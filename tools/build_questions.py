"""Build assets/questions/questions.json from tools/raw/*.json.

Usage:  python tools/build_questions.py [--fresh] [--dry-run]

The bank is append-only: questions already in questions.json keep their id
and position (the daily sets depend on it). New questions are shuffled with
a fixed seed and appended. --fresh rebuilds from scratch; use it only before
the first release.

Numbers come only from the raw Wikidata dumps. A value is skipped when its
statements disagree (more than 1% apart after rank resolution).
"""

from __future__ import annotations

import argparse
import json
import random
import re
import sys
from collections import Counter
from dataclasses import dataclass
from datetime import date
from decimal import ROUND_HALF_UP, Decimal
from pathlib import Path
from typing import Callable

ROOT = Path(__file__).resolve().parent.parent
RAW_DIR = ROOT / "tools" / "raw"
OUT_PATH = ROOT / "assets" / "questions" / "questions.json"

SEED = 20261101
QUESTIONS_PER_DAY = 5
MAX_SAME_CATEGORY_PER_DAY = 2
AMBIGUITY_TOLERANCE = 0.01
MIN_POPULATION_YEAR = 2020

# Entities whose data is fine on Wikidata but makes a misleading question.
EXCLUDED = {
    "Q737945": "Cidde Kulesi henüz tamamlanmadı; 1008 m planlanan yükseklik.",
    "Q41553": "Rodos Heykeli artık yok; şimdiki zamanla sorulamaz.",
    "Q4180162": "Karapınar Düzlüğü bir dağ değil.",
}

FIELD_ORDER = ["id", "text", "answer", "unit", "kind", "category", "source", "data_year", "fun_fact"]


@dataclass
class Entity:
    qid: str
    label: str
    links: int
    rows: list[dict]
    # Set when another entity in the dataset has the same label.
    homonym: bool = False

    @property
    def source(self) -> str:
        return f"https://www.wikidata.org/wiki/{self.qid}"

    def extra(self, name: str) -> list:
        """Union of an extra field across this entity's rows."""
        values: list = []
        for row in self.rows:
            for value in row.get(name, []):
                if isinstance(value, str):
                    value = re.sub(r"\s*\(.*?\)", "", value).strip()  # "Çiftlik (ilçe)"
                if value and value not in values:
                    values.append(value)
        return values

    def question_label(self) -> str | None:
        """Label for the question text; homonyms get their place: 'Nemrut Dağı (Bitlis)'."""
        label = clean_label(self.label)
        if label is None or not self.homonym:
            return label
        where = (self.extra("place") or self.extra("country"))[:1]
        return f"{label} ({where[0]})" if where else None


def load_entities(dataset: str) -> tuple[list[Entity], int]:
    path = RAW_DIR / f"{dataset}.json"
    payload = json.loads(path.read_text(encoding="utf-8"))
    fetched_year = int(payload["fetched_at"][:4])
    by_qid: dict[str, Entity] = {}
    for row in payload["rows"]:
        entity = by_qid.setdefault(
            row["qid"], Entity(row["qid"], row["label"], row["links"], [])
        )
        entity.rows.append(row)
    entities = sorted(by_qid.values(), key=lambda e: (-e.links, e.qid))
    label_counts = Counter(e.label.casefold() for e in entities)
    for e in entities:
        e.homonym = label_counts[e.label.casefold()] > 1
    return entities, fetched_year


def resolve_value(entity: Entity, latest_year: bool = False) -> tuple[float, int | None] | None:
    """Pick one value, or None if the statements disagree."""
    rows = entity.rows
    if latest_year:
        dated = [r for r in rows if r["value_year"] is not None]
        if not dated:
            return None
        newest = max(r["value_year"] for r in dated)
        rows = [r for r in dated if r["value_year"] == newest]
    preferred = [r for r in rows if r["rank"] == "preferred"]
    if preferred:
        rows = preferred
    values = sorted({r["value"] for r in rows})
    if not values or values[0] <= 0:
        return None
    if values[-1] / values[0] - 1 > AMBIGUITY_TOLERANCE:
        return None
    return values[0], rows[0]["value_year"]


def round_answer(value: float) -> int | float:
    """Half-up rounding: integers from 100 up, otherwise one decimal."""
    digits = Decimal("1") if value >= 100 else Decimal("0.1")
    rounded = Decimal(str(value)).quantize(digits, rounding=ROUND_HALF_UP)
    return int(rounded) if rounded == rounded.to_integral() else float(rounded)


