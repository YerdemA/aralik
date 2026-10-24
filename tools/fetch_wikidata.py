"""Fetch raw question data from Wikidata into tools/raw/.

Usage:  python tools/fetch_wikidata.py [dataset ...]

With no arguments every dataset is fetched. Only the standard library is used.

Two phases per dataset, because single big queries time out on the public
endpoint:
  1. Candidate items: one scan per type, restricted to items that have a
     Turkish Wikipedia article (keeps it fast and favours items a Turkish
     player may know). Ranked by sitelink count, a fame proxy.
  2. Details for the top candidates via VALUES: Turkish label, every
     non-deprecated value statement with its rank, and extra fields.

Each dataset is saved as tools/raw/<name>.json with one row per value
statement, so build_questions.py can resolve ambiguous values itself.
"""

from __future__ import annotations

import json
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path

ENDPOINT = "https://query.wikidata.org/sparql"
USER_AGENT = "AralikQuestionBot/0.1 (https://github.com/YerdemA/aralik)"
RAW_DIR = Path(__file__).resolve().parent / "raw"
IN_TURKEY = "?item wdt:P17 wd:Q43 ."
DETAIL_CHUNK = 60
PAUSE_SECONDS = 2  # be polite to the public endpoint

MOUNTAIN_TYPES = ("Q8502", "Q8072", "Q169358")  # mountain, volcano, stratovolcano
RIVER_TYPES = ("Q4022",)  # river
# skyscraper, tower, lattice tower, television tower, pyramid, colossal statue, dam
STRUCTURE_TYPES = ("Q11303", "Q12518", "Q1440476", "Q11166728", "Q12516", "Q1779653", "Q12323")


@dataclass(frozen=True)
class Dataset:
    name: str
    description: str
    # instance of (P31) any of these types.
    types: tuple[str, ...]
    # Quantity property of the question, e.g. P2044 (elevation).
    prop: str
    # Keep only the N candidates with the most sitelinks.
    limit: int
    # Extra SPARQL pattern on ?item, e.g. IN_TURKEY.
    where: str = ""
    # psn: values are SI-normalized (metres); population has no unit.
    normalized: bool = True
    # name -> (property path, kind); kind is "label", "year" or "literal".
    extras: dict[str, tuple[str, str]] = field(default_factory=dict)
    # True: one fixed-order scan per type (needed for huge types such as
    # mountains). False: a single query over all types, left to the
    # optimizer, which is much faster for the structure types.
    per_type_scan: bool = True


DATASETS = [
    Dataset(
        name="mountains_tr",
        description="Türkiye'deki dağlar, yükseklik (P2044)",
        types=MOUNTAIN_TYPES,
        prop="P2044",
        limit=80,
        where=IN_TURKEY,
        extras={"place": ("wdt:P131", "label")},
    ),
    Dataset(
        name="mountains_world",
        description="Dünyadaki bilinen dağlar, yükseklik (P2044)",
        types=MOUNTAIN_TYPES,
        prop="P2044",
        limit=120,
        extras={"country": ("wdt:P17", "label")},
    ),
    Dataset(
        name="rivers_tr",
        description="Türkiye'den geçen nehirler, uzunluk (P2043)",
        types=RIVER_TYPES,
        prop="P2043",
        limit=60,
        where=IN_TURKEY,
        extras={"mouth": ("wdt:P403", "label")},
    ),
    Dataset(
        name="rivers_world",
        description="Dünyadaki bilinen nehirler, uzunluk (P2043)",
        types=RIVER_TYPES,
        prop="P2043",
        limit=120,
        extras={"mouth": ("wdt:P403", "label"), "country": ("wdt:P17", "label")},
    ),
    Dataset(
        name="provinces_tr",
        description="Türkiye illeri, nüfus (P1082)",
        types=("Q48336",),  # province of Turkey
        prop="P1082",
        limit=90,
        normalized=False,
        extras={"plate": ("wdt:P395", "literal")},
    ),
    Dataset(
        name="structures_tr",
        description="Türkiye'deki yapılar, yükseklik (P2048)",
        types=STRUCTURE_TYPES,
        prop="P2048",
        limit=80,
        where=IN_TURKEY,
        extras={"place": ("wdt:P131", "label"), "opened": ("wdt:P1619", "year")},
        per_type_scan=False,
    ),
    Dataset(
        name="structures_world",
        description="Dünyadaki önemli yapılar, yükseklik (P2048)",
        types=STRUCTURE_TYPES,
        prop="P2048",
        limit=120,
        extras={
            "place": ("wdt:P131", "label"),
            "country": ("wdt:P17", "label"),
            "opened": ("wdt:P1619", "year"),
        },
        per_type_scan=False,
    ),
]


TR_ARTICLE = "?article schema:isPartOf <https://tr.wikipedia.org/> ; schema:about ?item ."


