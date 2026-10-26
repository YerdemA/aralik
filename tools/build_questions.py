"""Build assets/questions/questions.json from tools/raw/wikidata/*.json.

Usage:  python tools/build_questions.py [--fresh] [--dry-run] [--report]

The bank is append-only: questions already in questions.json keep their id
(the daily schedule and the players' seen questions refer to it). New
questions are shuffled with a fixed seed and appended. --fresh rebuilds from
scratch; use it only before the first player has the app. Which question
comes on which day is decided by tools/build_schedule.py, not by the order.

Every question gets its data set and a starting difficulty (1 easy, 2
medium, 3 hard), estimated from page views, category and kind (see
difficulty()). tools/difficulty_overrides.json ({"q0012": 1, ...}) fixes
single questions by hand and wins over the estimate.

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
import math
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
RAW_DIR = ROOT / "tools" / "raw" / "wikidata"
OUT_PATH = ROOT / "assets" / "questions" / "questions.json"
OVERRIDES_PATH = ROOT / "tools" / "difficulty_overrides.json"

SEED = 20261101
QUESTIONS_PER_DAY = 5
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
    "Q43502": "Dodo'nun nesli tükendi; 'kaç kilogram gelir?' diye sorulamaz.",
}

FIELD_ORDER = [
    "id", "text", "answer", "unit", "kind", "category", "source", "data_year",
    "fun_fact", "difficulty", "dataset",
]

# Starting difficulty. ease = log10(Turkish Wikipedia reads in 12 months)
# + the adjustments below; higher is easier. Familiar topics and units a
# player has a feel for are easier; whole-country figures span orders of
# magnitude nobody has a feel for. Tuned so the bank splits roughly into
# 40% easy, 40% medium and 20% hard, which is what the schedule uses.
CATEGORY_EASE = {
    "türkiye": 0.4,
    "gündelik": 0.3,
    "spor": 0.2,
    "tarih": 0.0,
    "coğrafya": -0.1,
    "bilim": -0.2,
    "hayvanlar": 0.2,
    "şirketler": 0.0,
}
KIND_EASE = {"year": 0.0, "magnitude": -0.1}
UNIT_EASE = {"kişi": -0.6, "km²": -0.6}
EASY_MIN_EASE = 4.69  # ease ≥ this → 1 (easy)
HARD_MAX_EASE = 4.12  # ease < this → 3 (hard)


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


def abroad(template: Template) -> Template:
    """Skip items in Turkey: structures_tr asks them under "türkiye"."""

    def build(e: Entity, fetched_year: int) -> dict | None:
        return None if "Türkiye" in e.extra("country") else template(e, fetched_year)

    build.__qualname__ = template.__qualname__
    return build


def tr_capitalize(text: str) -> str:
    """Upper-case the first letter the Turkish way: 'iyot' → 'İyot'."""
    if not text:
        return text
    first = {"i": "İ", "ı": "I"}.get(text[0], text[0].upper())
    return first + text[1:]


def plain_label(e: Entity) -> str | None:
    """Labels of common nouns ('demir', 'aslan') start in lower case on
    Wikidata; accept them, but still reject odd punctuation. A label equal
    to the scientific name (P225) means the species has no Turkish name,
    and then it makes no question."""
    label = e.label.strip()
    if not label or any(c in label for c in "(),/;:") or re.search(r"\d", label):
        return None
    if label.casefold() in {t.casefold() for t in e.extra("taxon")}:
        return None
    return label


def with_rows(e: Entity, rows: list[dict]) -> Entity:
    return Entity(e.qid, e.label, e.views, rows, e.homonym)


KELVIN = 273.15


def element_temperature(verb: str, *, min_celsius: float = 100) -> Template:
    """Melting or boiling point in °C. Wikidata normalizes temperatures to
    kelvin. The interval slider is logarithmic, so only clearly positive
    Celsius values are asked (no mercury or gases)."""

    def build(e: Entity, fetched_year: int) -> dict | None:
        resolved = resolve_value(e)
        label = plain_label(e)
        if not resolved or not label:
            return None
        celsius = resolved[0] - KELVIN
        if celsius < min_celsius:
            return None
        return {
            "text": f"{tr_capitalize(label)} kaç °C'de {verb}?",
            "answer": round_answer(celsius),
            "unit": "°C",
            "kind": "magnitude",
            "category": "bilim",
            "data_year": fetched_year,
            "fun_fact": None,
        }

    build.__qualname__ = f"temperature[{verb}]"
    return build


def discovered_year(*, min_year: int = 1600) -> Template:
    """Discovery year of an element; ancient ones have no meaningful year."""

    def build(e: Entity, fetched_year: int) -> dict | None:
        resolved = resolve_value(e, exact=True)
        label = plain_label(e)
        if not resolved or not label or not min_year <= resolved[0] <= fetched_year:
            return None
        return {
            "text": f"{tr_capitalize(label)} hangi yıl keşfedilmiştir?",
            "answer": int(resolved[0]),
            "unit": "",
            "kind": "year",
            "category": "bilim",
            "data_year": fetched_year,
            "fun_fact": None,
        }

    build.__qualname__ = "discovered"
    return build


# The six Nobel prizes: Turkish name in the accusative, and the category.
# Not taken from Wikidata labels: Q80061's Turkish label reads "… sahipleri
# listesi" (2026-10-26).
NOBEL_PRIZES = {
    "Q38104": ("Nobel Fizik Ödülü'nü", "bilim"),
    "Q44585": ("Nobel Kimya Ödülü'nü", "bilim"),
    "Q80061": ("Nobel Fizyoloji veya Tıp Ödülü'nü", "bilim"),
    "Q47170": ("Nobel Ekonomi Ödülü'nü", "bilim"),
    "Q37922": ("Nobel Edebiyat Ödülü'nü", "tarih"),
    "Q35637": ("Nobel Barış Ödülü'nü", "tarih"),
}


def nobel_year(e: Entity, fetched_year: int) -> dict | None:
    """Year of a person's Nobel prize. People with several Nobel statements
    (Curie, Bardeen, Sanger, ...) are skipped: one clear answer only."""
    prizes = {r.get("value_item") for r in e.rows}
    resolved = resolve_value(e, exact=True)
    label = e.question_label(allow_digits=False)
    if len(prizes) != 1 or not resolved or not label:
        return None
    prize, category = NOBEL_PRIZES[prizes.pop()]
    if not 1901 <= resolved[0] <= fetched_year:
        return None
    return {
        "text": f"{label}, {prize} hangi yıl almıştır?",
        "answer": int(resolved[0]),
        "unit": "",
        "kind": "year",
        "category": category,
        "data_year": fetched_year,
        "fun_fact": None,
    }


nobel_year.__qualname__ = "nobel"

ADULT_WEIGHT = "Q78101716"  # P3831 role: adult weight
MALE, FEMALE = "Q44148", "Q43445"


def animal_mass(e: Entity, fetched_year: int) -> dict | None:
    """Adult mass, from statements qualified as adult weight (P3831). With
    separate values per sex the male one is asked, naming the sex; a value
    without a sex is asked only when no sex-specific value exists."""
    label = plain_label(e)
    adult = [r for r in e.rows if ADULT_WEIGHT in r.get("role", [])]
    if not label or not adult:
        return None
    unsexed = [r for r in adult if not r.get("sex")]
    male = [r for r in adult if r.get("sex") == [MALE]]
    if male:
        rows, who = male, "yetişkin erkek"
    elif unsexed and not any(r.get("sex") for r in adult):
        rows, who = unsexed, "yetişkin"
    else:
        return None
    resolved = resolve_value(with_rows(e, rows))
    if not resolved:
        return None
    kg = resolved[0]
    value, unit = (kg, "kg") if kg >= 1 else (kg * 1000, "g")
    unit_word = "kilogram" if unit == "kg" else "gram"
    return {
        "text": f"{tr_capitalize(label)} ({who}) ortalama kaç {unit_word} gelir?",
        "answer": round_answer(value),
        "unit": unit,
        "kind": "magnitude",
        "category": "hayvanlar",
        "data_year": fetched_year,
        "fun_fact": None,
    }


animal_mass.__qualname__ = "animal_mass"

SECONDS_PER_YEAR = 365.25 * 24 * 3600


def animal_lifespan(e: Entity, fetched_year: int) -> dict | None:
    """Life expectancy (P2250, normalized to seconds). Statements limited to
    a sex or a setting (wild, captivity) are left out: the question could
    not say which one it means."""
    label = plain_label(e)
    rows = [r for r in e.rows if not r.get("sex") and not r.get("applies_to")]
    if not label or not rows:
        return None
    resolved = resolve_value(with_rows(e, rows))
    if not resolved:
        return None
    years = resolved[0] / SECONDS_PER_YEAR
    if years < 1:
        return None
    return {
        "text": f"{tr_capitalize(label)} ortalama kaç yıl yaşar?",
        "answer": round_answer(years),
        "unit": "yıl",
        "kind": "magnitude",
        "category": "hayvanlar",
        "data_year": fetched_year,
        "fun_fact": None,
    }


animal_lifespan.__qualname__ = "animal_lifespan"


def ease(q: dict, views: int) -> float:
    return (
        math.log10(max(views, 1))
        + CATEGORY_EASE.get(q["category"], 0.0)
        + KIND_EASE.get(q["kind"], 0.0)
        + UNIT_EASE.get(q["unit"], 0.0)
    )


def difficulty(q: dict, views: int) -> int:
    """1 easy, 2 medium, 3 hard (see CATEGORY_EASE)."""
    e = ease(q, views)
    if e >= EASY_MIN_EASE:
        return 1
    return 3 if e < HARD_MAX_EASE else 2


def load_overrides() -> dict[str, int]:
    if not OVERRIDES_PATH.exists():
        return {}
    overrides = json.loads(OVERRIDES_PATH.read_text(encoding="utf-8"))
    bad = {k: v for k, v in overrides.items() if v not in (1, 2, 3)}
    if bad:
        sys.exit(f"HATA: difficulty_overrides.json geçersiz değerler: {bad}")
    return overrides


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
    Step("mountains_tr", magnitude("{label} kaç metre yüksekliktedir?", "m", "coğrafya", minimum=500), 19, 7500),
    Step("mountains_world", magnitude("{label} kaç metre yüksekliktedir?", "m", "coğrafya", minimum=500), 22, 5000),
    Step("rivers_tr", magnitude("{label} kaç kilometre uzunluğundadır?", "km", "coğrafya", scale=1 / 1000, minimum=50, fact=mouth), 16, 7500),
    Step("rivers_world", magnitude("{label} kaç kilometre uzunluğundadır?", "km", "coğrafya", scale=1 / 1000, minimum=50, fact=mouth), 19, 5000),
    Step("lakes_tr", magnitude("{label} kaç kilometrekaredir?", "km²", "coğrafya", scale=1 / 1e6, minimum=1), 13, 5000),
    Step("countries_population", magnitude("{year} verilerine göre {label} nüfusu kaçtır?", "kişi", "coğrafya", latest_year=True, fact=capital, genitive_label=True), 40, 25000),
    Step("countries_area", magnitude("{label} yüzölçümü kaç kilometrekaredir?", "km²", "coğrafya", scale=1 / 1e6, minimum=1, fact=capital, genitive_label=True), 32, 25000),
    Step("structures_tr", magnitude("{label} kaç metre yüksekliğindedir?", "m", "türkiye", minimum=30), 16, 7500),
    Step("structures_world", magnitude("{label} kaç metre yüksekliğindedir?", "m", "gündelik", minimum=30), 22, 5000),
    Step("bridges_tr", magnitude("{label} kaç metre uzunluğundadır?", "m", "türkiye", minimum=100), 16, 2500),
    Step("stadiums_tr", magnitude("{label} kaç kişiliktir?", "kişi", "spor", minimum=1000), 19, 2500),
    Step("structures_tr", opened_year("tarih"), 6, 7500),
    Step("structures_world", opened_year("tarih"), 16, 5000),
    Step("bridges_tr", opened_year("türkiye"), 10, 2500),
    Step("clubs_tr", year_of("{label} hangi yıl kurulmuştur?", "spor"), 32, 7500),
    Step("universities_tr", year_of("{label} hangi yıl kurulmuştur?", "türkiye"), 24, 15000),
    Step("battles", year_of("{label} hangi yıl yaşanmıştır?", "tarih", fact=no_fact), 48, 15000),
    Step("wars", year_of("{label} hangi yıl başlamıştır?", "tarih", fact=no_fact), 32, 15000),
    Step("skyscrapers_world", abroad(magnitude("{label} kaç metre yüksekliğindedir?", "m", "gündelik", minimum=100)), 12, 2000),
    Step("companies_founded", year_of("{label} hangi yıl kurulmuştur?", "şirketler"), 25, 5000),
    Step("companies_employees", magnitude("{year} verilerine göre {label} kaç kişi çalıştırmaktadır?", "kişi", "şirketler", latest_year=True, minimum=100, genitive_label=False), 12, 5000),
    Step("elements_melting", element_temperature("erir"), 10, 1000),
    Step("elements_boiling", element_temperature("kaynar"), 8, 1000),
    Step("elements_discovered", discovered_year(), 12, 1000),
    Step("nobel", nobel_year, 25, 5000),
    Step("animals_mass", animal_mass, 15, 1000),
    Step("animals_lifespan", animal_lifespan, 8, 1000),
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
            q["dataset"] = step.dataset
            q["difficulty"] = difficulty(q, entity.views)
            q["_views"] = entity.views
            questions.append(q)
            chosen.append((entity, q))
            made += 1
        name = step.template.__qualname__
        note = "" if made == step.quota else f"  (hedef {step.quota})"
        print(f"  {step.dataset:22} {name:16} {made:3} soru, {skipped} uygunsuz{note}")
        if report:
            for entity, q in chosen:
                print(f"      + {entity.views:>8,} z{q['difficulty']} {q['text']} = {q['answer']} {q['unit']}")
            for entity in passed[:3]:
                print(f"      - {entity.views:>8,} {entity.label}")
    return questions


def print_difficulty_table(bank: list[dict]) -> None:
    """Difficulty × category counts, and how many days 2+2+1 allows."""
    categories = sorted({q["category"] for q in bank})
    counts = Counter((q.get("difficulty"), q["category"]) for q in bank)
    print("\nZorluk × kategori:")
    print(f"  {'':10}" + "".join(f"{c:>10}" for c in categories) + f"{'toplam':>10}")
    for d, name in ((1, "kolay"), (2, "orta"), (3, "zor")):
        row = [counts[(d, c)] for c in categories]
        print(f"  {name:10}" + "".join(f"{n:>10}" for n in row) + f"{sum(row):>10}")
    by_difficulty = Counter(q.get("difficulty") for q in bank)
    days = min(by_difficulty[1] // 2, by_difficulty[2] // 2, by_difficulty[3])
    print(f"  2 kolay + 2 orta + 1 zor ile en fazla {days} gün (kategori/veri seti kuralları hariç).")


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
            continue
        if old["answer"] != q["answer"]:
            print(f"  UYARI: {old['id']} cevabı değişmiş: {old['answer']} -> {q['answer']} (dokunulmadı)")
        # Metadata may be refreshed; the schedule does not depend on it.
        old["dataset"] = q["dataset"]
        old["difficulty"] = q["difficulty"]

    # The order does not matter for the daily sets (build_schedule.py picks
    # them); shuffle so nothing reads the file order as a ranking.
    rng = random.Random(f"{SEED}:{len(existing)}")
    rng.shuffle(new)
    next_number = max((int(q["id"][1:]) for q in existing), default=0) + 1
    for i, q in enumerate(new):
        q["id"] = f"q{next_number + i:04d}"
    bank = existing + new

    overrides = load_overrides()
    for q in bank:
        if q["id"] in overrides:
            q["difficulty"] = overrides[q["id"]]
    bank = [{key: q[key] for key in FIELD_ORDER if key in q} for q in bank]

    print(f"{len(existing)} mevcut + {len(new)} yeni = {len(bank)} soru.")
    print_difficulty_table(bank)
    if args.dry_run:
        return 0
    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUT_PATH.write_text(json.dumps(bank, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"Yazıldı: {OUT_PATH.relative_to(ROOT)}  ({date.today().isoformat()})")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
