"""Earthquake questions from the USGS ANSS Comprehensive Catalog (ComCat).

Usage:  python tools/import_usgs.py [--fetch] [--dry-run]

Magnitudes are not asked: on the log scale of the game a 7.8 and a 7.0 are
too close for a meaningful interval. Three kinds of question instead:

- YEARS: the year of a known earthquake (event time in UTC; none of them is
  near New Year). The fun fact gives its magnitude from the catalog.
- COUNTS: how many earthquakes of at least a magnitude the catalog has in a
  period (the FDSN `count` method). The fun fact gives another period.
- DEPTHS: the depth of two deep earthquakes. Shallow depths are often fixed
  by the network (10 km), so only deep ones are asked.

--fetch calls the FDSN event service (no key) and writes the values used to
tools/raw/usgs/comcat.json (committed); without it that file is read.
ComCat is a U.S. Government work, public domain. The source of a year or
depth question is the event page; of a count, the count query itself.
"""

from __future__ import annotations

import argparse
import json
import random
import sys
import time
import urllib.parse
import urllib.request
from collections import Counter
from dataclasses import dataclass
from datetime import date, datetime, timedelta, timezone
from pathlib import Path

from rounding import half_up, turkish_decimal

ROOT = Path(__file__).resolve().parent.parent
BANK = ROOT / "assets" / "questions" / "questions.json"
EXTRACT = ROOT / "tools" / "raw" / "usgs" / "comcat.json"
FDSN = "https://earthquake.usgs.gov/fdsnws/event/1/"
EVENT_PAGE = "https://earthquake.usgs.gov/earthquakes/eventpage/{id}"
SEED = 20261113
USER_AGENT = "KabacaContentCheck/1.0 (https://github.com/YerdemA/aralik)"


@dataclass(frozen=True)
class Event:
    id: str  # ComCat event id
    text: str
    difficulty: int
    category: str


YEARS = [
    Event("official19600522191120_30", "Kayıtlara geçmiş en büyük deprem olan Şili'deki Valdivia depremi hangi yıl olmuştur?", 2, "tarih"),
    Event("official19640328033616_30", "ABD'nin Alaska eyaletindeki Büyük Alaska depremi hangi yıl olmuştur?", 3, "tarih"),
    Event("official20041226005853450_30", "Hint Okyanusu'nda büyük tsunamiye yol açan Sumatra-Andaman depremi hangi yıl olmuştur?", 2, "tarih"),
    Event("official20110311054624120_30", "Fukuşima nükleer kazasına yol açan Japonya'daki Büyük Tōhoku depremi hangi yıl olmuştur?", 2, "tarih"),
    Event("official19521104165830_30", "Rusya'nın Kamçatka Yarımadası açıklarındaki 9,0 büyüklüğündeki deprem hangi yıl olmuştur?", 3, "tarih"),
    Event("official20100227063411530_30", "Şili'deki Maule depremi hangi yıl olmuştur?", 3, "tarih"),
    Event("official19060131153610_30", "Ekvador-Kolombiya kıyısındaki büyük deprem hangi yıl olmuştur?", 3, "tarih"),
    Event("official19500815140934_30", "Hindistan ile Tibet sınırındaki Assam-Tibet depremi hangi yıl olmuştur?", 3, "tarih"),
    Event("iscgem902291", "7,8 büyüklüğündeki büyük Erzincan depremi hangi yıl olmuştur?", 2, "türkiye"),
    Event("iscgem900102", "Tosya-Ladik depremi hangi yıl olmuştur?", 3, "türkiye"),
    Event("iscgem899277", "Bolu-Gerede depremi hangi yıl olmuştur?", 3, "türkiye"),
    Event("iscgem844692", "Muş'taki Varto depremi hangi yıl olmuştur?", 3, "türkiye"),
    Event("iscgem798506", "Kütahya'daki Gediz depremi hangi yıl olmuştur?", 3, "türkiye"),
    Event("usp0000cqe", "Diyarbakır'daki Lice depremi hangi yıl olmuştur?", 3, "türkiye"),
    Event("usp0000kf0", "Van'daki Çaldıran-Muradiye depremi hangi yıl olmuştur?", 3, "türkiye"),
    Event("usp000547c", "6,7 büyüklüğündeki, 1939'dan sonraki Erzincan depremi hangi yıl olmuştur?", 3, "türkiye"),
    Event("usp0009hev", "Düzce depremi hangi yıl olmuştur?", 2, "türkiye"),
    Event("usp000j9rr", "Van-Erciş depremi hangi yıl olmuştur?", 2, "türkiye"),
    Event("us60007ewc", "Elazığ'daki Sivrice depremi hangi yıl olmuştur?", 2, "türkiye"),
    Event("us6000jllz", "Pazarcık merkezli Kahramanmaraş depremi hangi yıl olmuştur?", 1, "türkiye"),
]