def clean_label(label: str) -> str | None:
    """Reject labels that read badly inside a Turkish question."""
    label = label.strip()
    if not label or label[0].islower() or any(c in label for c in "(),/;:"):
        return None
    return label


def join_tr(values: list[str], limit: int = 3) -> str:
    return ", ".join(values[:limit])


# --- Templates --------------------------------------------------------------
# Each template turns an entity into a question dict, or None to skip it.

Template = Callable[[Entity, int], dict | None]


def mountain(category: str, fact_field: str, fact_prefix: str) -> Template:
    def build(e: Entity, year: int) -> dict | None:
        resolved = resolve_value(e)
        label = e.question_label()
        if not resolved or not label or resolved[0] < 500:
            return None
        facts = e.extra(fact_field)
        return {
            "text": f"{label} kaç metre yüksekliktedir?",
            "answer": round_answer(resolved[0]),
            "unit": "m",
            "kind": "magnitude",
            "category": category,
            "data_year": year,
            "fun_fact": f"{fact_prefix}: {join_tr(facts)}." if facts else None,
        }

    return build


def river(e: Entity, year: int) -> dict | None:
    resolved = resolve_value(e)
    label = e.question_label()
    if not resolved or not label:
        return None
    km = resolved[0] / 1000
    if km < 50:
        return None
    mouth = e.extra("mouth")
    return {
        "text": f"{label} kaç kilometre uzunluğundadır?",
        "answer": round_answer(km),
        "unit": "km",
        "kind": "magnitude",
        "category": "coğrafya",
        "data_year": year,
        "fun_fact": f"Döküldüğü yer: {join_tr(mouth, 1)}." if len(mouth) == 1 else None,
    }


def province(e: Entity, year: int) -> dict | None:
    resolved = resolve_value(e, latest_year=True)
    label = e.question_label()
    if not resolved or not label:
        return None
    population, value_year = resolved
    if value_year is None or value_year < MIN_POPULATION_YEAR:
        return None
    name = label.removesuffix(" ili").removesuffix(" İli")
    plate = e.extra("plate")
    return {
        "text": f"{value_year} verilerine göre {name} ilinin nüfusu kaçtır?",
        "answer": int(population),
        "unit": "kişi",
        "kind": "magnitude",
        "category": "türkiye",
        "data_year": value_year,
        "fun_fact": f"Plaka kodu: {plate[0]}." if len(plate) == 1 else None,
    }


def structure_location(e: Entity) -> str | None:
    parts = e.extra("place")[:1] + e.extra("country")[:1]
    return f"Konum: {', '.join(parts)}." if parts else None


def structure_height(category: str) -> Template:
    def build(e: Entity, year: int) -> dict | None:
        resolved = resolve_value(e)
        label = e.question_label()
        if not resolved or not label or resolved[0] < 30:
            return None
        return {
            "text": f"{label} kaç metre yüksekliğindedir?",
            "answer": round_answer(resolved[0]),
            "unit": "m",
            "kind": "magnitude",
            "category": category,
            "data_year": year,
            "fun_fact": structure_location(e),
        }

    return build


def structure_opened(e: Entity, year: int) -> dict | None:
    opened = e.extra("opened")
    label = e.question_label()
    # Exactly one opening year, otherwise the answer is ambiguous.
    if len(opened) != 1 or not label or not 0 < opened[0] <= year:
        return None
    return {
        "text": f"{label} hangi yıl açılmıştır?",
        "answer": opened[0],
        "unit": "",
        "kind": "year",
        "category": "tarih",
        "data_year": year,
        "fun_fact": structure_location(e),
    }


# (raw dataset, template, how many questions to take)
# provinces_tr is fetched but not used: Wikidata's province populations
# disagree with TÜİK ADNKS (e.g. its preferred 2021 value for Bursa is ~250k
# too low). Province questions will come from TÜİK CSVs in tools/tuik/.
PLAN: list[tuple[str, Template, int]] = [
    ("mountains_tr", mountain("coğrafya", "place", "Konum"), 25),
    ("mountains_world", mountain("coğrafya", "country", "Ülke"), 30),
    ("rivers_tr", river, 20),
    ("rivers_world", river, 25),
    ("structures_tr", structure_height("türkiye"), 15),
    ("structures_world", structure_height("gündelik"), 25),
    ("structures_tr", structure_opened, 4),
    ("structures_world", structure_opened, 10),
]


