"""Istanbul questions from the İBB Open Data Portal (data.ibb.gov.tr).

Usage:  python tools/import_ibb.py [--fetch] [--dry-run]

Each question is computed from one data set by a small function in
QUESTIONS (a single cell, a column sum or a year total). Years are fixed by
hand to the latest year that is surely complete (2025 figures were still
partial for some sets when this was written, 2026-11-06), and the year is in
every question text.

--fetch downloads the files into tools/raw/ibb/ (git-ignored) and writes the
computed values to tools/raw/ibb/ibb.json (committed); without it that file
is read. Licence: İBB Açık Veri Lisansı 1.0 (commercial use allowed,
attribution required). The source is the data set's page; when one data set
gives several questions with the same unit, the fragment tells them apart.
"""

from __future__ import annotations

import argparse
import csv
import json
import random
import sys
import urllib.request
from collections import Counter, defaultdict
from dataclasses import dataclass
from datetime import date
from pathlib import Path
from typing import Callable

import openpyxl

from rounding import half_up

ROOT = Path(__file__).resolve().parent.parent
BANK = ROOT / "assets" / "questions" / "questions.json"
RAW = ROOT / "tools" / "raw" / "ibb"
EXTRACT = RAW / "ibb.json"
PAGE_URL = "https://data.ibb.gov.tr/dataset/{name}"
SEED = 20261114
USER_AGENT = "KabacaContentCheck/1.0 (https://github.com/YerdemA/aralik)"

FILES = {
    "su.xlsx": ("kisi-basi-cekilen-gunluk-su-miktari",
                "https://data.ibb.gov.tr/dataset/1530d08d-aec9-4c97-a63b-2a9279ba23df/resource/d82998dd-1032-47ff-91c6-1387a273dc32/download/kisi-bas-cekilen-gunluk-su-miktar.xlsx"),
    "turist.csv": ("milliyetlerine-gore-istanbul-a-gelen-yabanci-turist-sayisi",
                   "https://data.ibb.gov.tr/dataset/cbae904d-dcf1-4059-b1db-260fe747fe79/resource/9c90499f-5472-4fba-a8d4-fa8dd0521077/download/milliyetlerine-gore-istanbul-a-gelen-yabanci-turist-sayisi.csv"),
    "vapur.xlsx": ("sehir-hatlari-a-s-denizyolu-tasimaciligi",
                   "https://data.ibb.gov.tr/dataset/f5999383-140b-43a4-b274-0df6c7ba5904/resource/dbe63c15-e49a-4b49-b3bd-308e4e0a5d87/download/sehir-hatlar-a.s.-denizyolu-tasimaciligi.xlsx"),
    "istanbulkart.xlsx": ("istanbulkart-yillara-ve-kart-tiplerine-gore-kullanim-verisi",
                          "https://data.ibb.gov.tr/dataset/deb594e7-918a-4356-b74b-043197609362/resource/9a9f943e-3ed6-44a9-8f70-4f3873a65429/download/istanbulkart-yllara-ve-kartlara-gore-gecis-adetleri.xlsx"),
    "atik.xlsx": ("evsel-atik-miktari",
                  "https://data.ibb.gov.tr/dataset/31d85b21-32a9-4270-95d9-a1712a6567ea/resource/50036dfd-aea5-4f06-832f-f7020fdaaa5a/download/ilce-baznda-yllk-evsel-atk-miktarlar.xlsx"),
    "hayvan.xlsx": ("yillara-gore-hayvan-istatistikleri",
                    "https://data.ibb.gov.tr/dataset/b75b0c2a-8a6e-42ab-821b-deb437d7ea70/resource/e79ac29b-ab5c-4bb1-a575-a92548cd5caf/download/yllara-gore-hayvan-istatistikleri-2004_2025.xlsx"),
    "tiyatro.csv": ("tiyatro-seyirci-sayisi",
                    "https://data.ibb.gov.tr/dataset/e120f33f-5c2a-486c-8c21-ee2f95e509a5/resource/73bc0a0b-779e-4f26-a46c-96beac0c3291/download/tiyatro-seyirci-says.csv"),
}


def sheet(name: str) -> list[tuple]:
    workbook = openpyxl.load_workbook(RAW / name, read_only=True, data_only=True)
    return list(workbook.worksheets[0].iter_rows(values_only=True))