def candidates_query(ds: Dataset, item_type: str | None = None) -> str:
    """Candidates of one type (per-type scan) or of all types at once."""
    if item_type:
        # optimizer "None" keeps the written join order: start from the
        # Turkish Wikipedia articles, far fewer than e.g. all mountains.
        body = f"""hint:Query hint:optimizer "None" .
  {TR_ARTICLE}
  ?item wdt:P31 wd:{item_type} .
  {ds.where}"""
    else:
        types = " ".join(f"wd:{t}" for t in ds.types)
        # Turkey-restricted sets are small enough without the article filter.
        body = f"""VALUES ?type {{ {types} }}
  {ds.where or TR_ARTICLE}
  ?item wdt:P31 ?type ."""
    return f"""
SELECT DISTINCT ?item ?links WHERE {{
  {body}
  ?item wdt:{ds.prop} [] ; wikibase:sitelinks ?links .
}}
ORDER BY DESC(?links)
LIMIT {ds.limit}
"""


def details_query(ds: Dataset, qids: list[str]) -> str:
    value_path = (
        f"psn:{ds.prop}/wikibase:quantityAmount" if ds.normalized else f"ps:{ds.prop}"
    )
    extra_select = []
    extra_where = []
    for name, (path, kind) in ds.extras.items():
        extra_select.append(f'(GROUP_CONCAT(DISTINCT ?{name}_v; separator="|") AS ?{name})')
        if kind == "label":
            extra_where.append(
                f"OPTIONAL {{ ?item {path} ?{name}_e . ?{name}_e rdfs:label ?{name}_v . "
                f'FILTER(LANG(?{name}_v) = "tr") }}'
            )
        elif kind == "year":
            extra_where.append(
                f"OPTIONAL {{ ?item {path} ?{name}_d . BIND(YEAR(?{name}_d) AS ?{name}_v) }}"
            )
        else:
            extra_where.append(f"OPTIONAL {{ ?item {path} ?{name}_v . }}")
    values = " ".join(f"wd:{qid}" for qid in qids)
    extras = "\n  ".join(extra_where)

    return f"""
SELECT ?item ?label ?value ?rank ?valueYear {' '.join(extra_select)} WHERE {{
  VALUES ?item {{ {values} }}
  ?item rdfs:label ?label . FILTER(LANG(?label) = "tr")
  ?item p:{ds.prop} ?st .
  ?st wikibase:rank ?rank ; {value_path} ?value .
  FILTER(?rank != wikibase:DeprecatedRank)
  OPTIONAL {{ ?st pq:P585 ?time . BIND(YEAR(?time) AS ?valueYear) }}
  {extras}
}}
GROUP BY ?item ?label ?value ?rank ?valueYear
"""


def run_query(query: str, retries: int = 3) -> list[dict]:
    body = urllib.parse.urlencode({"query": query}).encode()
    request = urllib.request.Request(
        ENDPOINT,
        data=body,
        headers={
            "User-Agent": USER_AGENT,
            "Accept": "application/sparql-results+json",
            "Content-Type": "application/x-www-form-urlencoded",
        },
    )
    for attempt in range(1, retries + 1):
        try:
            with urllib.request.urlopen(request, timeout=90) as response:
                return json.load(response)["results"]["bindings"]
        except urllib.error.HTTPError as error:
            if error.code in (429, 500, 502, 503, 504) and attempt < retries:
                wait = int(error.headers.get("Retry-After") or 15 * attempt)
                print(f"    HTTP {error.code}, {wait} sn sonra tekrar...", flush=True)
                time.sleep(wait)
                continue
            raise
        except (urllib.error.URLError, TimeoutError):
            if attempt < retries:
                time.sleep(15 * attempt)
                continue
            raise
    raise RuntimeError("unreachable")


def qid_of(binding: dict) -> str:
    return binding["item"]["value"].rsplit("/", 1)[-1]


def fetch_candidates(ds: Dataset) -> dict[str, int]:
    links: dict[str, int] = {}
    for item_type in ds.types if ds.per_type_scan else [None]:
        bindings = run_query(candidates_query(ds, item_type))
        for b in bindings:
            links[qid_of(b)] = int(b["links"]["value"])
        print(f"    {item_type or 'tüm tipler'}: {len(bindings)} aday", flush=True)
        time.sleep(PAUSE_SECONDS)
    top = sorted(links.items(), key=lambda kv: (-kv[1], kv[0]))[: ds.limit]
    return dict(top)


