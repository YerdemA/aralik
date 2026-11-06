"""Brain and body mass questions from AnimalTraits (Herberstein et al., 2022).

Usage:  python tools/import_animaltraits.py [--fetch] [--dry-run]

QUESTIONS lists the species and the Turkish text. The answer is the median of
all AnimalTraits observations of that species for the trait ("brain size" in
grams, or "body mass" in milligrams for small animals), only rounded. When
there is more than one observation the fun fact says how many; for a brain it
also gives the median body mass of the same observations. A brain size from a
single observation without body mass is not asked (cattle and wild boar had
one 1908 measurement each).

Most well-known large animals (elephant, horse, cat, dolphin) are not in
AnimalTraits; QUESTIONS holds what is.

--fetch downloads observations.csv from Zenodo (git-ignored) and writes the
listed species to tools/raw/animaltraits/animaltraits.json (committed);
without it that file is read. AnimalTraits is CC0 (Zenodo record 6468938).
There is no page per species; the source is the Zenodo record with the
species and trait in the fragment.
"""

from __future__ import annotations

import argparse
import csv
import io
import json
import random
import statistics
import sys
import urllib.request
from collections import Counter
from datetime import date
from pathlib import Path

from rounding import half_up, turkish_decimal

ROOT = Path(__file__).resolve().parent.parent
BANK = ROOT / "assets" / "questions" / "questions.json"
RAW = ROOT / "tools" / "raw" / "animaltraits"
CSV_PATH = RAW / "observations.csv"
EXTRACT = RAW / "animaltraits.json"
CSV_URL = "https://zenodo.org/records/6468938/files/observations.csv?download=1"
SOURCE_URL = "https://zenodo.org/records/6468938#{trait}={species}"
SEED = 20261113
USER_AGENT = "KabacaContentCheck/1.0 (https://github.com/YerdemA/aralik)"

# (species, trait, unit, difficulty, text)
QUESTIONS = [
    ("Homo sapiens", "brain", "g", 2, "Yetişkin bir insanın beyni kaç gram gelir?"),
    ("Pan troglodytes", "brain", "g", 3, "Bir şempanzenin beyni kaç gram gelir?"),
    ("Gorilla gorilla", "brain", "g", 3, "Bir gorilin beyni kaç gram gelir?"),
    ("Pongo pygmaeus", "brain", "g", 3, "Bir Borneo orangutanının beyni kaç gram gelir?"),
    ("Macaca mulatta", "brain", "g", 3, "Bir rhesus maymununun beyni kaç gram gelir?"),
    ("Canis lupus", "brain", "g", 3, "Bir kurdun beyni kaç gram gelir?"),
    ("Canis familiaris", "brain", "g", 3, "Bir köpeğin beyni kaç gram gelir?"),
    ("Panthera leo", "brain", "g", 3, "Bir aslanın beyni kaç gram gelir?"),
    ("Panthera tigris", "brain", "g", 3, "Bir kaplanın beyni kaç gram gelir?"),
    # Bos taurus (q1817) and Sus scrofa (q1818) were here: one 1908
    # measurement each, no body mass. q1817 now cites Ballarin et al. 2016,
    # q1818 is retired.
    ("Ursus arctos", "brain", "g", 3, "Bir boz ayının beyni kaç gram gelir?"),
    ("Ursus maritimus", "brain", "g", 3, "Bir kutup ayısının beyni kaç gram gelir?"),
    ("Rattus norvegicus", "brain", "g", 3, "Bir sıçanın beyni kaç gram gelir?"),
    ("Oryctolagus cuniculus", "brain", "g", 3, "Bir tavşanın beyni kaç gram gelir?"),
    ("Macropus giganteus", "brain", "g", 3, "Bir doğu gri kangurusunun beyni kaç gram gelir?"),
    ("Phascolarctos cinereus", "brain", "g", 3, "Bir koalanın beyni kaç gram gelir?"),
    ("Vulpes vulpes", "brain", "g", 3, "Bir kızıl tilkinin beyni kaç gram gelir?"),
    ("Struthio camelus", "brain", "g", 3, "Bir deve kuşunun beyni kaç gram gelir?"),
    ("Columba livia", "brain", "g", 3, "Bir güvercinin beyni kaç gram gelir?"),
    ("Passer domesticus", "brain", "g", 3, "Bir serçenin beyni kaç gram gelir?"),
    ("Erinaceus europaeus", "brain", "g", 3, "Bir kirpinin beyni kaç gram gelir?"),
    ("Apis mellifera", "brain", "mg", 3, "Bir bal arısının beyni kaç miligram gelir?"),
    # Not the honey bee's mass: the brain question's fun fact gives it away.
    ("Periplaneta americana", "mass", "mg", 3, "Bir Amerikan hamamböceği kaç miligram gelir?"),
    ("Drosophila melanogaster", "mass", "mg", 3, "Bir sirke sineği kaç miligram gelir?"),
    ("Acheta domesticus", "mass", "mg", 3, "Bir ev cırcır böceği kaç miligram gelir?"),
    ("Solenopsis invicta", "mass", "mg", 3, "Bir ateş karıncası kaç miligram gelir?"),
    ("Latrodectus mactans", "mass", "mg", 3, "Bir karadul örümceği kaç miligram gelir?"),
]

