"""Fetch raw question data from Wikidata into tools/raw/wikidata/.

Usage:  python tools/fetch_wikidata.py [dataset ...]

With no arguments every dataset is fetched. Only the standard library is used.

Two phases per dataset, because single big queries time out on the public
endpoint:
  1. Candidate items: one scan per type, restricted to items that have a
     Turkish Wikipedia article (keeps it fast and favours items a Turkish
     player may know). Ranked by sitelink count, a fame proxy.
  2. Details for the top candidates via VALUES: Turkish label, every
     non-deprecated value statement with its rank, extra fields and the
     Turkish Wikipedia article title.
Then the article's page views over the last 12 months are added
(Wikimedia REST API). build_questions.py ranks by them: they say far more
about what a Turkish player knows than sitelink counts.

Each dataset is saved as tools/raw/wikidata/<name>.json with one row per
value statement, so build_questions.py can resolve ambiguous values itself.
tools/raw/<source>/_meta.json records where each dump came from, when, and
under which license (docs/SOURCES.md, rule 2).

Property and class ids were checked on wikidata.org before use (2026-10-26):
P2067 mass, P2048 height, P2250 life expectancy, P571 inception, P1128
employees, P166 award received, P585 point in time, P2101 melting point,
P2102 boiling point, P575 time of discovery, P21 sex, P3831 object of
statement has role; Q11303 skyscraper, Q11344 chemical element, Q7432
species, Q4830453/Q891723/Q6881511/Q783794 business/public company/
enterprise/company, Q38104 … Q47170 the six Nobel prizes.
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
PAGEVIEWS = (
    "https://wikimedia.org/api/rest_v1/metrics/pageviews/per-article/"
    "tr.wikipedia.org/all-access/user/{title}/monthly/{start}/{end}"
)
# Last 12 full months before the fetch.
VIEWS_START, VIEWS_END = "2025100100", "2026093000"
USER_AGENT = "AralikQuestionBot/0.1 (https://github.com/YerdemA/aralik)"
RAW_ROOT = Path(__file__).resolve().parent / "raw"
RAW_DIR = RAW_ROOT / "wikidata"
VIEWS_DIR = RAW_ROOT / "wikimedia_pageviews"
VIEWS_CACHE = VIEWS_DIR / "pageviews_cache.json"
IN_TURKEY = "?item wdt:P17 wd:Q43 ."
TR_ARTICLE_PATTERN = "?article schema:about ?item ; schema:isPartOf <https://tr.wikipedia.org/> ."
META = {
    RAW_DIR: {
        "source": "wikidata",
        "url": ENDPOINT,
        "license": "CC0 1.0",
        "license_url": "https://www.wikidata.org/wiki/Wikidata:Licensing",
    },
    VIEWS_DIR: {
        "source": "wikimedia_pageviews",
        "url": "https://wikimedia.org/api/rest_v1/metrics/pageviews/",
        "license": "CC0 1.0",
        "license_url": "https://wikitech.wikimedia.org/wiki/Analytics/AQS/Pageviews",
        "period": f"{VIEWS_START[:8]}-{VIEWS_END[:8]}",
    },
}
DETAIL_CHUNK = 60
PAUSE_SECONDS = 2  # be polite to the public endpoint

MOUNTAIN_TYPES = ("Q8502", "Q8072", "Q169358")  # mountain, volcano, stratovolcano
RIVER_TYPES = ("Q4022",)  # river
# skyscraper, tower, lattice tower, television tower, pyramid, colossal statue, dam
STRUCTURE_TYPES = ("Q11303", "Q12518", "Q1440476", "Q11166728", "Q12516", "Q1779653", "Q12323")
UNIVERSITY_TYPES = ("Q3918", "Q875538", "Q902104")  # university, public, private
CLUB_TYPES = ("Q476028", "Q847017")  # association football club, sports club
HISTORIC_BUILDING_TYPES = ("Q32815", "Q23413", "Q16560")  # mosque, castle, palace
BRIDGE_TYPES = ("Q12280", "Q12570", "Q158555")  # bridge, suspension, cable-stayed
STADIUM_TYPES = ("Q483110", "Q1154710", "Q1049757")  # stadium, football, multi-purpose
# business, public company, enterprise, company
COMPANY_TYPES = ("Q4830453", "Q891723", "Q6881511", "Q783794")
NOBEL_PRIZES = ("Q38104", "Q44585", "Q80061", "Q37922", "Q35637", "Q47170")
SPECIES = "?item wdt:P105 wd:Q7432 ."  # taxon rank: species


@dataclass(frozen=True)
class Dataset:
    name: str
    description: str
    # instance of (P31) any of these types.
    types: tuple[str, ...]
    # Property of the question, e.g. P2044 (elevation) or P571 (inception).
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
    # "quantity", "year" (a date property; only year precision or finer) or
    # "qualifier_year": the year (P585) of a statement whose value is one of
    # value_items, e.g. the year of a Nobel prize (P166).
    value_kind: str = "quantity"
    value_items: tuple[str, ...] = ()
    # name -> qualifier property, kept per statement as QIDs, e.g. the sex
    # (P21) and role (P3831) of an animal's mass.
    qualifiers: dict[str, str] = field(default_factory=dict)
    # Hand-written candidate pattern (binds ?item) for sets where the
    # generic scans time out; replaces types/where in the candidate query.
    candidates: str = ""


DATASETS = [
    Dataset(
        name="mountains_tr",
        description="Türkiye'deki dağlar, yükseklik (P2044)",
        types=MOUNTAIN_TYPES,
        prop="P2044",
        limit=150,
        where=IN_TURKEY,
        extras={"place": ("wdt:P131", "label")},
        per_type_scan=False,
    ),
    Dataset(
        name="mountains_world",
        description="Dünyadaki bilinen dağlar, yükseklik (P2044)",
        types=MOUNTAIN_TYPES,
        prop="P2044",
        limit=200,
        extras={"country": ("wdt:P17", "label")},
    ),
    Dataset(
        name="rivers_tr",
        description="Türkiye'den geçen nehirler, uzunluk (P2043)",
        types=RIVER_TYPES,
        prop="P2043",
        limit=100,
        where=IN_TURKEY,
        extras={"mouth": ("wdt:P403", "label")},
        per_type_scan=False,
    ),
    Dataset(
        name="rivers_world",
        description="Dünyadaki bilinen nehirler, uzunluk (P2043)",
        types=RIVER_TYPES,
        prop="P2043",
        limit=200,
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
        limit=150,
        where=IN_TURKEY,
        extras={"place": ("wdt:P131", "label"), "opened": ("wdt:P1619", "year")},
        per_type_scan=False,
    ),
    Dataset(
        name="structures_world",
        description="Dünyadaki önemli yapılar, yükseklik (P2048)",
        types=STRUCTURE_TYPES,
        prop="P2048",
        limit=200,
        extras={
            "place": ("wdt:P131", "label"),
            "country": ("wdt:P17", "label"),
            "opened": ("wdt:P1619", "year"),
        },
        per_type_scan=False,
    ),
    Dataset(
        name="bridges_tr",
        description="Türkiye'deki köprüler, uzunluk (P2043)",
        types=BRIDGE_TYPES,
        prop="P2043",
        limit=120,
        where=IN_TURKEY,
        extras={"place": ("wdt:P131", "label"), "opened": ("wdt:P1619", "year")},
        per_type_scan=False,
    ),
    Dataset(
        name="lakes_tr",
        description="Türkiye'deki göller, yüzölçümü (P2046)",
        types=("Q23397",),
        prop="P2046",
        limit=100,
        where=IN_TURKEY,
        extras={"place": ("wdt:P131", "label")},
        per_type_scan=False,
    ),
    Dataset(
        name="stadiums_tr",
        description="Türkiye'deki stadyumlar, kapasite (P1083)",
        types=STADIUM_TYPES,
        prop="P1083",
        limit=100,
        where=IN_TURKEY,
        normalized=False,
        extras={"place": ("wdt:P131", "label")},
        per_type_scan=False,
    ),
    Dataset(
        name="countries_population",
        description="Egemen devletler, nüfus (P1082)",
        types=("Q3624078",),
        prop="P1082",
        limit=200,
        normalized=False,
        extras={"capital": ("wdt:P36", "label")},
        per_type_scan=False,
    ),
    Dataset(
        name="countries_area",
        description="Egemen devletler, yüzölçümü (P2046)",
        types=("Q3624078",),
        prop="P2046",
        limit=200,
        extras={"capital": ("wdt:P36", "label")},
        per_type_scan=False,
    ),
    Dataset(
        name="clubs_tr",
        description="Türkiye'deki spor kulüpleri, kuruluş yılı (P571)",
        types=CLUB_TYPES,
        prop="P571",
        limit=120,
        where=IN_TURKEY,
        extras={"place": ("wdt:P131", "label")},
        per_type_scan=False,
        value_kind="year",
    ),
    Dataset(
        name="universities_tr",
        description="Türkiye'deki üniversiteler, kuruluş yılı (P571)",
        types=UNIVERSITY_TYPES,
        prop="P571",
        limit=150,
        where=IN_TURKEY,
        extras={"place": ("wdt:P131", "label")},
        per_type_scan=False,
        value_kind="year",
    ),
    Dataset(
        name="historic_buildings_tr",
        description="Türkiye'deki cami, kale ve saraylar, yapım yılı (P571)",
        types=HISTORIC_BUILDING_TYPES,
        prop="P571",
        limit=200,
        where=IN_TURKEY,
        extras={"place": ("wdt:P131", "label")},
        per_type_scan=False,
        value_kind="year",
    ),
    Dataset(
        name="skyscrapers_world",
        description="Gökdelenler ve kuleler, yükseklik (P2048)",
        types=("Q11303", "Q12518"),
        prop="P2048",
        limit=250,
        extras={"place": ("wdt:P131", "label"), "country": ("wdt:P17", "label")},
        per_type_scan=False,
    ),
    Dataset(
        name="companies_founded",
        description="Şirketler, kuruluş yılı (P571)",
        types=COMPANY_TYPES,
        prop="P571",
        limit=300,
        extras={"country": ("wdt:P17", "label")},
        value_kind="year",
        # Well-documented companies only (those with an employee count);
        # the plain type scan times out on "business" (2026-10-26).
        candidates=" ".join(
            [
                "VALUES ?type {",
                *(f"wd:{t}" for t in COMPANY_TYPES),
                "}",
                TR_ARTICLE_PATTERN,
                "?item wdt:P31 ?type ; wdt:P1128 [] .",
            ]
        ),
    ),
    Dataset(
        name="companies_employees",
        description="Şirketler, çalışan sayısı (P1128, yılı P585)",
        types=COMPANY_TYPES,
        prop="P1128",
        limit=300,
        normalized=False,
        extras={"country": ("wdt:P17", "label")},
        per_type_scan=False,
    ),
    Dataset(
        name="elements_melting",
        description="Kimyasal elementler, erime noktası (P2101, kelvin)",
        types=("Q11344",),
        prop="P2101",
        limit=130,
        where="?item wdt:P1086 [] .",
        per_type_scan=False,
    ),
    Dataset(
        name="elements_boiling",
        description="Kimyasal elementler, kaynama noktası (P2102, kelvin)",
        types=("Q11344",),
        prop="P2102",
        limit=130,
        where="?item wdt:P1086 [] .",
        per_type_scan=False,
    ),
    Dataset(
        name="elements_discovered",
        description="Kimyasal elementler, keşif yılı (P575)",
        types=("Q11344",),
        prop="P575",
        limit=130,
        where="?item wdt:P1086 [] .",
        per_type_scan=False,
        value_kind="year",
    ),
    Dataset(
        name="nobel",
        description="Nobel ödülü sahipleri, ödül yılı (P166 + P585)",
        types=("Q5",),
        prop="P166",
        limit=400,
        where="VALUES ?prize { " + " ".join(f"wd:{q}" for q in NOBEL_PRIZES) + " } ?item wdt:P166 ?prize .",
        per_type_scan=False,
        value_kind="qualifier_year",
        value_items=NOBEL_PRIZES,
    ),
    Dataset(
        name="animals_mass",
        description="Hayvan türleri, kütle (P2067, cinsiyet ve rol niteleyicileriyle)",
        types=("Q16521",),
        prop="P2067",
        limit=250,
        where=SPECIES,
        qualifiers={"sex": "P21", "role": "P3831"},
        # P225 taxon name: a "label" equal to it means no Turkish name.
        extras={"taxon": ("wdt:P225", "literal")},
        # Start from the adult-weight qualifier: only those values are used,
        # and every other order times out (2026-10-26).
        candidates=f"""hint:Query hint:optimizer "None" .
  ?st pq:P3831 wd:Q78101716 . ?item p:P2067 ?st .
  {SPECIES}
  {TR_ARTICLE_PATTERN}""",
    ),
    Dataset(
        name="animals_lifespan",
        description="Hayvan türleri, beklenen yaşam süresi (P2250)",
        types=("Q16521",),
        prop="P2250",
        limit=100,
        where=SPECIES,
        qualifiers={"sex": "P21", "applies_to": "P518"},
        extras={"taxon": ("wdt:P225", "literal")},
        # Only ~70 species have P2250 at all; the article join is what times
        # out, and the details query keeps Turkish labels anyway.
        candidates=f"?item wdt:P2250 [] . {SPECIES}",
    ),
    Dataset(
        name="battles",
        description="Muharebeler, tarih (P585)",
        types=("Q178561",),
        prop="P585",
        limit=250,
        value_kind="year",
    ),
    Dataset(
        name="wars",
        description="Savaşlar, başlangıç (P580)",
        types=("Q198",),
        prop="P580",
        limit=200,
        value_kind="year",
    ),
    Dataset(
        name="earthquakes_tr",
        description="Türkiye'deki depremler, tarih (P585)",
        types=("Q7944",),
        prop="P585",
        limit=100,
        where=IN_TURKEY,
        per_type_scan=False,
        value_kind="year",
    ),
]


TR_ARTICLE = "?article schema:isPartOf <https://tr.wikipedia.org/> ; schema:about ?item ."


def candidates_query(ds: Dataset, item_type: str | None = None) -> str:
    """Candidates of one type (per-type scan) or of all types at once."""
    if ds.candidates:
        body = ds.candidates
    elif item_type:
        # optimizer "None" keeps the written join order: start from the
        # Turkish Wikipedia articles, far fewer than e.g. all mountains.
        body = f"""hint:Query hint:optimizer "None" .
  {TR_ARTICLE}
  ?item wdt:P31 wd:{item_type} .
  {ds.where}"""
    else:
        types = " ".join(f"wd:{t}" for t in ds.types)
        # Turkey-restricted sets are small enough without the article filter.
        restriction = ds.where if ds.where == IN_TURKEY else f"{TR_ARTICLE}\n  {ds.where}"
        body = f"""VALUES ?type {{ {types} }}
  {restriction}
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
    if ds.value_kind == "qualifier_year":
        items = " ".join(f"wd:{q}" for q in ds.value_items)
        value_pattern = (
            f"ps:{ds.prop} ?valueItem ; pq:P585 ?date .\n"
            f"  VALUES ?valueItem {{ {items} }}\n"
            "  BIND(YEAR(?date) AS ?value)"
        )
    elif ds.value_kind == "year":
        # Only dates known at least to the year (precision 9 = year).
        value_pattern = (
            f"psv:{ds.prop} [ wikibase:timeValue ?date ; wikibase:timePrecision ?precision ] .\n"
            "  FILTER(?precision >= 9)\n"
            "  BIND(YEAR(?date) AS ?value)"
        )
    elif ds.normalized:
        value_pattern = f"psn:{ds.prop}/wikibase:quantityAmount ?value ."
    else:
        value_pattern = f"ps:{ds.prop} ?value ."
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
    for name, prop in ds.qualifiers.items():
        extra_select.append(f'(GROUP_CONCAT(DISTINCT ?{name}_q; separator="|") AS ?{name})')
        extra_where.append(f"OPTIONAL {{ ?st pq:{prop} ?{name}_q . }}")
    item_select = "?valueItem" if ds.value_kind == "qualifier_year" else ""
    values = " ".join(f"wd:{qid}" for qid in qids)
    extras = "\n  ".join(extra_where)

    return f"""
SELECT ?item ?label ?st ?value {item_select} ?rank ?valueYear (SAMPLE(?title_v) AS ?title) {' '.join(extra_select)} WHERE {{
  VALUES ?item {{ {values} }}
  ?item rdfs:label ?label . FILTER(LANG(?label) = "tr")
  ?item p:{ds.prop} ?st .
  ?st wikibase:rank ?rank ; {value_pattern}
  FILTER(?rank != wikibase:DeprecatedRank)
  OPTIONAL {{ ?article schema:about ?item ; schema:isPartOf <https://tr.wikipedia.org/> ; schema:name ?title_v . }}
  OPTIONAL {{ ?st pq:P585 ?time . BIND(YEAR(?time) AS ?valueYear) }}
  {extras}
}}
GROUP BY ?item ?label ?st ?value {item_select} ?rank ?valueYear
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
    for item_type in ds.types if ds.per_type_scan and not ds.candidates else [None]:
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
        "tr_title": get("title"),
    }
    if get("valueItem"):
        row["value_item"] = get("valueItem").rsplit("/", 1)[-1]
    for name in ds.qualifiers:
        raw = get(name)
        row[name] = sorted(v.rsplit("/", 1)[-1] for v in raw.split("|") if v) if raw else []
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
    add_page_views(rows, "tr_title", "tr_views")
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
    write_meta(RAW_DIR, ds.name, payload["fetched_at"], ds.description)
    items = len({r["qid"] for r in rows})
    print(f"  {len(rows)} satır, {items} öğe -> tools/raw/wikidata/{out.name}", flush=True)
    return out


def write_meta(directory: Path, dataset: str, fetched_at: str, description: str) -> None:
    """Record the dump's origin, date and license in <dir>/_meta.json."""
    path = directory / "_meta.json"
    meta = json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}
    meta.update(META[directory])
    meta.setdefault("datasets", {})[dataset] = {
        "description": description,
        "fetched_at": fetched_at,
    }
    meta["datasets"] = dict(sorted(meta["datasets"].items()))
    path.write_text(json.dumps(meta, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")


def page_views(titles: set[str]) -> dict[str, int]:
    """12-month Turkish Wikipedia page views per article title (cached)."""
    cache = json.loads(VIEWS_CACHE.read_text(encoding="utf-8")) if VIEWS_CACHE.exists() else {}
    known = cache.setdefault(f"{VIEWS_START}-{VIEWS_END}", {})
    missing = sorted(t for t in titles if t not in known)
    for i, title in enumerate(missing):
        url = PAGEVIEWS.format(
            title=urllib.parse.quote(title.replace(" ", "_"), safe=""),
            start=VIEWS_START,
            end=VIEWS_END,
        )
        request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                items = json.load(response)["items"]
            known[title] = sum(item["views"] for item in items)
        except urllib.error.HTTPError as error:
            if error.code != 404:  # 404: no views recorded
                raise
            known[title] = 0
        time.sleep(0.05)
        if i % 50 == 49:
            print(f"    okunma sayıları: {i + 1}/{len(missing)}", flush=True)
            VIEWS_CACHE.write_text(json.dumps(cache, ensure_ascii=False), encoding="utf-8")
    VIEWS_CACHE.write_text(json.dumps(cache, ensure_ascii=False), encoding="utf-8")
    write_meta(
        VIEWS_DIR,
        "tr.wikipedia",
        datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "Türkçe Vikipedi maddelerinin aylık okunma sayıları (kullanıcı erişimi)",
    )
    return {t: known[t] for t in titles}


def add_page_views(rows: list[dict], title_key: str, views_key: str) -> None:
    views = page_views({r[title_key] for r in rows if r.get(title_key)})
    for row in rows:
        row[views_key] = views.get(row.get(title_key) or "", 0)


# Coordinates for on-device distance questions (see tools/build_places.py).
# One row per coordinate statement; the builder drops ambiguous places.
PLACE_QUERIES = {
    "places_tr": (
        "Türkiye il merkezleri, koordinat (P625)",
        """
SELECT ?province ?plate ?city ?cityLabel ?cityTitle ?lat ?lon WHERE {
  ?province wdt:P31 wd:Q48336 ; wdt:P36 ?city .
  OPTIONAL { ?province wdt:P395 ?plate . }
  ?city p:P625 ?st .
  ?st wikibase:rank ?rank ; psv:P625 [ wikibase:geoLatitude ?lat ; wikibase:geoLongitude ?lon ] .
  FILTER(?rank != wikibase:DeprecatedRank)
  ?city rdfs:label ?cityLabel . FILTER(LANG(?cityLabel) = "tr")
  OPTIONAL { ?cityArticle schema:about ?city ; schema:isPartOf <https://tr.wikipedia.org/> ; schema:name ?cityTitle . }
}
""",
    ),
    "places_world": (
        "Egemen devletlerin başkentleri, koordinat (P625)",
        """
SELECT ?country ?countryLabel ?links ?city ?cityLabel ?cityTitle ?lat ?lon WHERE {
  ?country wdt:P31 wd:Q3624078 ; wdt:P36 ?city ; wikibase:sitelinks ?links .
  FILTER NOT EXISTS { ?country wdt:P576 [] . }
  ?country rdfs:label ?countryLabel . FILTER(LANG(?countryLabel) = "tr")
  ?city p:P625 ?st .
  ?st wikibase:rank ?rank ; psv:P625 [ wikibase:geoLatitude ?lat ; wikibase:geoLongitude ?lon ] .
  FILTER(?rank != wikibase:DeprecatedRank)
  ?city rdfs:label ?cityLabel . FILTER(LANG(?cityLabel) = "tr")
  OPTIONAL { ?cityArticle schema:about ?city ; schema:isPartOf <https://tr.wikipedia.org/> ; schema:name ?cityTitle . }
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
    add_page_views(rows, "cityTitle", "city_views")
    rows.sort(key=lambda r: tuple(sorted((k, str(v)) for k, v in r.items())))
    out = RAW_DIR / f"{name}.json"
    payload = {
        "dataset": name,
        "description": description,
        "fetched_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "rows": rows,
    }
    out.write_text(json.dumps(payload, ensure_ascii=False, indent=1), encoding="utf-8")
    write_meta(RAW_DIR, name, payload["fetched_at"], description)
    print(f"  {len(rows)} satır -> tools/raw/wikidata/{out.name}", flush=True)
    return out


def main(argv: list[str]) -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    RAW_DIR.mkdir(parents=True, exist_ok=True)
    VIEWS_DIR.mkdir(parents=True, exist_ok=True)
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