def row_by_label(rows: list[tuple], label: str) -> dict:
    header = rows[0]
    for row in rows:
        if row[0] and str(row[0]).strip().startswith(label):
            return dict(zip(header, row))
    raise KeyError(label)


def number(value) -> float:
    if isinstance(value, (int, float)):
        return float(value)
    return float(str(value).replace(".", "").replace(",", ".").rstrip("*"))


def water(year: int) -> float:
    return next(number(r[1]) for r in sheet("su.xlsx")[1:] if r[0] == year)


def tourists(year: int, nationality: str | None = None) -> float:
    total = 0
    months = set()
    with open(RAW / "turist.csv", encoding="utf-8-sig") as handle:
        for row in csv.DictReader(handle):
            if row["tarih"].startswith(str(year)) and (nationality is None or row["uyruk"] == nationality):
                total += int(row["ziyaretci_sayisi"] or 0)
                months.add(row["tarih"][5:7])
    if len(months) != 12:
        raise ValueError(f"{year}: {len(months)} ay")
    return total


def ferry(label: str, year: int, scale: float) -> Callable[[], float]:
    return lambda: number(row_by_label(sheet("vapur.xlsx"), label)[year]) * scale


def istanbulkart(year: int) -> float:
    return sum(r[4] or 0 for r in sheet("istanbulkart.xlsx")[1:] if r[0] == year)


def waste(year: int) -> float:
    rows = sheet("atik.xlsx")
    column = rows[0].index(str(year))
    return sum(number(r[column]) for r in rows[1:] if r[0] and "oplam" not in str(r[0]) and r[column] is not None)


def animals(column: str, year: int) -> float:
    rows = sheet("hayvan.xlsx")
    index = rows[0].index(column)
    return next(number(r[index]) for r in rows[1:] if r[0] == year)


def theatre(year: int) -> float:
    with open(RAW / "tiyatro.csv", encoding="utf-8-sig") as handle:
        for row in csv.reader(handle, delimiter=";"):
            if row and row[0] == str(year):
                return number(row[1]) + number(row[2])
    raise KeyError(year)


@dataclass(frozen=True)
class Asked:
    key: str  # unique, also the fragment of the source when needed
    file: str
    compute: Callable[[], float]
    year: int
    unit: str
    difficulty: int
    text: str
    fragment: bool = False


QUESTIONS = [
    Asked("su2022", "su.xlsx", lambda: water(2022), 2022, "litre", 2,
          "2022 yılında İstanbul'da şebekeye kişi başına günde ortalama kaç litre su verilmiştir?"),
    Asked("turist2023", "turist.csv", lambda: tourists(2023), 2023, "kişi", 2,
          "2023 yılında İstanbul'a kaç yabancı turist gelmiştir?", fragment=True),
    Asked("turist2023-rusya", "turist.csv", lambda: tourists(2023, "Rusya"), 2023, "kişi", 3,
          "2023 yılında İstanbul'a Rusya'dan kaç turist gelmiştir?", fragment=True),
    Asked("turist2023-almanya", "turist.csv", lambda: tourists(2023, "Almanya"), 2023, "kişi", 3,
          "2023 yılında İstanbul'a Almanya'dan kaç turist gelmiştir?", fragment=True),
    Asked("turist2023-iran", "turist.csv", lambda: tourists(2023, "İran"), 2023, "kişi", 3,
          "2023 yılında İstanbul'a İran'dan kaç turist gelmiştir?", fragment=True),
    Asked("vapur2024-yolcu", "vapur.xlsx", ferry("Yıllık Taşınan Yolcu", 2024, 1000), 2024, "kişi", 3,
          "2024 yılında Şehir Hatları vapurları kaç yolcu taşımıştır?"),
    Asked("vapur2024-sefer", "vapur.xlsx", ferry("Sefer", 2024, 1000), 2024, "sefer", 3,
          "2024 yılında Şehir Hatları vapurları kaç sefer yapmıştır?"),
    Asked("istanbulkart2024", "istanbulkart.xlsx", lambda: istanbulkart(2024), 2024, "geçiş", 2,
          "2024 yılında İstanbulkart ile toplu taşımada kaç geçiş yapılmıştır?"),
    Asked("atik2024", "atik.xlsx", lambda: waste(2024), 2024, "ton", 3,
          "2024 yılında İstanbul'da kaç ton evsel atık toplanmıştır?"),
    Asked("hayvan2024-kisir", "hayvan.xlsx", lambda: animals("Kısırlaştırılan Hayvan Sayısı", 2024), 2024, "hayvan", 3,
          "2024 yılında İBB veteriner hizmetleri kaç hayvanı kısırlaştırmıştır?", fragment=True),
    Asked("hayvan2024-tedavi", "hayvan.xlsx", lambda: animals("Muayene ve Tedavi Edilen Hayvan Sayısı", 2024), 2024, "hayvan", 3,
          "2024 yılında İBB veteriner hizmetlerinde kaç hayvan muayene ve tedavi edilmiştir?", fragment=True),
    Asked("tiyatro2024", "tiyatro.csv", lambda: theatre(2024), 2024, "seyirci", 3,
          "2024 yılında İstanbul'da tiyatro oyunlarını kaç seyirci izlemiştir?"),
]

