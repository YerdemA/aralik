"""Animal questions from AnAge (The Animal Ageing and Longevity Database, HAGR).

Usage:  python tools/import_anage.py [--fetch] [--dry-run]

QUESTIONS lists the species (scientific name), what is asked and the Turkish
text; the number comes from AnAge only:

  gestation  "Gestation/Incubation (days)", whole days
  longevity  "Maximum longevity (yrs)", the longest recorded life
  birth      "Birth weight (g)", in kg from 1 kg up, else in g

Only records with "Data quality" high or acceptable are used; a longevity
also needs a "Sample size". Left out on purpose: gestations with delayed
implantation (bears, giant panda) where AnAge's figure is not what people
mean, and animals whose lifespan or gestation the bank already asks (dog and
cat gestation, gorilla and pigeon lifespan, polar bear, koala lifespan).

--fetch downloads the AnAge zip (git-ignored) and writes the listed species
to tools/raw/anage/anage.json (committed); without it that file is read.
AnAge is CC BY 3.0 (HAGR, de Magalhães et al.). The source of a question is
the species' AnAge entry.
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

from rounding import half_up

ROOT = Path(__file__).resolve().parent.parent
BANK = ROOT / "assets" / "questions" / "questions.json"
RAW = ROOT / "tools" / "raw" / "anage"
ARCHIVE = RAW / "anage.zip"
EXTRACT = RAW / "anage.json"
ARCHIVE_URL = "https://genomics.senescence.info/species/dataset.zip"
SOURCE_URL = "https://genomics.senescence.info/species/entry.php?species={genus}_{species}"
GOOD_QUALITY = ("high", "acceptable")
SEED = 20261112
USER_AGENT = "KabacaContentCheck/1.0 (https://github.com/YerdemA/aralik)"

COLUMNS = {
    "gestation": "Gestation/Incubation (days)",
    "longevity": "Maximum longevity (yrs)",
    "birth": "Birth weight (g)",
}
DATASETS = {"gestation": "anage_gestation", "longevity": "anage_longevity", "birth": "anage_birth_weight"}

# (scientific name, asked, difficulty, text). Birth texts end in "kaç {unit} gelir?"
# and get the unit word filled in.
QUESTIONS = [
    ("Loxodonta africana", "gestation", 2, "Bir Afrika filinin gebelik süresi kaç gündür?"),
    ("Giraffa camelopardalis", "gestation", 3, "Bir zürafanın gebelik süresi kaç gündür?"),
    ("Equus caballus", "gestation", 2, "Bir atın gebelik süresi kaç gündür?"),
    ("Ovis aries", "gestation", 2, "Bir koyunun gebelik süresi kaç gündür?"),
    ("Capra hircus", "gestation", 3, "Bir keçinin gebelik süresi kaç gündür?"),
    ("Pan troglodytes", "gestation", 3, "Bir şempanzenin gebelik süresi kaç gündür?"),
    ("Gorilla gorilla", "gestation", 3, "Bir gorilin gebelik süresi kaç gündür?"),
    ("Panthera leo", "gestation", 3, "Bir aslanın gebelik süresi kaç gündür?"),
    ("Panthera tigris", "gestation", 3, "Bir kaplanın gebelik süresi kaç gündür?"),
    ("Hippopotamus amphibius", "gestation", 3, "Bir su aygırının gebelik süresi kaç gündür?"),
    ("Camelus dromedarius", "gestation", 3, "Tek hörgüçlü bir devenin gebelik süresi kaç gündür?"),
    ("Balaenoptera musculus", "gestation", 3, "Bir mavi balinanın gebelik süresi kaç gündür?"),
    ("Orcinus orca", "gestation", 3, "Bir katil balinanın gebelik süresi kaç gündür?"),
    ("Tursiops truncatus", "gestation", 3, "Bir şişe burunlu yunusun gebelik süresi kaç gündür?"),
    ("Oryctolagus cuniculus", "gestation", 2, "Bir tavşanın gebelik süresi kaç gündür?"),
    ("Mus musculus", "gestation", 3, "Bir ev faresinin gebelik süresi kaç gündür?"),
    ("Sus scrofa", "gestation", 3, "Bir yaban domuzunun gebelik süresi kaç gündür?"),
    ("Ceratotherium simum", "gestation", 3, "Bir beyaz gergedanın gebelik süresi kaç gündür?"),
    ("Canis lupus", "gestation", 3, "Bir kurdun gebelik süresi kaç gündür?"),
    ("Macropus giganteus", "gestation", 3, "Bir doğu gri kangurusunun gebelik süresi kaç gündür?"),
    ("Acinonyx jubatus", "gestation", 3, "Bir çitanın gebelik süresi kaç gündür?"),
    ("Phascolarctos cinereus", "gestation", 3, "Bir koalanın gebelik süresi kaç gündür?"),
    ("Delphinapterus leucas", "gestation", 3, "Bir beluganın gebelik süresi kaç gündür?"),
    ("Columba livia", "gestation", 3, "Bir güvercin yumurtası kaç günde çatlar?"),
    ("Anas platyrhynchos", "gestation", 3, "Bir yeşilbaş ördek yumurtası kaç günde çatlar?"),
    ("Balaena mysticetus", "longevity", 3, "Grönland balinası için kaydedilen en uzun ömür kaç yıldır?"),
    ("Chelonoidis nigra", "longevity", 2, "Galapagos kaplumbağası için kaydedilen en uzun ömür kaç yıldır?"),
    ("Somniosus microcephalus", "longevity", 3, "Grönland köpekbalığı için kaydedilen en uzun ömür kaç yıldır?"),
    ("Arctica islandica", "longevity", 3, "İzlanda deniz tarağı (Arctica islandica) için kaydedilen en uzun ömür kaç yıldır?"),
    ("Proteus anguinus", "longevity", 3, "Mağara semenderi (olm) için kaydedilen en uzun ömür kaç yıldır?"),
    ("Heterocephalus glaber", "longevity", 3, "Çıplak köstebek faresi için kaydedilen en uzun ömür kaç yıldır?"),
    ("Elephas maximus", "longevity", 2, "Asya fili için kaydedilen en uzun ömür kaç yıldır?"),
    ("Equus caballus", "longevity", 2, "At için kaydedilen en uzun ömür kaç yıldır?"),
    ("Bubo bubo", "longevity", 3, "Puhu için kaydedilen en uzun ömür kaç yıldır?"),
    ("Psittacus erithacus", "longevity", 3, "Jako papağanı için kaydedilen en uzun ömür kaç yıldır?"),
    ("Cacatua galerita", "longevity", 3, "Sarı tepeli kakadu için kaydedilen en uzun ömür kaç yıldır?"),
    ("Cyprinus carpio", "longevity", 3, "Sazan balığı için kaydedilen en uzun ömür kaç yıldır?"),
    ("Mus musculus", "longevity", 3, "Ev faresi için kaydedilen en uzun ömür kaç yıldır?"),
    ("Pan troglodytes", "longevity", 3, "Şempanze için kaydedilen en uzun ömür kaç yıldır?"),
    ("Balaenoptera musculus", "longevity", 3, "Mavi balina için kaydedilen en uzun ömür kaç yıldır?"),
    ("Homarus americanus", "longevity", 3, "Amerikan ıstakozu için kaydedilen en uzun ömür kaç yıldır?"),
    ("Acipenser fulvescens", "longevity", 3, "Göl mersin balığı için kaydedilen en uzun ömür kaç yıldır?"),
    ("Hippopotamus amphibius", "longevity", 3, "Su aygırı için kaydedilen en uzun ömür kaç yıldır?"),
    ("Balaenoptera musculus", "birth", 2, "Yeni doğmuş bir mavi balina yavrusu kaç {unit} gelir?"),
    ("Elephas maximus", "birth", 2, "Yeni doğmuş bir Asya fili yavrusu kaç {unit} gelir?"),
    ("Giraffa camelopardalis", "birth", 3, "Yeni doğmuş bir zürafa yavrusu kaç {unit} gelir?"),
    ("Hippopotamus amphibius", "birth", 3, "Yeni doğmuş bir su aygırı yavrusu kaç {unit} gelir?"),
    ("Orcinus orca", "birth", 3, "Yeni doğmuş bir katil balina yavrusu kaç {unit} gelir?"),
    ("Ailuropoda melanoleuca", "birth", 3, "Yeni doğmuş bir dev panda yavrusu kaç {unit} gelir?"),
    ("Macropus giganteus", "birth", 3, "Yeni doğmuş bir doğu gri kangurusu yavrusu kaç {unit} gelir?"),
    ("Phascolarctos cinereus", "birth", 3, "Yeni doğmuş bir koala yavrusu kaç {unit} gelir?"),
    ("Ursus arctos", "birth", 3, "Yeni doğmuş bir boz ayı yavrusu kaç {unit} gelir?"),
    ("Panthera leo", "birth", 3, "Yeni doğmuş bir aslan yavrusu kaç {unit} gelir?"),
    ("Equus caballus", "birth", 3, "Yeni doğmuş bir tay kaç {unit} gelir?"),
]

UNIT_WORDS = {"kg": "kilogram", "g": "gram"}


def fetch(names: set[str]) -> dict:
    RAW.mkdir(parents=True, exist_ok=True)
    if not ARCHIVE.exists():
        print(f"İndiriliyor: {ARCHIVE_URL}")
        request = urllib.request.Request(ARCHIVE_URL, headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(request, timeout=120) as response:
            ARCHIVE.write_bytes(response.read())
    with zipfile.ZipFile(ARCHIVE) as archive:
        table = archive.read("anage_data.txt").decode("latin-1")
        release = archive.read("release.html").decode("latin-1") if "release.html" in archive.namelist() else ""
    species = {}
    for row in csv.DictReader(io.StringIO(table), delimiter="\t"):
        name = f"{row['Genus']} {row['Species']}"
        if name in names:
            keep = ["HAGRID", "Common name", *COLUMNS.values(), "Specimen origin", "Sample size", "Data quality"]
            species[name] = {key: row[key] for key in keep}
    build_line = next((line.strip() for line in release.splitlines() if "Build" in line), None)
    payload = {"source": ARCHIVE_URL, "release": build_line, "fetched": date.today().isoformat(),
               "species": dict(sorted(species.items()))}
    EXTRACT.write_text(json.dumps(payload, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"Yazıldı: {EXTRACT.relative_to(ROOT)} ({len(species)} tür)")
    return payload


def build(payload: dict, bank: list[dict]) -> tuple[list[dict], list[str]]:
    year = int(payload["fetched"][:4])
    asked = {(q["source"], q["kind"], q["unit"]) for q in bank}
    texts = {q["text"].casefold() for q in bank}
    new, dropped = [], []
    for name, what, difficulty, text in QUESTIONS:
        label = f"{name} {what}"
        row = payload["species"].get(name)
        if row is None:
            dropped.append(f"VERİDE YOK: {label}")
            continue
        raw = row[COLUMNS[what]]
        if not raw or float(raw) <= 0:
            dropped.append(f"DEĞER YOK: {label}")
            continue
        if row["Data quality"] not in GOOD_QUALITY:
            dropped.append(f"KALİTE '{row['Data quality']}': {label}")
            continue
        if what == "longevity" and not row["Sample size"]:
            dropped.append(f"ÖRNEK SAYISI YOK: {label}")
            continue
        value = float(raw)
        fact = None
        if what == "gestation":
            unit, answer = "gün", half_up(value)
        elif what == "longevity":
            unit, answer = "yıl", int(value) if value == int(value) else half_up(value, 1)
            origin = {"captivity": "Kayıt bakım altındaki bir bireye ait.", "wild": "Kayıt doğada yaşayan bir bireye ait."}
            fact = origin.get(row["Specimen origin"])
        else:
            unit = "kg" if value >= 1000 else "g"
            number = value / 1000 if unit == "kg" else value
            answer = half_up(number) if number >= 10 else half_up(number, 2 if number < 1 else 1)
            text = text.format(unit=UNIT_WORDS[unit])
        genus, species = name.split(" ")
        source = SOURCE_URL.format(genus=genus, species=species)
        key = (source, "magnitude", unit)
        if key in asked or text.casefold() in texts:
            continue  # imported earlier
        asked.add(key)
        texts.add(text.casefold())
        new.append(
            {
                "text": text,
                "answer": answer,
                "unit": unit,
                "kind": "magnitude",
                "category": "hayvanlar",
                "source": source,
                "data_year": year,
                "fun_fact": fact,
                "difficulty": difficulty,
                "dataset": DATASETS[what],
            }
        )
    return new, dropped


def main(argv: list[str]) -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--fetch", action="store_true", help="AnAge arşivinden yeniden çıkar")
    parser.add_argument("--dry-run", action="store_true", help="bankaya yazma")
    args = parser.parse_args(argv)

    names = {name for name, *_ in QUESTIONS}
    if args.fetch or not EXTRACT.exists():
        payload = fetch(names)
    else:
        payload = json.loads(EXTRACT.read_text(encoding="utf-8"))
        missing = names - payload["species"].keys()
        if missing:
            sys.exit(f"HATA: {len(missing)} tür {EXTRACT.name} içinde yok, --fetch ile çalıştırın: {sorted(missing)}")

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