DEPTHS = [
    Event("usp0006dzc", "1994'te Bolivya'da olan 8,2 büyüklüğündeki deprem yerin kaç kilometre altında olmuştur?", 3, "bilim"),
    Event("usb000h4jh", "2013'te Okhotsk Denizi'nde olan 8,3 büyüklüğündeki deprem yerin kaç kilometre altında olmuştur?", 3, "bilim"),
]


@dataclass(frozen=True)
class Count:
    key: str
    text: str
    minmag: float
    start: str  # inclusive, UTC
    end: str  # exclusive, UTC
    compare: str  # key of the count in the fun fact
    fact: str
    difficulty: int


COUNTS = [
    Count("m7_2024", "USGS kayıtlarına göre 2024 yılında dünyada büyüklüğü 7 ve üzeri kaç deprem olmuştur?",
          7, "2024-01-01", "2025-01-01", "m7_2023", "2023 yılında: {n}.", 2),
    Count("m7_2023", "USGS kayıtlarına göre 2023 yılında dünyada büyüklüğü 7 ve üzeri kaç deprem olmuştur?",
          7, "2023-01-01", "2024-01-01", "m6_2023", "Büyüklüğü 6 ve üzeri olanlar: {n}.", 3),
    Count("m6_2024", "USGS kayıtlarına göre 2024 yılında dünyada büyüklüğü 6 ve üzeri kaç deprem olmuştur?",
          6, "2024-01-01", "2025-01-01", "m7_2024", "Büyüklüğü 7 ve üzeri olanlar: {n}.", 3),
    Count("m5_2024", "USGS kayıtlarına göre 2024 yılında dünyada büyüklüğü 5 ve üzeri kaç deprem olmuştur?",
          5, "2024-01-01", "2025-01-01", "m6_2024", "Büyüklüğü 6 ve üzeri olanlar: {n}.", 3),
    Count("m8_2000", "USGS kayıtlarına göre 2000-2025 arasında dünyada büyüklüğü 8 ve üzeri kaç deprem olmuştur?",
          8, "2000-01-01", "2026-01-01", "m9_1900", "1900'den bu yana 9 ve üzeri olanlar: {n}.", 3),
    Count("m6_2023", "", 6, "2023-01-01", "2024-01-01", "", "", 0),  # fun fact only
    Count("m9_1900", "", 9, "1900-01-01", "2026-01-01", "", "", 0),  # fun fact only
]


def get_json(url: str, attempts: int = 4):
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    for attempt in range(1, attempts + 1):
        try:
            with urllib.request.urlopen(request, timeout=90) as response:
                return json.loads(response.read().decode("utf-8"))
        except (TimeoutError, OSError) as error:
            if attempt == attempts:
                raise
            print(f"    tekrar deneniyor ({error})")
            time.sleep(5 * attempt)


def count_url(c: Count) -> str:
    params = {"format": "geojson", "starttime": c.start, "endtime": c.end, "minmagnitude": f"{c.minmag:g}"}
    return f"{FDSN}count?{urllib.parse.urlencode(params)}"