def generate() -> list[dict]:
    questions: list[dict] = []
    taken: set[tuple[str, str]] = set()
    for dataset, template, quota in PLAN:
        entities, year = load_entities(dataset)
        made = skipped = 0
        for entity in entities:
            if made == quota:
                break
            if entity.qid in EXCLUDED:
                continue
            q = template(entity, year)
            if q is None:
                skipped += 1
                continue
            key = (entity.source, q["kind"])
            if key in taken:  # e.g. a Turkish river also in the world list
                continue
            taken.add(key)
            q["source"] = entity.source
            questions.append(q)
            made += 1
        name = template.__qualname__.split(".")[0]
        note = "" if made == quota else f"  (hedef {quota}, veri yetmedi)"
        print(f"  {dataset:17} {name:17} {made:3} soru, {skipped} atlandı{note}")
    return questions


def order_for_days(questions: list[dict], offset: int, rng: random.Random) -> list[dict]:
    """Spread categories evenly, then greedily avoid repeating a source or
    flooding a category within a day."""
    # Stratified shuffle: the k-th of n questions in a category sorts near
    # position k/n, so every category is spread over the whole bank instead
    # of the largest one piling up at the end.
    by_category: dict[str, list[dict]] = {}
    for q in questions:
        by_category.setdefault(q["category"], []).append(q)
    keyed = []
    for category in sorted(by_category):
        group = by_category[category]
        rng.shuffle(group)
        for k, q in enumerate(group):
            keyed.append(((k + rng.random()) / len(group), q))
    keyed.sort(key=lambda kq: kq[0])
    pool = [q for _, q in keyed]
    ordered: list[dict] = []
    while pool:
        day_start = ((offset + len(ordered)) // QUESTIONS_PER_DAY) * QUESTIONS_PER_DAY - offset
        day = ordered[max(day_start, 0) :]
        sources = {q["source"] for q in day}
        categories = Counter(q["category"] for q in day)

        def fits(q: dict, strict: bool) -> bool:
            if q["source"] in sources:
                return False
            return not strict or categories[q["category"]] < MAX_SAME_CATEGORY_PER_DAY

        # The category rule only looks a few items ahead, so it varies a day
        # locally without dragging a big category towards the end.
        window = pool[:QUESTIONS_PER_DAY]
        pick = next((q for q in window if fits(q, True)), None)
        pick = pick or next((q for q in pool if fits(q, False)), pool[0])
        pool.remove(pick)
        ordered.append(pick)
    return ordered


def main(argv: list[str]) -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--fresh", action="store_true", help="mevcut bankayı yok say")
    parser.add_argument("--dry-run", action="store_true", help="dosyaya yazma")
    args = parser.parse_args(argv)

    existing: list[dict] = []
    if OUT_PATH.exists() and not args.fresh:
        existing = json.loads(OUT_PATH.read_text(encoding="utf-8"))

    print("Sorular üretiliyor:")
    generated = generate()

    known = {(q["source"], q["kind"]): q for q in existing}
    new = []
    for q in generated:
        old = known.get((q["source"], q["kind"]))
        if old is None:
            new.append(q)
        elif old["answer"] != q["answer"]:
            print(f"  UYARI: {old['id']} cevabı değişmiş: {old['answer']} -> {q['answer']} (dokunulmadı)")

    rng = random.Random(f"{SEED}:{len(existing)}")
    ordered = order_for_days(new, len(existing), rng)
    next_number = max((int(q["id"][1:]) for q in existing), default=0) + 1
    for i, q in enumerate(ordered):
        q["id"] = f"q{next_number + i:04d}"
    bank = existing + [{key: q[key] for key in FIELD_ORDER} for q in ordered]

    print(f"{len(existing)} mevcut + {len(ordered)} yeni = {len(bank)} soru "
          f"({len(bank) // QUESTIONS_PER_DAY} gün).")
    if args.dry_run:
        return 0
    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUT_PATH.write_text(json.dumps(bank, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"Yazıldı: {OUT_PATH.relative_to(ROOT)}  ({date.today().isoformat()})")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