COLUMNS = {"brain": "brain size", "mass": "body mass"}  # both in kg in the standardised columns
TO_UNIT = {"g": 1e3, "mg": 1e6}
DATASETS = {"brain": "animaltraits_brain", "mass": "animaltraits_mass"}


def fetch(names: set[str]) -> dict:
    RAW.mkdir(parents=True, exist_ok=True)
    if not CSV_PATH.exists():
        print(f"İndiriliyor: {CSV_URL}")
        request = urllib.request.Request(CSV_URL, headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(request, timeout=120) as response:
            CSV_PATH.write_bytes(response.read())
    species: dict[str, list[dict]] = {}
    text = CSV_PATH.read_text(encoding="utf-8", errors="replace")
    for row in csv.DictReader(io.StringIO(text)):
        if row["species"] in names:
            species.setdefault(row["species"], []).append(
                {
                    "brain_kg": float(row["brain size"]) if row["brain size"] else None,
                    "brain_units": row["brain size - units"],
                    "mass_kg": float(row["body mass"]) if row["body mass"] else None,
                    "mass_units": row["body mass - units"],
                    "reference": row["inTextReference"],
                }
            )
    payload = {"source": CSV_URL, "fetched": date.today().isoformat(), "species": dict(sorted(species.items()))}
    EXTRACT.write_text(json.dumps(payload, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"Yazıldı: {EXTRACT.relative_to(ROOT)} ({len(species)} tür)")
    return payload


def rounded(value: float) -> int | float:
    result = half_up(value) if value >= 100 else half_up(value, 1 if value >= 10 else 2)
    return int(result) if result == int(result) else result


def build(payload: dict, bank: list[dict]) -> tuple[list[dict], list[str]]:
    year = int(payload["fetched"][:4])
    asked = {(q["source"], q["kind"], q["unit"]) for q in bank}
    texts = {q["text"].casefold() for q in bank}
    new, dropped = [], []
    for name, trait, unit, difficulty, text in QUESTIONS:
        label = f"{name} {trait}"
        observations = payload["species"].get(name, [])
        key_kg, key_units = f"{trait}_kg", f"{trait}_units"
        measured = [o for o in observations if o[key_kg] is not None]
        if not measured:
            dropped.append(f"ÖLÇÜM YOK: {label}")
            continue
        if any(o[key_units] != "kg" for o in measured):
            dropped.append(f"BİRİM kg DEĞİL: {label}")
            continue
        if trait == "brain" and len(measured) == 1 and measured[0]["mass_kg"] is None:
            dropped.append(f"TEK ÖLÇÜM, VÜCUT AĞIRLIĞI YOK: {label}")
            continue
        answer = rounded(statistics.median(o[key_kg] for o in measured) * TO_UNIT[unit])
        parts = []
        if len(measured) > 1:
            parts.append(f"{len(measured)} ölçümün ortancası.")
        if trait == "brain":
            bodies = [o["mass_kg"] for o in measured if o["mass_kg"] is not None]
            if bodies:
                body = statistics.median(bodies)
                if body >= 1:
                    shown = f"{turkish_decimal(body, 1, strip=True, grouping=True)} kg"
                elif body >= 0.001:
                    shown = f"{half_up(body * 1000)} g"
                else:
                    shown = f"{turkish_decimal(body * 1e6, 1, strip=True)} mg"
                parts.append(f"Ölçülen bireylerin vücut ağırlığı: {shown}.")
        source = SOURCE_URL.format(trait=COLUMNS[trait].replace(" ", "_"), species=name.replace(" ", "_"))
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
                "fun_fact": " ".join(parts) or None,
                "difficulty": difficulty,
                "dataset": DATASETS[trait],
            }
        )
    return new, dropped


def main(argv: list[str]) -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--fetch", action="store_true", help="AnimalTraits dosyasından yeniden çıkar")
    parser.add_argument("--dry-run", action="store_true", help="bankaya yazma")
    args = parser.parse_args(argv)

    names = {name for name, *_ in QUESTIONS}
    payload = fetch(names) if args.fetch or not EXTRACT.exists() else json.loads(EXTRACT.read_text(encoding="utf-8"))
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
