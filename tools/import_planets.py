"""Planet questions from NASA's NSSDC Planetary Fact Sheet, appended to the bank.

Usage:  python tools/import_planets.py [--fetch] [--dry-run]

The numbers come from the comparison table at
https://nssdc.gsfc.nasa.gov/planetary/factsheet/ (one column per body).
--fetch downloads it and writes the parsed table to
tools/raw/nasa/factsheet.json (committed); without it that file is read.
QUESTIONS below only says which cell is asked and how; the answer is the
cell's value times `scale`, nothing else.

Not asked: diameter and orbital period (the bank has Wikidata's radius and
orbit questions), number of moons (changes every year), temperatures below
zero (magnitude answers are positive), Earth's axial tilt (asked by hand,
science_curated).

The source of each question is the body's own fact sheet page (marsfact.html),
which shows the same values in more detail. A body is asked at most once per
unit (validate_questions.py). The bank stays append-only. NASA content is not
under copyright in the US; NASA is credited, no endorsement implied.
"""

from __future__ import annotations

import argparse
import html
import json
import random
import re
import sys
import urllib.request
from collections import Counter
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BANK = ROOT / "assets" / "questions" / "questions.json"
RAW = ROOT / "tools" / "raw" / "nasa"
EXTRACT = RAW / "factsheet.json"
TABLE_URL = "https://nssdc.gsfc.nasa.gov/planetary/factsheet/"
PAGE_URL = "https://nssdc.gsfc.nasa.gov/planetary/factsheet/{body}fact.html"
CATEGORY = "bilim"
SEED = 20261107

# Row labels of the table, as printed (superscripts flattened).
DAY = "Length of Day (hours)"
DISTANCE = "Distance from Sun (106 km)"
ESCAPE = "Escape Velocity (km/s)"
GRAVITY = "Gravity (m/s2)"
TILT = "Obliquity to Orbit (degrees)"
TEMPERATURE = "Mean Temperature (C)"
PRESSURE = "Surface Pressure (bars)"
ORBIT = "Orbital Period (days)"
SPEED = "Orbital Velocity (km/s)"

