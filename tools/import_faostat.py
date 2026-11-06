"""Crop and livestock questions from FAOSTAT (Production: Crops and livestock products).

Usage:  python tools/import_faostat.py [--fetch] [--dry-run]

QUESTIONS lists what is asked: an FAOSTAT area (223 Türkiye, 5000 World), an
item, an element (production in tonnes, animal stocks, egg numbers) and the
Turkish wording. The answer is the value of YEAR, only rounded (and scaled
where FAOSTAT counts in thousands). For Türkiye only official figures (flag
A) are used; world totals are FAO's own aggregates (A or E). Third-party
figures (flag X) and imputed ones (I) are never used.

Fun fact for Türkiye: the share of the world total of the same item, when the
world total exists.

--fetch downloads the bulk file (about 34 MB, git-ignored) and writes the
asked values to tools/raw/faostat/qcl.json (committed); without it that file
is read. FAOSTAT is CC BY 4.0 ("FAO. FAOSTAT."). FAOSTAT has no permanent
link to a single value; the source is the data page with the query in the
fragment (area, item, element, year), different for each question.
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
from dataclasses import dataclass
from datetime import date
from pathlib import Path

from rounding import half_up

ROOT = Path(__file__).resolve().parent.parent
BANK = ROOT / "assets" / "questions" / "questions.json"
RAW = ROOT / "tools" / "raw" / "faostat"
ARCHIVE = RAW / "qcl.zip"
EXTRACT = RAW / "qcl.json"
ARCHIVE_URL = "https://bulks-faostat.fao.org/production/Production_Crops_Livestock_E_All_Data_(Normalized).zip"
DATA_CSV = "Production_Crops_Livestock_E_All_Data_(Normalized).csv"
SOURCE_URL = "https://www.fao.org/faostat/en/#data/QCL?area={area}&item={item}&element={element}&year={year}"
YEAR = 2024
TURKIYE, WORLD = 223, 5000
PRODUCTION, STOCKS, STOCKS_THOUSANDS, BEEHIVES, EGGS_THOUSANDS = 5510, 5111, 5112, 5114, 5513
SEED = 20261111

ELEMENT_UNITS = {PRODUCTION: ("ton", 1), STOCKS: ("baş", 1), STOCKS_THOUSANDS: ("baş", 1000),
                 BEEHIVES: ("kovan", 1), EGGS_THOUSANDS: ("adet", 1000)}


@dataclass(frozen=True)
class Asked:
    area: int
    item: int
    element: int
    name: str  # Turkish, as it goes in the text
    difficulty: int


def tr_crop(item: int, name: str, difficulty: int = 3) -> Asked:
    return Asked(TURKIYE, item, PRODUCTION, name, difficulty)


QUESTIONS = [
    # Türkiye, production (tonnes)
    tr_crop(225, "fındık (kabuklu)", 2), tr_crop(667, "yaş çay yaprağı", 2), tr_crop(15, "buğday", 2),
    tr_crop(526, "kayısı"), tr_crop(531, "kiraz"), tr_crop(530, "vişne"), tr_crop(569, "incir"),
    tr_crop(260, "zeytin"), tr_crop(388, "domates"), tr_crop(267, "ayçiçeği tohumu"),
    tr_crop(328, "kütlü pamuk"), tr_crop(201, "kuru mercimek"), tr_crop(191, "kuru nohut"),
    tr_crop(223, "Antep fıstığı (kabuklu)"), tr_crop(560, "üzüm"), tr_crop(515, "elma"),
    tr_crop(490, "portakal"), tr_crop(497, "limon ve misket limonu"), tr_crop(495, "mandalina"),
    tr_crop(567, "karpuz"), tr_crop(116, "patates"), tr_crop(157, "şeker pancarı"),
    tr_crop(222, "ceviz (kabuklu)"), tr_crop(544, "çilek"), tr_crop(486, "muz"),
    tr_crop(826, "tütün"), tr_crop(27, "çeltik (kabuklu pirinç)"), tr_crop(56, "mısır"),
    tr_crop(44, "arpa"), tr_crop(523, "ayva"), tr_crop(221, "badem (kabuklu)"),
    tr_crop(1182, "bal"), tr_crop(882, "inek sütü"), tr_crop(1058, "tavuk eti"),
    tr_crop(403, "kuru soğan"), tr_crop(220, "kestane"),
    # Türkiye, animals
    Asked(TURKIYE, 976, STOCKS, "koyun", 2), Asked(TURKIYE, 866, STOCKS, "sığır", 2),
    Asked(TURKIYE, 1016, STOCKS, "keçi", 3), Asked(TURKIYE, 946, STOCKS, "manda", 3),
    Asked(TURKIYE, 1096, STOCKS, "at", 3), Asked(TURKIYE, 1107, STOCKS, "eşek", 3),
    Asked(TURKIYE, 1126, STOCKS, "deve", 3), Asked(TURKIYE, 1181, BEEHIVES, "arı kovanı", 3),
    Asked(TURKIYE, 1062, EGGS_THOUSANDS, "tavuk yumurtası", 3),
    # World, production (tonnes)
    Asked(WORLD, 656, PRODUCTION, "kahve (yeşil çekirdek)", 3), Asked(WORLD, 661, PRODUCTION, "kakao çekirdeği", 3),
    Asked(WORLD, 486, PRODUCTION, "muz", 3), Asked(WORLD, 27, PRODUCTION, "çeltik (kabuklu pirinç)", 3),
    Asked(WORLD, 15, PRODUCTION, "buğday", 3), Asked(WORLD, 225, PRODUCTION, "fındık (kabuklu)", 3),
    Asked(WORLD, 1182, PRODUCTION, "bal", 3), Asked(WORLD, 260, PRODUCTION, "zeytin", 3),
]


def text_of(q: Asked) -> str:
    place = "Türkiye'de" if q.area == TURKIYE else "dünyada"
    if q.element == PRODUCTION:
        return f"{YEAR} yılında {place} kaç ton {q.name} üretilmiştir?"
    if q.element == EGGS_THOUSANDS:
        return f"{YEAR} yılında {place} kaç adet {q.name} üretilmiştir?"
    if q.element == BEEHIVES:
        return f"{YEAR} verilerine göre {place} kaç {q.name} bulunmaktadır?"
    return f"{YEAR} verilerine göre {place} kaç baş {q.name} bulunmaktadır?"


def fetch() -> dict:
    RAW.mkdir(parents=True, exist_ok=True)
    if not ARCHIVE.exists():
        print(f"İndiriliyor: {ARCHIVE_URL}")
        with urllib.request.urlopen(ARCHIVE_URL, timeout=300) as response:
            ARCHIVE.write_bytes(response.read())
    # Every asked item also for the world, for the Türkiye share.
    wanted = {(q.area, q.item, q.element) for q in QUESTIONS}
    wanted |= {(WORLD, q.item, q.element) for q in QUESTIONS}
    values: dict[str, dict] = {}
    with zipfile.ZipFile(ARCHIVE) as archive:
        rows = csv.DictReader(io.TextIOWrapper(archive.open(DATA_CSV), encoding="utf-8", errors="replace"))
        for row in rows:
            if row["Year"] != str(YEAR):
                continue
            key = (int(row["Area Code"]), int(row["Item Code"]), int(row["Element Code"]))
            if key in wanted and row["Value"]:
                values[f"{key[0]}/{key[1]}/{key[2]}"] = {
                    "item": row["Item"], "value": float(row["Value"]), "unit": row["Unit"], "flag": row["Flag"],
                }
    payload = {"source": ARCHIVE_URL, "year": YEAR, "fetched": date.today().isoformat(), "values": dict(sorted(values.items()))}
    EXTRACT.write_text(json.dumps(payload, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"Yazıldı: {EXTRACT.relative_to(ROOT)} ({len(values)} değer)")
    return payload


def share_fact(q: Asked, value: float, values: dict) -> str | None:
    if q.area != TURKIYE:
        return None
    world = values.get(f"{WORLD}/{q.item}/{q.element}")
    if world is None or world["flag"] not in ("A", "E") or world["value"] <= 0:
        return None
    share = 100 * value / world["value"]
    if share < 1:
        return None
    # "payı: %59" needs no suffix that depends on the number ("%59'u", "%7'si").
    shown = f"{share:.0f}" if share >= 10 else f"{share:.1f}".replace(".", ",")
    return f"Dünyadaki payı: %{shown}."


def build(payload: dict, bank: list[dict]) -> tuple[list[dict], list[str]]:
    values = payload["values"]
    asked = {(q["source"], q["kind"], q["unit"]) for q in bank}
    texts = {q["text"].casefold() for q in bank}
    new, dropped = [], []
    for q in QUESTIONS:
        label = f"{q.area}/{q.item}/{q.element} {q.name}"
        found = values.get(f"{q.area}/{q.item}/{q.element}")
        allowed = ("A",) if q.area == TURKIYE else ("A", "E")
        if found is None or found["value"] <= 0:
            dropped.append(f"DEĞER YOK: {label}")
            continue
        if found["flag"] not in allowed:
            dropped.append(f"RESMÎ DEĞİL (flag {found['flag']}): {label}")
            continue
        unit, scale = ELEMENT_UNITS[q.element]
        value = found["value"] * scale
        text = text_of(q)
        source = SOURCE_URL.format(area=q.area, item=q.item, element=q.element, year=YEAR)
        key = (source, "magnitude", unit)
        if key in asked or text.casefold() in texts:
            continue  # imported earlier
        asked.add(key)
        texts.add(text.casefold())
        new.append(
            {
                "text": text,
                "answer": half_up(value),
                "unit": unit,
                "kind": "magnitude",
                "category": "türkiye" if q.area == TURKIYE else "gündelik",
                "source": source,
                "data_year": YEAR,
                "fun_fact": share_fact(q, found["value"], values),
                "difficulty": q.difficulty,
                "dataset": "fao_turkiye_crops" if q.area == TURKIYE and q.element == PRODUCTION
                else "fao_turkiye_animals" if q.area == TURKIYE else "fao_world",
            }
        )
    return new, dropped


def main(argv: list[str]) -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--fetch", action="store_true", help="FAOSTAT toplu dosyasından yeniden çıkar")
    parser.add_argument("--dry-run", action="store_true", help="bankaya yazma")
    args = parser.parse_args(argv)

    payload = fetch() if args.fetch or not EXTRACT.exists() else json.loads(EXTRACT.read_text(encoding="utf-8"))
    bank = json.loads(BANK.read_text(encoding="utf-8"))
    new, dropped = build(payload, bank)
    for line in dropped:
        print(f"  - {line}")
    for q in new:
        print(f"  + z{q['difficulty']} {q['text']} = {q['answer']:,} {q['unit']}  [{q['fun_fact']}]")
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