# Fun facts, from the same files, never another question's answer.
FACTS: dict[str, Callable[[], str]] = {
    "su2022": lambda: f"2001'de {half_up(water(2001))} litreydi.",
    "turist2023": lambda: "En çok turist gönderen ülkeler sırasıyla Rusya, Almanya ve İran.",
    "vapur2024-yolcu": lambda: f"2013'te {str(half_up(number(row_by_label(sheet('vapur.xlsx'), 'Yıllık Taşınan Yolcu')[2013]) / 1000, 1)).replace('.', ',')} milyon yolcu taşınmıştı.",
    "vapur2024-sefer": lambda: f"2024'te Şehir Hatları filosunda {half_up(number(row_by_label(sheet('vapur.xlsx'), 'Gemi/Motor')[2024]))} gemi vardı.",
    "istanbulkart2024": lambda: f"Salgın yılı 2020'de {str(half_up(istanbulkart(2020) / 1e9, 2)).replace('.', ',')} milyardı.",
    "atik2024": lambda: f"2004'te {str(half_up(waste(2004) / 1e6, 1)).replace('.', ',')} milyon tondu.",
    "tiyatro2024": lambda: f"2002'de {str(half_up(theatre(2002) / 1e6, 1)).replace('.', ',')} milyondu.",
}


def fetch() -> dict:
    RAW.mkdir(parents=True, exist_ok=True)
    for name, (_, url) in FILES.items():
        path = RAW / name
        if not path.exists():
            print(f"İndiriliyor: {name}")
            request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
            with urllib.request.urlopen(request, timeout=120) as response:
                path.write_bytes(response.read())
    values = {}
    for q in QUESTIONS:
        fact = FACTS.get(q.key)
        values[q.key] = {"value": q.compute(), "fact": fact() if fact else None}
    payload = {"fetched": date.today().isoformat(), "values": values}
    EXTRACT.write_text(json.dumps(payload, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"Yazıldı: {EXTRACT.relative_to(ROOT)} ({len(values)} değer)")
    return payload


def build(payload: dict, bank: list[dict]) -> tuple[list[dict], list[str]]:
    asked = {(q["source"], q["kind"], q["unit"]) for q in bank}
    texts = {q["text"].casefold() for q in bank}
    new, dropped = [], []
    for q in QUESTIONS:
        found = payload["values"].get(q.key)
        if found is None or found["value"] <= 0:
            dropped.append(f"DEĞER YOK: {q.key}")
            continue
        source = PAGE_URL.format(name=FILES[q.file][0]) + (f"#{q.key}" if q.fragment else "")
        key = (source, "magnitude", q.unit)
        if key in asked or q.text.casefold() in texts:
            continue  # imported earlier
        asked.add(key)
        texts.add(q.text.casefold())
        new.append(
            {
                "text": q.text,
                "answer": half_up(found["value"]),
                "unit": q.unit,
                "kind": "magnitude",
                "category": "gündelik",
                "source": source,
                "data_year": q.year,
                "fun_fact": found["fact"],
                "difficulty": q.difficulty,
                "dataset": "ibb_istanbul",
            }
        )
    return new, dropped


def main(argv: list[str]) -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--fetch", action="store_true", help="İBB dosyalarını indirip yeniden hesapla")
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
