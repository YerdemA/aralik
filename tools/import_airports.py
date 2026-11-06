"""Airport questions from OurAirports, appended to the bank.

Usage:  python tools/import_airports.py [--fetch] [--dry-run]

tools/airports_tr.csv lists the airports (ICAO code, what is asked,
difficulty, category, Turkish name, location for the fun fact):

  elevation  "Erzurum Havalimanı deniz seviyesinden kaç metre yüksekliktedir?"
  runway     "İstanbul Havalimanı'nın en uzun pisti kaç metredir?"

OurAirports gives feet; answers are converted to whole metres (× 0.3048),
nothing else. The longest runway counts only open ones. Negative or zero
elevations are not asked.

--fetch downloads airports.csv and runways.csv (about 15 MB, git-ignored)
and writes the listed airports to tools/raw/ourairports/airports.json
(small, committed); without it that file is read.

Sources: the airport's page for its elevation, its runways page for the
runway, so one airport can have both questions (validate_questions.py allows
one question per source and unit). The fun fact is only the location, so it
never gives away the airport's other question. OurAirports data is in the public domain.
"""

from __future__ import annotations

import argparse
import csv
import io
import json
import random
import sys
import urllib.request
from collections import Counter
from datetime import date
from pathlib import Path

from rounding import half_up

ROOT = Path(__file__).resolve().parent.parent
AIRPORTS = ROOT / "tools" / "airports_tr.csv"
BANK = ROOT / "assets" / "questions" / "questions.json"
RAW = ROOT / "tools" / "raw" / "ourairports"
EXTRACT = RAW / "airports.json"
DATA_URL = "https://davidmegginson.github.io/ourairports-data/{name}"
AIRPORT_URL = "https://ourairports.com/airports/{ident}/"
RUNWAYS_URL = "https://ourairports.com/airports/{ident}/runways.html"
FEET = 0.3048
SEED = 20261108
USER_AGENT = "KabacaContentCheck/1.0 (https://github.com/YerdemA/aralik)"

ASKED = {
    "elevation": ("{name} deniz seviyesinden kaç metre yüksekliktedir?", "airports_elevation"),
    "runway": ("{name}'nın en uzun pisti kaç metredir?", "airports_runway"),
}
CATEGORIES = {"türkiye", "coğrafya", "mimari"}


def read_rows(path: Path = AIRPORTS) -> list[dict]:
    rows = []
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split(";")
        if len(parts) != 6:
            sys.exit(f"HATA: satır biçimi bozuk: {line}")
        ident, asked, difficulty, category, name, place = (p.strip() for p in parts)
        if asked not in ASKED or difficulty not in ("1", "2", "3") or category not in CATEGORIES:
            sys.exit(f"HATA: geçersiz soru türü, zorluk ya da kategori: {line}")
        if not name.endswith("Havalimanı"):
            sys.exit(f"HATA: ad 'Havalimanı' ile bitmeli: {line}")
        rows.append(
            {"ident": ident, "asked": asked, "difficulty": int(difficulty), "category": category, "name": name, "place": place}
        )
    return rows