# (body column, row, unit, dataset, difficulty, text, scale)
QUESTIONS = [
    ("MARS", DAY, "saat", "planets_day", 1, "Mars'ta bir gün (gün doğumundan gün doğumuna) kaç saat sürer?", 1),
    ("JUPITER", DAY, "saat", "planets_day", 2, "Jüpiter'de bir gün (gün doğumundan gün doğumuna) kaç saat sürer?", 1),
    ("MOON", DAY, "saat", "planets_day", 2, "Ay'da bir gün (gün doğumundan gün doğumuna) kaç saat sürer?", 1),
    ("SATURN", DAY, "saat", "planets_day", 3, "Satürn'de bir gün (gün doğumundan gün doğumuna) kaç saat sürer?", 1),
    ("URANUS", DAY, "saat", "planets_day", 3, "Uranüs'te bir gün (gün doğumundan gün doğumuna) kaç saat sürer?", 1),
    ("NEPTUNE", DAY, "saat", "planets_day", 3, "Neptün'de bir gün (gün doğumundan gün doğumuna) kaç saat sürer?", 1),
    ("PLUTO", DAY, "saat", "planets_day", 3, "Plüton'da bir gün (gün doğumundan gün doğumuna) kaç saat sürer?", 1),
    ("VENUS", DAY, "saat", "planets_day", 3, "Venüs'te bir gün (gün doğumundan gün doğumuna) kaç saat sürer?", 1),
    ("MERCURY", DAY, "saat", "planets_day", 3, "Merkür'de bir gün (gün doğumundan gün doğumuna) kaç saat sürer?", 1),
    ("EARTH", DISTANCE, "milyon km", "planets_distance", 1, "Dünya Güneş'ten ortalama kaç milyon kilometre uzaklıktadır?", 1),
    ("MOON", DISTANCE, "km", "planets_distance", 1, "Ay Dünya'dan ortalama kaç kilometre uzaklıktadır?", 1_000_000),
    ("MERCURY", DISTANCE, "milyon km", "planets_distance", 2, "Merkür Güneş'ten ortalama kaç milyon kilometre uzaklıktadır?", 1),
    ("MARS", DISTANCE, "milyon km", "planets_distance", 2, "Mars Güneş'ten ortalama kaç milyon kilometre uzaklıktadır?", 1),
    ("JUPITER", DISTANCE, "milyon km", "planets_distance", 2, "Jüpiter Güneş'ten ortalama kaç milyon kilometre uzaklıktadır?", 1),
    ("VENUS", DISTANCE, "milyon km", "planets_distance", 3, "Venüs Güneş'ten ortalama kaç milyon kilometre uzaklıktadır?", 1),
    ("SATURN", DISTANCE, "milyon km", "planets_distance", 3, "Satürn Güneş'ten ortalama kaç milyon kilometre uzaklıktadır?", 1),
    ("URANUS", DISTANCE, "milyon km", "planets_distance", 3, "Uranüs Güneş'ten ortalama kaç milyon kilometre uzaklıktadır?", 1),
    ("NEPTUNE", DISTANCE, "milyon km", "planets_distance", 3, "Neptün Güneş'ten ortalama kaç milyon kilometre uzaklıktadır?", 1),
    ("PLUTO", DISTANCE, "milyon km", "planets_distance", 3, "Plüton Güneş'ten ortalama kaç milyon kilometre uzaklıktadır?", 1),
    ("EARTH", ESCAPE, "km/s", "planets_physics", 2, "Bir roketin Dünya'nın çekiminden kurtulması için saniyede kaç kilometre hıza ulaşması gerekir?", 1),
    ("MOON", ESCAPE, "km/s", "planets_physics", 3, "Bir roketin Ay'ın çekiminden kurtulması için saniyede kaç kilometre hıza ulaşması gerekir?", 1),
    ("JUPITER", ESCAPE, "km/s", "planets_physics", 3, "Bir roketin Jüpiter'in çekiminden kurtulması için saniyede kaç kilometre hıza ulaşması gerekir?", 1),
    ("MARS", TILT, "°", "planets_physics", 3, "Mars'ın dönme ekseni yörüngesine göre kaç derece eğiktir?", 1),
    ("URANUS", TILT, "°", "planets_physics", 3, "Uranüs'ün dönme ekseni yörüngesine göre kaç derece eğiktir?", 1),
    ("VENUS", TEMPERATURE, "°C", "planets_physics", 2, "Venüs'ün ortalama yüzey sıcaklığı kaç °C'dir?", 1),
    ("VENUS", PRESSURE, "bar", "planets_physics", 3, "Dünya'da deniz seviyesinde hava basıncı yaklaşık 1 bardır. Venüs'ün yüzeyinde kaç bardır?", 1),
    ("MOON", GRAVITY, "m/s²", "planets_physics", 2, "Dünya'da yerçekimi ivmesi 9,8 m/s²'dir. Ay'da kaç m/s²'dir?", 1),
    ("JUPITER", GRAVITY, "m/s²", "planets_physics", 3, "Dünya'da yerçekimi ivmesi 9,8 m/s²'dir. Jüpiter'in bulut tepelerinde kaç m/s²'dir?", 1),
]

NAMES_TR = {
    "MERCURY": "Merkür", "VENUS": "Venüs", "EARTH": "Dünya", "MOON": "Ay", "MARS": "Mars",
    "JUPITER": "Jüpiter", "SATURN": "Satürn", "URANUS": "Uranüs", "NEPTUNE": "Neptün", "PLUTO": "Plüton",
}


def cell_text(cell: str) -> str:
    return re.sub(r"\s+", " ", html.unescape(re.sub(r"<.*?>", "", cell, flags=re.S))).strip()


