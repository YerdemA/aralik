"""Food questions from USDA FoodData Central (SR Legacy), appended to the bank.

Usage:  python tools/import_foods.py [--fetch] [--dry-run]

tools/foods_tr.csv lists the foods (FDC id, nutrient, difficulty, the start of
USDA's English description, and the Turkish place phrase: "100 gram muzda").
Every answer is the value per 100 g in SR Legacy, only rounded:

  energy     kcal, whole number        "100 gram muzda kaç kalori var?"
  protein    g, whole number from 10   "... kaç gram protein var?"
  caffeine   mg, whole number          "... kaç miligram kafein var?"
  vitamin_c  mg, whole number from 10  "... kaç miligram C vitamini var?"

--fetch downloads the SR Legacy CSV archive (about 6 MB, git-ignored) and
writes the values of the listed foods to tools/raw/usda/sr_legacy_foods.json
(small, committed), so the bank can be rebuilt without the archive. Without
--fetch that file is read; foods missing from it stop the run.

A row is dropped when USDA's description does not start with the given text
(a mistyped id), the value is missing or zero, or the bank already asks about
the same food with the same unit. The bank stays append-only.
SR Legacy is USDA's final release of April 2018 (data_year 2018); CC0.
"""

from __future__ import annotations

import argparse
import csv
import io
import json
import random
import sys
import urllib.request
import zipfile
from collections import Counter
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FOODS = ROOT / "tools" / "foods_tr.csv"
BANK = ROOT / "assets" / "questions" / "questions.json"
RAW = ROOT / "tools" / "raw" / "usda"
ARCHIVE = RAW / "sr_legacy.zip"
EXTRACT = RAW / "sr_legacy_foods.json"
ARCHIVE_URL = "https://fdc.nal.usda.gov/fdc-datasets/FoodData_Central_sr_legacy_food_csv_2018-04.zip"
SOURCE_URL = "https://fdc.nal.usda.gov/food-details/{fdc_id}/nutrients"
DATA_YEAR = 2018
CATEGORY = "gündelik"
SEED = 20261106

# SR Legacy nutrient ids (nutrient.csv).
NUTRIENT_IDS = {"1008": "energy", "1003": "protein", "2000": "sugars", "1057": "caffeine", "1162": "vitamin_c"}

# nutrient → (question ending, unit, data set, value below which one decimal is kept)
ASKED = {
    "energy": ("kaç kalori var?", "kcal", "foods_energy", 0),
    "protein": ("kaç gram protein var?", "g", "foods_protein", 10),
    "caffeine": ("kaç miligram kafein var?", "mg", "foods_caffeine", 0),
    "vitamin_c": ("kaç miligram C vitamini var?", "mg", "foods_vitamin_c", 10),
}


def read_rows(path: Path = FOODS) -> list[dict]:
    rows = []
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split(";")
        if len(parts) != 5:
            sys.exit(f"HATA: satır biçimi bozuk: {line}")
        fdc_id, nutrient, difficulty, description, place = (p.strip() for p in parts)
        if nutrient not in ASKED:
            sys.exit(f"HATA: bilinmeyen besin '{nutrient}': {line}")
        if difficulty not in ("1", "2", "3"):
            sys.exit(f"HATA: zorluk 1, 2 ya da 3 olmalı: {line}")
        rows.append(
            {"fdc_id": fdc_id, "nutrient": nutrient, "difficulty": int(difficulty), "description": description, "place": place}
        )
    return rows