def download(name: str) -> str:
    path = RAW / name
    if not path.exists():
        print(f"İndiriliyor: {DATA_URL.format(name=name)}")
        request = urllib.request.Request(DATA_URL.format(name=name), headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(request, timeout=120) as response:
            path.write_bytes(response.read())
    return path.read_text(encoding="utf-8")


def fetch(idents: set[str]) -> dict:
    RAW.mkdir(parents=True, exist_ok=True)
    airports: dict[str, dict] = {}
    for row in csv.DictReader(io.StringIO(download("airports.csv"))):
        if row["ident"] in idents:
            airports[row["ident"]] = {
                "name": row["name"],
                "municipality": row["municipality"],
                "iso_country": row["iso_country"],
                "type": row["type"],
                "elevation_ft": int(row["elevation_ft"]) if row["elevation_ft"] else None,
                "runways": [],
            }
    for row in csv.DictReader(io.StringIO(download("runways.csv"))):
        airport = airports.get(row["airport_ident"])
        if airport is not None and row["length_ft"]:
            airport["runways"].append(
                {
                    "ident": f"{row['le_ident']}/{row['he_ident']}",
                    "length_ft": int(row["length_ft"]),
                    "surface": row["surface"],
                    "closed": row["closed"] == "1",
                }
            )
    payload = {
        "source": DATA_URL.format(name=""),
        "fetched": date.today().isoformat(),
        "airports": dict(sorted(airports.items())),
    }
    EXTRACT.write_text(json.dumps(payload, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"Yazıldı: {EXTRACT.relative_to(ROOT)} ({len(airports)} havalimanı)")
    return payload


def metres(feet: int) -> int:
    return half_up(feet * FEET)


def fun_fact(row: dict) -> str | None:
    # Only the location: OurAirports' runway lists also hold helipads and
    # grass strips (Charles de Gaulle 08H/26H), so a runway count is unsafe.
    return f"Konum: {row['place']}." if row["place"] else None


def build(rows: list[dict], payload: dict, bank: list[dict]) -> tuple[list[dict], list[str]]:
    year = int(payload["fetched"][:4])
    asked = {(q["source"], q["kind"], q["unit"]) for q in bank}
    texts = {q["text"].casefold() for q in bank}
    new, dropped = [], []
    for row in rows:
        template, dataset = ASKED[row["asked"]]
        label = f"{row['ident']} {row['asked']} ({row['name']})"
        airport = payload["airports"].get(row["ident"])
        if airport is None:
            dropped.append(f"VERİDE YOK: {label}")
            continue
        if row["asked"] == "elevation":
            feet = airport["elevation_ft"]
            source = AIRPORT_URL.format(ident=row["ident"])
        else:
            open_runways = [r["length_ft"] for r in airport["runways"] if not r["closed"]]
            feet = max(open_runways, default=None)
            source = RUNWAYS_URL.format(ident=row["ident"])
        if not feet or feet <= 0:
            dropped.append(f"DEĞER YOK YA DA SIFIRIN ALTINDA: {label}")
            continue
        text = template.format(name=row["name"])
        key = (source, "magnitude", "m")
        if key in asked or text.casefold() in texts:
            continue  # imported earlier
        asked.add(key)
        texts.add(text.casefold())
        new.append(
            {
                "text": text,
                "answer": metres(feet),
                "unit": "m",
                "kind": "magnitude",
                "category": row["category"],
                "source": source,
                "data_year": year,
                "fun_fact": fun_fact(row),
                "difficulty": row["difficulty"],
                "dataset": dataset,
            }
        )
    return new, dropped


def main(argv: list[str]) -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--fetch", action="store_true", help="OurAirports dosyalarından yeniden çıkar")
    parser.add_argument("--dry-run", action="store_true", help="bankaya yazma")
    args = parser.parse_args(argv)

    rows = read_rows()
    idents = {row["ident"] for row in rows}
    if args.fetch or not EXTRACT.exists():
        payload = fetch(idents)
    else:
        payload = json.loads(EXTRACT.read_text(encoding="utf-8"))
        missing = idents - payload["airports"].keys()
        if missing:
            sys.exit(f"HATA: {len(missing)} havalimanı {EXTRACT.name} içinde yok, --fetch ile çalıştırın: {sorted(missing)}")

    bank = json.loads(BANK.read_text(encoding="utf-8"))
    new, dropped = build(rows, payload, bank)
    for line in dropped:
        print(f"  - {line}")
    for q in new:
        print(f"  + z{q['difficulty']} {q['category']:9} {q['text']} = {q['answer']} m  [{q['fun_fact']}]")
    print(f"{len(rows)} satır, {len(new)} yeni, {len(dropped)} düşürüldü.")
    print("Yeni, veri seti:", dict(Counter(q["dataset"] for q in new)))
    print("Yeni, zorluk:", dict(sorted(Counter(q["difficulty"] for q in new).items())))
    if args.dry_run or not new:
        return 0

    # Like build_questions.py: the order is no ranking.
    random.Random(f"{SEED}:{len(bank)}").shuffle(new)
    next_number = max(int(q["id"][1:]) for q in bank) + 1
    new = [{"id": f"q{next_number + i:04d}", **q} for i, q in enumerate(new)]
    BANK.write_text(json.dumps(bank + new, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"Yazıldı: {BANK.relative_to(ROOT)} ({len(bank)} + {len(new)} soru)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