def fetch() -> dict:
    RAW.mkdir(parents=True, exist_ok=True)
    request = urllib.request.Request(TABLE_URL, headers={"User-Agent": "KabacaContentCheck/1.0 (https://github.com/YerdemA/aralik)"})
    with urllib.request.urlopen(request, timeout=60) as response:
        page = response.read().decode("latin-1")
    rows = []
    for row in re.findall(r"<tr.*?</tr>", page, re.S | re.I):
        rows.append([cell_text(c) for c in re.findall(r"<t[dh].*?>(.*?)</t[dh]>", row, re.S | re.I)])
    bodies = rows[0][1:]
    table = {row[0]: dict(zip(bodies, row[1:])) for row in rows[1:] if row and row[0]}
    updated = re.search(r"Last Updated:\s*([^,<]+)", page)
    payload = {
        "source": TABLE_URL,
        "last_updated": updated.group(1).strip() if updated else None,
        "fetched": date.today().isoformat(),
        "table": table,
    }
    EXTRACT.write_text(json.dumps(payload, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"Yazıldı: {EXTRACT.relative_to(ROOT)} ({len(table)} satır, güncelleme: {payload['last_updated']})")
    return payload


def number(text: str) -> float | None:
    """'1,432.0' → 1432.0; '0.384*' → 0.384; 'Unknown*' → None."""
    match = re.fullmatch(r"-?[\d,]+(\.\d+)?\*?", text)
    return float(text.rstrip("*").replace(",", "")) if match else None


def tidy(value: float) -> int | float:
    """Drops float noise from the scaling; keeps the table's precision."""
    value = round(value, 6)
    return int(value) if value == int(value) else value


def turkish_number(value: float) -> str:
    whole, _, fraction = f"{value:,.1f}".rstrip("0").rstrip(".").partition(".")
    whole = whole.replace(",", ".")
    return f"{whole},{fraction}" if fraction else whole


def fun_fact(body: str, row: str, table: dict) -> str | None:
    """Another number of the same body from the same table."""
    if row == DAY:
        orbit = number(table[ORBIT][body])
        if body == "MOON":
            return f"Dünya çevresindeki bir turu {turkish_number(orbit)} Dünya günü sürer."
        return f"Bir yılı {turkish_number(orbit)} Dünya günü sürer."
    if row == DISTANCE and body != "MOON":
        speed = number(table[SPEED][body])
        return f"Güneş çevresinde saniyede {turkish_number(speed)} km hızla dolanır."
    return None


def data_year(last_updated: str | None) -> int:
    found = re.search(r"\d{4}", last_updated or "")
    return int(found.group()) if found else date.today().year


def build(payload: dict, bank: list[dict]) -> tuple[list[dict], list[str]]:
    table = payload["table"]
    asked = {(q["source"], q["kind"], q["unit"]) for q in bank}
    texts = {q["text"].casefold() for q in bank}
    new, dropped = [], []
    for body, row, unit, dataset, difficulty, text, scale in QUESTIONS:
        label = f"{NAMES_TR[body]} / {row}"
        value = number(table.get(row, {}).get(body, ""))
        if value is None or value <= 0:
            dropped.append(f"DEĞER YOK: {label}")
            continue
        source = PAGE_URL.format(body=body.lower())
        key = (source, "magnitude", unit)
        if text.casefold() in texts:
            continue  # imported earlier
        if key in asked:
            dropped.append(f"AYNI KAYNAK VE BİRİM: {label}")
            continue
        asked.add(key)
        texts.add(text.casefold())
        new.append(
            {
                "text": text,
                "answer": tidy(value * scale),
                "unit": unit,
                "kind": "magnitude",
                "category": CATEGORY,
                "source": source,
                "data_year": data_year(payload.get("last_updated")),
                "fun_fact": fun_fact(body, row, table),
                "difficulty": difficulty,
                "dataset": dataset,
            }
        )
    return new, dropped


def main(argv: list[str]) -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--fetch", action="store_true", help="NASA tablosunu yeniden indir")
    parser.add_argument("--dry-run", action="store_true", help="bankaya yazma")
    args = parser.parse_args(argv)

    if args.fetch or not EXTRACT.exists():
        payload = fetch()
    else:
        payload = json.loads(EXTRACT.read_text(encoding="utf-8"))

    bank = json.loads(BANK.read_text(encoding="utf-8"))
    new, dropped = build(payload, bank)
    for line in dropped:
        print(f"  - {line}")
    for q in new:
        print(f"  + z{q['difficulty']} {q['text']} = {q['answer']} {q['unit']}  [{q['fun_fact']}]")
    print(f"{len(QUESTIONS)} soru tanımı, {len(new)} yeni, {len(dropped)} düşürüldü.")
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
