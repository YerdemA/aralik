"""Build assets/questions/questions.json from tools/raw/*.json.

Usage:  python tools/build_questions.py [--fresh] [--dry-run] [--report]

The bank is append-only: questions already in questions.json keep their id
and position (the daily sets depend on it). New questions are shuffled with
a fixed seed and appended. --fresh rebuilds from scratch; use it only before
the first player has the app.

Numbers come only from the raw Wikidata dumps. A value is skipped when its
statements disagree (more than 1% apart, or different years, after rank
resolution).

Which items become questions is decided by how often their Turkish
Wikipedia article was read in the last 12 months (tr_views): a far better
guess of what a Turkish player has heard of than global fame. --report
prints the chosen and the next skipped items per dataset with their views.
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
MIN_DATA_YEAR = 2020  # population / capacity figures must be this recent

# Entities whose data is fine on Wikidata but makes a misleading question.
EXCLUDED = {
    "Q737945": "Cidde Kulesi henüz tamamlanmadı; 1008 m planlanan yükseklik.",
    "Q41553": "Rodos Heykeli artık yok; şimdiki zamanla sorulamaz.",
    "Q4180162": "Karapınar Düzlüğü bir dağ değil.",
    "Q200032": "Malazgirt Zaferi Günü bir anma günü; muharebenin kendisi değil.",
    "Q1033157": "Nur Dağı (Mekke) Türkiye'deki Nur Dağları ile karışır.",
    "Q125846": "Q1 adlı bina, adından anlaşılmıyor.",
    "Q1070800": "Ali Sami Yen Stadyumu yıkıldı; şimdiki zamanla sorulamaz.",
    "Q751820": "BJK İnönü Stadyumu yıkıldı; yerine Beşiktaş Stadyumu yapıldı.",
    "Q4450209": "Taksim Stadı yıkıldı.",
    "Q229": "Kıbrıs nüfusu/yüzölçümü Türk kullanıcılar için tartışmalı.",
}

FIELD_ORDER = ["id", "text", "answer", "unit", "kind", "category", "source", "data_year", "fun_fact"]


@dataclass
class Entity:
    qid: str
    label: str
    views: int
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

    def question_label(self, allow_digits: bool = True) -> str | None:
        """Label for the question text; homonyms get their place: 'Nemrut Dağı (Bitlis)'."""
        label = clean_label(self.label)
        if label is None or (not allow_digits and re.search(r"\d", label)):
            return None
        if not self.homonym:
            return label
        where = (self.extra("place") or self.extra("country"))[:1]
        return f"{label} ({where[0]})" if where else None


def load_entities(dataset: str) -> tuple[list[Entity], int]:
    path = RAW_DIR / f"{dataset}.json"
    payload = json.loads(path.read_text(encoding="utf-8"))
    fetched_year = int(payload["fetched_at"][:4])
    by_qid: dict[str, Entity] = {}
    for row in payload["rows"]:
        entity = by_qid.setdefault(row["qid"], Entity(row["qid"], row["label"], 0, []))
        entity.views = max(entity.views, row.get("tr_views", 0))
        entity.rows.append(row)
    entities = sorted(by_qid.values(), key=lambda e: (-e.views, e.qid))
    label_counts = Counter(e.label.casefold() for e in entities)
    for e in entities:
        e.homonym = label_counts[e.label.casefold()] > 1
    return entities, fetched_year


def resolve_value(
    entity: Entity, latest_year: bool = False, exact: bool = False
) -> tuple[float, int | None] | None:
    """Pick one value, or None if the statements disagree.

    latest_year: keep only the statements with the newest point in time
    (population, capacity). exact: values must be identical (years).
    """
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
    if exact and len(values) > 1:
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


def genitive(name: str) -> str:
    """Turkish genitive with an apostrophe: Almanya'nın, Çin'in, Mısır'ın, Peru'nun."""
    vowels = [c for c in name.lower() if c in "aıoueiöü"]
    last = vowels[-1] if vowels else "e"
    suffix_vowel = {"a": "ı", "ı": "ı", "o": "u", "u": "u", "e": "i", "i": "i", "ö": "ü", "ü": "ü"}[last]
    buffer = "n" if name[-1].lower() in "aıoueiöü" else ""
    return f"{name}'{buffer}{suffix_vowel}n"


def location(e: Entity) -> str | None:
    parts = e.extra("place")[:1] + e.extra("country")[:1]
    return f"Konum: {', '.join(parts)}." if parts else None


# --- Templates --------------------------------------------------------------
# Each template turns an entity into a question dict, or None to skip it.

Template = Callable[[Entity, int], "dict | None"]


def magnitude(
    text: str,
    unit: str,
    category: str,
    *,
    scale: float = 1,
    minimum: float = 0,
    latest_year: bool = False,
    fact: Callable[[Entity], str | None] = location,
    genitive_label: bool = False,
) -> Template:
    """A quantity question. `text` uses {label} and optionally {year}."""

    def build(e: Entity, fetched_year: int) -> dict | None:
        resolved = resolve_value(e, latest_year=latest_year)
        label = e.question_label()
        if not resolved or not label:
            return None
        value, value_year = resolved
        value *= scale
        if value < minimum:
            return None
        if latest_year and (value_year is None or value_year < MIN_DATA_YEAR):
            return None
        return {
            "text": text.format(label=genitive(label) if genitive_label else label, year=value_year),
            "answer": round_answer(value),
            "unit": unit,
            "kind": "magnitude",
            "category": category,
            "data_year": value_year if latest_year else fetched_year,
            "fun_fact": fact(e),
        }

    build.__qualname__ = f"magnitude[{unit}]"
    return build


def year_of(text: str, category: str, *, fact: Callable[[Entity], str | None] = location) -> Template:
    """A year question from a date property (value_kind="year" datasets)."""

    def build(e: Entity, fetched_year: int) -> dict | None:
        resolved = resolve_value(e, exact=True)
        # A year inside the label gives the answer away ("1999 Gölcük depremi").
        label = e.question_label(allow_digits=False)
        if not resolved or not label or not 0 < resolved[0] <= fetched_year:
            return None
        return {
            "text": text.format(label=label),
            "answer": int(resolved[0]),
            "unit": "",
            "kind": "year",
            "category": category,
            "data_year": fetched_year,
            "fun_fact": fact(e),
        }

    build.__qualname__ = "year"
    return build


def opened_year(category: str) -> Template:
    """Opening year from the `opened` extra (P1619) of structure datasets."""

    def build(e: Entity, fetched_year: int) -> dict | None:
        opened = e.extra("opened")
        label = e.question_label()
        if len(opened) != 1 or not label or not 0 < opened[0] <= fetched_year:
            return None
        return {
            "text": f"{label} hangi yıl açılmıştır?",
            "answer": opened[0],
            "unit": "",
            "kind": "year",
            "category": category,
            "data_year": fetched_year,
            "fun_fact": location(e),
        }

    build.__qualname__ = "opened"
    return build


def mouth(e: Entity) -> str | None:
    m = e.extra("mouth")
    return f"Döküldüğü yer: {m[0]}." if len(m) == 1 else None


def capital(e: Entity) -> str | None:
    c = e.extra("capital")
    return f"Başkenti: {c[0]}." if len(c) == 1 else None


def no_fact(_: Entity) -> None:
    return None


@dataclass(frozen=True)
class Step:
    dataset: str
    template: Template
    quota: int
    # Turkish Wikipedia reads in 12 months; below this an item is too obscure.
    min_views: int


# Fetched but not used:
# - provinces_tr: Wikidata's province populations disagree with TÜİK ADNKS.
#   Province questions will come from TÜİK files in tools/tuik/.
# - historic_buildings_tr: "inception" (P571) means start of construction for
#   some buildings and completion for others (Yeni Cami 1597 vs. finished
#   1665; Selimiye 1575 = finished), so "hangi yıl inşa edilmiştir?" has no
#   single sourced answer.
# - earthquakes_tr: every label contains the year ("1999 Gölcük depremi").
PLAN: list[Step] = [
    Step("mountains_tr", magnitude("{label} kaç metre yüksekliktedir?", "m", "coğrafya", minimum=500), 12, 15000),
    Step("mountains_world", magnitude("{label} kaç metre yüksekliktedir?", "m", "coğrafya", minimum=500), 14, 10000),
    Step("rivers_tr", magnitude("{label} kaç kilometre uzunluğundadır?", "km", "coğrafya", scale=1 / 1000, minimum=50, fact=mouth), 10, 15000),
    Step("rivers_world", magnitude("{label} kaç kilometre uzunluğundadır?", "km", "coğrafya", scale=1 / 1000, minimum=50, fact=mouth), 12, 10000),
    Step("lakes_tr", magnitude("{label} kaç kilometrekaredir?", "km²", "coğrafya", scale=1 / 1e6, minimum=1), 8, 10000),
    Step("countries_population", magnitude("{year} verilerine göre {label} nüfusu kaçtır?", "kişi", "coğrafya", latest_year=True, fact=capital, genitive_label=True), 25, 50000),
    Step("countries_area", magnitude("{label} yüzölçümü kaç kilometrekaredir?", "km²", "coğrafya", scale=1 / 1e6, minimum=1, fact=capital, genitive_label=True), 20, 50000),
    Step("structures_tr", magnitude("{label} kaç metre yüksekliğindedir?", "m", "türkiye", minimum=30), 10, 15000),
    Step("structures_world", magnitude("{label} kaç metre yüksekliğindedir?", "m", "gündelik", minimum=30), 14, 10000),
    Step("bridges_tr", magnitude("{label} kaç metre uzunluğundadır?", "m", "türkiye", minimum=100), 10, 5000),
    Step("stadiums_tr", magnitude("{label} kaç kişiliktir?", "kişi", "spor", minimum=1000), 12, 5000),
    Step("structures_tr", opened_year("tarih"), 4, 15000),
    Step("structures_world", opened_year("tarih"), 10, 10000),
    Step("bridges_tr", opened_year("türkiye"), 6, 5000),
    Step("clubs_tr", year_of("{label} hangi yıl kurulmuştur?", "spor"), 20, 15000),
    Step("universities_tr", year_of("{label} hangi yıl kurulmuştur?", "türkiye"), 15, 30000),
    Step("battles", year_of("{label} hangi yıl yaşanmıştır?", "tarih", fact=no_fact), 30, 30000),
    Step("wars", year_of("{label} hangi yıl başlamıştır?", "tarih", fact=no_fact), 20, 30000),
]


def generate(report: bool = False) -> list[dict]:
    questions: list[dict] = []
    taken: set[tuple[str, str]] = set()
    for step in PLAN:
        path = RAW_DIR / f"{step.dataset}.json"
        if not path.exists():
            print(f"  {step.dataset:22} ham veri yok, atlandı")
            continue
        entities, year = load_entities(step.dataset)
        made = skipped = 0
        chosen, passed = [], []
        for entity in entities:
            if made == step.quota or entity.views < step.min_views:
                passed.append(entity)
                continue
            if entity.qid in EXCLUDED:
                continue
            q = step.template(entity, year)
            if q is None:
                skipped += 1
                continue
            key = (entity.source, q["kind"])
            if key in taken:  # e.g. a Turkish river also in the world list
                continue
            taken.add(key)
            q["source"] = entity.source
            q["_views"] = entity.views
            questions.append(q)
            chosen.append((entity, q))
            made += 1
        name = step.template.__qualname__
        note = "" if made == step.quota else f"  (hedef {step.quota})"
        print(f"  {step.dataset:22} {name:16} {made:3} soru, {skipped} uygunsuz{note}")
        if report:
            for entity, q in chosen:
                print(f"      + {entity.views:>8,} {q['text']} = {q['answer']} {q['unit']}")
            for entity in passed[:3]:
                print(f"      - {entity.views:>8,} {entity.label}")
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
    parser.add_argument("--report", action="store_true", help="seçilenleri okunma sayılarıyla listele")
    args = parser.parse_args(argv)

    existing: list[dict] = []
    if OUT_PATH.exists() and not args.fresh:
        existing = json.loads(OUT_PATH.read_text(encoding="utf-8"))

    print("Sorular üretiliyor:")
    generated = generate(report=args.report)

    known = {(q["source"], q["kind"]): q for q in existing}
    new = []
    for q in generated:
        old = known.get((q["source"], q["kind"]))
        if old is None:
            new.append(q)
        elif old["answer"] != q["answer"]:
            print(f"  UYARI: {old['id']} cevabı değişmiş: {old['answer']} -> {q['answer']} (dokunulmadı)")

    # Within the new batch, better-known items come first: the first weeks
    # (and the closed test) should not start with the obscure tail.
    new.sort(key=lambda q: -q["_views"])
    head, tail = new[: len(new) // 2], new[len(new) // 2 :]
    rng = random.Random(f"{SEED}:{len(existing)}")
    ordered = order_for_days(head, len(existing), rng)
    ordered += order_for_days(tail, len(existing) + len(ordered), rng)
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