def simplify(ds: Dataset, binding: dict, links: int) -> dict:
    def get(key: str) -> str | None:
        return binding[key]["value"] if key in binding else None

    row = {
        "qid": qid_of(binding),
        "label": get("label"),
        "links": links,
        "value": float(get("value")),
        "rank": "preferred" if get("rank").endswith("PreferredRank") else "normal",
        "value_year": int(get("valueYear")) if get("valueYear") else None,
    }
    for name, (_, kind) in ds.extras.items():
        raw = get(name)
        values = sorted({v for v in raw.split("|") if v}) if raw else []
        row[name] = sorted(int(v) for v in values) if kind == "year" else values
    return row


def fetch(ds: Dataset) -> Path:
    candidates = fetch_candidates(ds)
    qids = list(candidates)
    rows = []
    for start in range(0, len(qids), DETAIL_CHUNK):
        chunk = qids[start : start + DETAIL_CHUNK]
        for b in run_query(details_query(ds, chunk)):
            rows.append(simplify(ds, b, candidates[qid_of(b)]))
        time.sleep(PAUSE_SECONDS)
    rows.sort(key=lambda r: (-r["links"], r["qid"], r["value"]))

    out = RAW_DIR / f"{ds.name}.json"
    payload = {
        "dataset": ds.name,
        "description": ds.description,
        "property": ds.prop,
        "fetched_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "rows": rows,
    }
    out.write_text(json.dumps(payload, ensure_ascii=False, indent=1), encoding="utf-8")
    items = len({r["qid"] for r in rows})
    print(f"  {len(rows)} satır, {items} öğe -> tools/raw/{out.name}", flush=True)
    return out


# Coordinates for on-device distance questions (see tools/build_places.py).
# One row per coordinate statement; the builder drops ambiguous places.
PLACE_QUERIES = {
    "places_tr": (
        "Türkiye il merkezleri, koordinat (P625)",
        """
SELECT ?province ?plate ?city ?cityLabel ?lat ?lon WHERE {
  ?province wdt:P31 wd:Q48336 ; wdt:P36 ?city .
  OPTIONAL { ?province wdt:P395 ?plate . }
  ?city p:P625 ?st .
  ?st wikibase:rank ?rank ; psv:P625 [ wikibase:geoLatitude ?lat ; wikibase:geoLongitude ?lon ] .
  FILTER(?rank != wikibase:DeprecatedRank)
  ?city rdfs:label ?cityLabel . FILTER(LANG(?cityLabel) = "tr")
}
""",
    ),
    "places_world": (
        "Egemen devletlerin başkentleri, koordinat (P625)",
        """
SELECT ?country ?countryLabel ?links ?city ?cityLabel ?lat ?lon WHERE {
  ?country wdt:P31 wd:Q3624078 ; wdt:P36 ?city ; wikibase:sitelinks ?links .
  FILTER NOT EXISTS { ?country wdt:P576 [] . }
  ?country rdfs:label ?countryLabel . FILTER(LANG(?countryLabel) = "tr")
  ?city p:P625 ?st .
  ?st wikibase:rank ?rank ; psv:P625 [ wikibase:geoLatitude ?lat ; wikibase:geoLongitude ?lon ] .
  FILTER(?rank != wikibase:DeprecatedRank)
  ?city rdfs:label ?cityLabel . FILTER(LANG(?cityLabel) = "tr")
}
""",
    ),
}


def fetch_places(name: str) -> Path:
    description, query = PLACE_QUERIES[name]
    rows = []
    for b in run_query(query):
        row = {}
        for key, cell in b.items():
            value = cell["value"]
            if cell.get("type") == "uri":
                value = value.rsplit("/", 1)[-1]
            row[key] = value
        rows.append(row)
    rows.sort(key=lambda r: tuple(sorted(r.items())))
    out = RAW_DIR / f"{name}.json"
    payload = {
        "dataset": name,
        "description": description,
        "fetched_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "rows": rows,
    }
    out.write_text(json.dumps(payload, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"  {len(rows)} satır -> tools/raw/{out.name}", flush=True)
    return out


def main(argv: list[str]) -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    RAW_DIR.mkdir(parents=True, exist_ok=True)
    by_name = {ds.name: ds for ds in DATASETS}
    names = list(by_name) + list(PLACE_QUERIES)
    unknown = [name for name in argv if name not in names]
    if unknown:
        print(f"Bilinmeyen veri seti: {', '.join(unknown)}. Seçenekler: {', '.join(names)}")
        return 2

    failed = []
    for name in argv or names:
        try:
            if name in PLACE_QUERIES:
                print(f"{name}: {PLACE_QUERIES[name][0]}", flush=True)
                fetch_places(name)
            else:
                print(f"{name}: {by_name[name].description}", flush=True)
                fetch(by_name[name])
        except Exception as error:  # noqa: BLE001 - report and continue
            print(f"  HATA: {error}", flush=True)
            failed.append(name)
        time.sleep(PAUSE_SECONDS)

    if failed:
        print(f"Başarısız: {', '.join(failed)}. Tekrar: python tools/fetch_wikidata.py {' '.join(failed)}")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