def fetch(ids: set[str]) -> dict:
    """Values of the given foods from the SR Legacy archive."""
    RAW.mkdir(parents=True, exist_ok=True)
    if not ARCHIVE.exists():
        print(f"İndiriliyor: {ARCHIVE_URL}")
        request = urllib.request.Request(ARCHIVE_URL, headers={"User-Agent": "KabacaContentCheck/1.0 (https://github.com/YerdemA/aralik)"})
        with urllib.request.urlopen(request, timeout=120) as response:
            ARCHIVE.write_bytes(response.read())
    foods: dict[str, dict] = {}
    with zipfile.ZipFile(ARCHIVE) as archive:

        def table(name: str):
            member = next(n for n in archive.namelist() if n.endswith("/" + name))
            return csv.DictReader(io.TextIOWrapper(archive.open(member), encoding="utf-8"))

        for row in table("food.csv"):
            if row["fdc_id"] in ids:
                foods[row["fdc_id"]] = {"description": row["description"], "per_100g": {}}
        for row in table("food_nutrient.csv"):
            food = foods.get(row["fdc_id"])
            name = NUTRIENT_IDS.get(row["nutrient_id"])
            if food is not None and name is not None:
                food["per_100g"][name] = float(row["amount"])
    payload = {
        "source": ARCHIVE_URL,
        "fetched": date.today().isoformat(),
        "foods": dict(sorted(foods.items(), key=lambda item: int(item[0]))),
    }
    EXTRACT.write_text(json.dumps(payload, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"Yazıldı: {EXTRACT.relative_to(ROOT)} ({len(foods)} yiyecek)")
    return payload


def rounded(value: float, decimals_below: float) -> int | float:
    if value < decimals_below:
        return round(value, 1)
    return int(round(value))


def turkish_number(value: float) -> str:
    text = f"{value:.1f}".rstrip("0").rstrip(".")
    return text.replace(".", ",")


def fun_fact(nutrient: str, values: dict) -> str | None:
    """Another number of the same food from the same record."""
    if nutrient == "energy":
        protein, sugars = values.get("protein"), values.get("sugars")
        if protein is None:
            return None
        if sugars is None:
            return f"Aynı 100 gramda {turkish_number(protein)} g protein var."
        return f"Aynı 100 gramda {turkish_number(protein)} g protein ve {turkish_number(sugars)} g şeker var."
    energy = values.get("energy")
    return None if energy is None else f"Aynı 100 gram {turkish_number(energy)} kcal."


def build(rows: list[dict], foods: dict, bank: list[dict]) -> tuple[list[dict], list[str]]:
    asked = {(q["source"], q["kind"], q["unit"]) for q in bank}
    texts = {q["text"].casefold() for q in bank}
    new, dropped = [], []
    for row in rows:
        ending, unit, dataset, decimals_below = ASKED[row["nutrient"]]
        label = f"{row['fdc_id']} {row['nutrient']} ({row['place']})"
        food = foods.get(row["fdc_id"])
        if food is None:
            dropped.append(f"VERİDE YOK: {label}")
            continue
        if not food["description"].startswith(row["description"]):
            dropped.append(f"AÇIKLAMA TUTMUYOR: {label}: USDA '{food['description']}'")
            continue
        value = food["per_100g"].get(row["nutrient"])
        if not value:
            dropped.append(f"DEĞER YOK: {label}")
            continue
        source = SOURCE_URL.format(fdc_id=row["fdc_id"])
        text = f"100 gram {row['place']} {ending}"
        key = (source, "magnitude", unit)
        if key in asked or text.casefold() in texts:
            continue  # imported earlier
        asked.add(key)
        texts.add(text.casefold())
        new.append(
            {
                "text": text,
                "answer": rounded(value, decimals_below),
                "unit": unit,
                "kind": "magnitude",
                "category": CATEGORY,
                "source": source,
                "data_year": DATA_YEAR,
                "fun_fact": fun_fact(row["nutrient"], food["per_100g"]),
                "difficulty": row["difficulty"],
                "dataset": dataset,
            }
        )
    return new, dropped


def main(argv: list[str]) -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--fetch", action="store_true", help="USDA arşivinden değerleri yeniden çıkar")
    parser.add_argument("--dry-run", action="store_true", help="bankaya yazma")
    args = parser.parse_args(argv)

    rows = read_rows()
    ids = {row["fdc_id"] for row in rows}
    if args.fetch or not EXTRACT.exists():
        payload = fetch(ids)
    else:
        payload = json.loads(EXTRACT.read_text(encoding="utf-8"))
        missing = ids - payload["foods"].keys()
        if missing:
            sys.exit(f"HATA: {len(missing)} yiyecek {EXTRACT.name} içinde yok, --fetch ile çalıştırın: {sorted(missing)}")

    bank = json.loads(BANK.read_text(encoding="utf-8"))
    new, dropped = build(rows, payload["foods"], bank)
    for line in dropped:
        print(f"  - {line}")
    for q in new:
        print(f"  + z{q['difficulty']} {q['text']} = {q['answer']} {q['unit']}")
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