def fetch() -> dict:
    events = {}
    for e in [*YEARS, *DEPTHS]:
        f = get_json(f"{FDSN}query?{urllib.parse.urlencode({'format': 'geojson', 'eventid': e.id})}")
        p = f["properties"]
        events[e.id] = {
            "time": p["time"], "mag": p["mag"], "depth": f["geometry"]["coordinates"][2], "title": p["title"],
        }
        time.sleep(0.3)
    counts = {c.key: get_json(count_url(c))["count"] for c in COUNTS}
    payload = {"source": FDSN, "fetched": date.today().isoformat(), "events": events, "counts": counts}
    EXTRACT.parent.mkdir(parents=True, exist_ok=True)
    EXTRACT.write_text(json.dumps(payload, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"Yazıldı: {EXTRACT.relative_to(ROOT)} ({len(events)} deprem, {len(counts)} sayım)")
    return payload


def utc(ms: int) -> datetime:
    return datetime(1970, 1, 1, tzinfo=timezone.utc) + timedelta(milliseconds=ms)


def magnitude(event: dict) -> str:
    return turkish_decimal(half_up(event["mag"], 1), 1)


def build(payload: dict, bank: list[dict]) -> tuple[list[dict], list[str]]:
    asked = {(q["source"], q["kind"], q["unit"]) for q in bank}
    texts = {q["text"].casefold() for q in bank}
    data_year = int(payload["fetched"][:4])
    new, dropped = [], []

    def add(text: str, answer, unit: str, kind: str, category: str, source: str, fact: str, difficulty: int, dataset: str):
        key = (source, kind, unit)
        if key in asked or text.casefold() in texts:
            return  # imported earlier
        asked.add(key)
        texts.add(text.casefold())
        new.append(
            {
                "text": text, "answer": answer, "unit": unit, "kind": kind, "category": category,
                "source": source, "data_year": data_year, "fun_fact": fact,
                "difficulty": difficulty, "dataset": dataset,
            }
        )

    for e in YEARS:
        event = payload["events"].get(e.id)
        if event is None:
            dropped.append(f"DEPREM YOK: {e.id}")
            continue
        when = utc(event["time"])
        if (when.month, when.day) in ((1, 1), (12, 31)):
            dropped.append(f"YILBAŞI SINIRINDA: {e.id}")
            continue
        dataset = "usgs_quake_years_tr" if e.category == "türkiye" else "usgs_quake_years_world"
        mag = magnitude(event)
        fact = None if mag in e.text else f"USGS'ye göre büyüklüğü {mag}."  # no repeat of the text
        add(e.text, when.year, "", "year", e.category, EVENT_PAGE.format(id=e.id), fact, e.difficulty, dataset)

    for e in DEPTHS:
        event = payload["events"].get(e.id)
        if event is None:
            dropped.append(f"DEPREM YOK: {e.id}")
            continue
        add(e.text, half_up(event["depth"], 0), "km", "magnitude", e.category, EVENT_PAGE.format(id=e.id),
            None, e.difficulty, "usgs_quake_depth")

    by_key = {c.key: c for c in COUNTS}
    for c in COUNTS:
        if not c.text:
            continue
        n = payload["counts"].get(c.key)
        if not n:
            dropped.append(f"SAYIM YOK: {c.key}")
            continue
        other = payload["counts"][by_key[c.compare].key]
        add(c.text, n, "deprem", "magnitude", "bilim", count_url(c),
            c.fact.format(n=turkish_decimal(other, 0, grouping=True)), c.difficulty, "usgs_quake_counts")
    return new, dropped


def main(argv: list[str]) -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--fetch", action="store_true", help="USGS'den yeniden çek")
    parser.add_argument("--dry-run", action="store_true", help="bankaya yazma")
    args = parser.parse_args(argv)

    payload = fetch() if args.fetch or not EXTRACT.exists() else json.loads(EXTRACT.read_text(encoding="utf-8"))
    bank = json.loads(BANK.read_text(encoding="utf-8"))
    new, dropped = build(payload, bank)
    for line in dropped:
        print(f"  - {line}")
    for q in new:
        print(f"  + z{q['difficulty']} {q['text']} = {q['answer']} {q['unit']}  [{q['fun_fact']}]")
    print(f"{len(new)} yeni, {len(dropped)} düşürüldü.")
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
