"""Long-run history questions from Our World in Data.

Usage:  python tools/import_owid.py [--fetch] [--dry-run]

Only data compiled by OWID itself is CC BY: a chart is used only if every
column's citation says "with major processing by Our World in Data" (checked
on --fetch). Charts with "minor processing" are third-party data under their
own licence (urbanization from HYDE, nuclear warheads from FAS), and the
COVID-19 vaccination chart is now WHO data (CC BY-NC-SA), so they are not
used.

Each question in QUESTIONS has its own text; the fun fact gives the same
series in another year (compare year). Values are only rounded: populations
to 4 significant digits (they are estimates), the rest to the decimals of
the metric.

--fetch downloads the charts' CSV and metadata from the grapher and writes
only the values used (and the citations) to tools/raw/owid/owid.json
(committed); without it that file is read. The source of a question is the
chart, opened at that country and year.
"""

from __future__ import annotations

import argparse
import csv
import io
import json
import random
import sys
import time
import urllib.request
from collections import Counter
from dataclasses import dataclass
from datetime import date
from pathlib import Path

from rounding import half_up, turkish_decimal

ROOT = Path(__file__).resolve().parent.parent
BANK = ROOT / "assets" / "questions" / "questions.json"
EXTRACT = ROOT / "tools" / "raw" / "owid" / "owid.json"
GRAPHER = "https://ourworldindata.org/grapher/"
SEED = 20261112
USER_AGENT = "KabacaContentCheck/1.0 (https://github.com/YerdemA/aralik)"
OWN_DATA = "with major processing by Our World in Data"


@dataclass(frozen=True)
class Metric:
    slug: str  # grapher chart
    column: str  # CSV column (short name)
    unit: str
    decimals: int | None  # None: 4 significant digits
    dataset: str
    category: str


METRICS = {
    "population": Metric("population", "population_historical", "kişi", None, "owid_population_history", "tarih"),
    "life": Metric("life-expectancy", "life_expectancy_0", "yıl", 1, "owid_life_expectancy_history", "tarih"),
    "literacy": Metric("cross-country-literacy-rates", "literacy_rate", "%", 1, "owid_literacy_history", "tarih"),
    "space": Metric(
        "yearly-number-of-objects-launched-into-outer-space", "annual_launches", "nesne", 0,
        "owid_space_objects", "bilim",
    ),
}

# OWID entity code → name in the CSV
ENTITIES = {
    "OWID_WRL": "World", "TUR": "Turkey", "CHN": "China", "IND": "India", "JPN": "Japan",
    "SWE": "Sweden", "GBR": "United Kingdom", "USA": "United States", "RUS": "Russia",
}


@dataclass(frozen=True)
class Question:
    metric: str
    code: str
    year: int
    difficulty: int
    text: str
    compare: int  # the year of the fun fact
    fact: str = "{year} yılında: {value}."


QUESTIONS = [
    # Population: HYDE, Gapminder and UN WPP joined by OWID; today's borders.
    Question("population", "OWID_WRL", 1000, 3, "1000 yılında dünya nüfusu tahminen kaçtı?", 2023),
    Question("population", "OWID_WRL", 1500, 3, "1500 yılında dünya nüfusu tahminen kaçtı?", 1000),
    Question("population", "OWID_WRL", 1800, 2, "1800 yılında dünya nüfusu tahminen kaçtı?", 2023),
    Question("population", "OWID_WRL", 1900, 2, "1900 yılında dünya nüfusu tahminen kaçtı?", 2023),
    Question("population", "OWID_WRL", 1950, 2, "1950 yılında dünya nüfusu tahminen kaçtı?", 2000),
    Question(
        "population", "TUR", 1900, 3,
        "1900 yılında bugünkü Türkiye topraklarında tahminen kaç kişi yaşıyordu?", 1950,
    ),
    Question("population", "TUR", 1950, 2, "1950 yılında Türkiye'nin nüfusu tahminen kaçtı?", 2023),
    Question("population", "CHN", 1800, 3, "1800 yılında bugünkü Çin topraklarında tahminen kaç kişi yaşıyordu?", 2023),
    Question(
        "population", "IND", 1900, 3,
        "1900 yılında bugünkü Hindistan topraklarında tahminen kaç kişi yaşıyordu?", 2023,
    ),
    # Life expectancy at birth: Riley, Zijdeman et al., HMD and UN WPP joined by OWID.
    Question("life", "OWID_WRL", 1800, 3, "1800 yılında dünyada doğumda beklenen ortalama yaşam süresi kaç yıldı?", 2023),
    Question("life", "OWID_WRL", 1900, 3, "1900 yılında dünyada doğumda beklenen ortalama yaşam süresi kaç yıldı?", 2023),
    Question("life", "OWID_WRL", 1950, 2, "1950 yılında dünyada doğumda beklenen ortalama yaşam süresi kaç yıldı?", 2023),
    Question("life", "TUR", 1950, 2, "1950 yılında Türkiye'de doğumda beklenen ortalama yaşam süresi kaç yıldı?", 2023),
    Question("life", "JPN", 1900, 3, "1900 yılında Japonya'da doğumda beklenen ortalama yaşam süresi kaç yıldı?", 2023),
    Question("life", "SWE", 1800, 3, "1800 yılında İsveç'te doğumda beklenen ortalama yaşam süresi kaç yıldı?", 1900),
    Question(
        "life", "GBR", 1900, 3,
        "1900 yılında Birleşik Krallık'ta doğumda beklenen ortalama yaşam süresi kaç yıldı?", 1950,
    ),
    # Literacy (15+): historical estimates compiled by OWID.
    Question("literacy", "OWID_WRL", 1820, 3, "1820 yılında dünyada yetişkinlerin yüzde kaçı okuryazardı?", 1900),
    Question("literacy", "OWID_WRL", 1900, 3, "1900 yılında dünyada yetişkinlerin yüzde kaçı okuryazardı?", 1820),
    # Not Türkiye: OWID gives 8.2 % for 1927, Turkish sources usually 10.6 % (another age base).
    # Objects launched (satellites, probes, crewed spacecraft), UN register, by launching state.
    Question("space", "OWID_WRL", 1965, 3, "BM kayıtlarına göre 1965 yılında uzaya kaç nesne fırlatılmıştır?", 2000),
    Question("space", "OWID_WRL", 2000, 3, "BM kayıtlarına göre 2000 yılında uzaya kaç nesne fırlatılmıştır?", 1965),
    Question("space", "OWID_WRL", 2015, 3, "BM kayıtlarına göre 2015 yılında uzaya kaç nesne fırlatılmıştır?", 2000),
    Question("space", "OWID_WRL", 2024, 2, "BM kayıtlarına göre 2024 yılında uzaya kaç nesne fırlatılmıştır?", 2015),
    Question("space", "USA", 2024, 3, "BM kayıtlarına göre ABD 2024 yılında uzaya kaç nesne fırlatmıştır?", 2015),
    Question("space", "CHN", 2024, 3, "BM kayıtlarına göre Çin 2024 yılında uzaya kaç nesne fırlatmıştır?", 2015),
    Question("space", "RUS", 2024, 3, "BM kayıtlarına göre Rusya 2024 yılında uzaya kaç nesne fırlatmıştır?", 2015),
    Question("space", "TUR", 2023, 3, "BM kayıtlarına göre Türkiye 2023 yılında uzaya kaç nesne fırlatmıştır?", 2015),
]

FACT_NOTES = {
    ("space", "OWID_WRL", 2024): " Artışın çoğu Starlink gibi uydu takımlarından.",
    ("space", "USA", 2024): " Çoğu SpaceX'in Starlink uyduları.",
    ("space", "TUR", 2023): " Başka ülkelerin roketleriyle fırlatılan Türk uyduları da sayılır.",
    ("population", "TUR", 1950): " Yıl ortası tahmini, sayım sonucu değil.",
}


def get(url: str, attempts: int = 4) -> bytes:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    for attempt in range(1, attempts + 1):
        try:
            with urllib.request.urlopen(request, timeout=120) as response:
                return response.read()
        except (TimeoutError, OSError) as error:
            if attempt == attempts:
                raise
            print(f"    tekrar deneniyor ({error})")
            time.sleep(5 * attempt)


def fetch() -> dict:
    values: dict[str, dict] = {}
    citations: dict[str, str] = {}
    for name, metric in METRICS.items():
        meta = json.loads(get(f"{GRAPHER}{metric.slug}.metadata.json"))
        for column in meta["columns"].values():
            cite = column.get("citationShort", "")
            if OWN_DATA not in cite:
                raise SystemExit(f"{metric.slug}: OWID'in kendi verisi değil: {cite}")
        citations[metric.slug] = " | ".join(c["citationShort"] for c in meta["columns"].values())
        wanted = {(q.code, y) for q in QUESTIONS if q.metric == name for y in (q.year, q.compare)}
        names = {ENTITIES[code]: code for code, _ in wanted}
        text = get(f"{GRAPHER}{metric.slug}.csv?v=1&csvType=full&useColumnShortNames=true").decode("utf-8")
        found = {}
        for row in csv.DictReader(io.StringIO(text)):
            code = names.get(row["entity"])
            if code and (code, int(row["year"])) in wanted and row[metric.column]:
                found[f"{code}:{row['year']}"] = float(row[metric.column])
        values[name] = found
        print(f"  {metric.slug}: {len(found)}/{len(wanted)} değer")
    payload = {"source": GRAPHER, "fetched": date.today().isoformat(), "citations": citations, "values": values}
    EXTRACT.parent.mkdir(parents=True, exist_ok=True)
    EXTRACT.write_text(json.dumps(payload, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"Yazıldı: {EXTRACT.relative_to(ROOT)}")
    return payload


def rounded(value: float, metric: Metric) -> int | float:
    if metric.decimals is not None:
        return half_up(value, metric.decimals)
    digits = len(str(int(value)))
    step = 10 ** max(digits - 4, 0)
    return int(half_up(value / step, 0)) * step


def shown(value: float, metric: Metric) -> str:
    value = rounded(value, metric)
    if metric.unit == "kişi":
        if value >= 1e9:
            return f"{turkish_decimal(value / 1e9, 2)} milyar"
        return f"{turkish_decimal(value / 1e6, 1)} milyon"
    number = turkish_decimal(value, metric.decimals or 0, grouping=True)
    return f"%{number}" if metric.unit == "%" else f"{number} {metric.unit}"


def build(payload: dict, bank: list[dict]) -> tuple[list[dict], list[str]]:
    asked = {(q["source"], q["kind"], q["unit"]) for q in bank}
    texts = {q["text"].casefold() for q in bank}
    new, dropped = [], []
    for q in QUESTIONS:
        metric = METRICS[q.metric]
        values = payload["values"].get(q.metric, {})
        value, other = values.get(f"{q.code}:{q.year}"), values.get(f"{q.code}:{q.compare}")
        if value is None or value <= 0 or other is None:
            dropped.append(f"DEĞER YOK: {q.metric} {q.code} {q.year}/{q.compare}")
            continue
        source = f"{GRAPHER}{metric.slug}?time={q.year}&country=~{q.code}"
        key = (source, "magnitude", metric.unit)
        if key in asked or q.text.casefold() in texts:
            continue  # imported earlier
        asked.add(key)
        texts.add(q.text.casefold())
        fact = q.fact.format(year=q.compare, value=shown(other, metric))
        fact += FACT_NOTES.get((q.metric, q.code, q.year), "")
        new.append(
            {
                "text": q.text,
                "answer": rounded(value, metric),
                "unit": metric.unit,
                "kind": "magnitude",
                "category": "türkiye" if q.code == "TUR" else metric.category,
                "source": source,
                "data_year": int(payload["fetched"][:4]),  # when compiled, like the history questions
                "fun_fact": fact,
                "difficulty": q.difficulty,
                "dataset": metric.dataset,
            }
        )
    return new, dropped


def main(argv: list[str]) -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--fetch", action="store_true", help="OWID'den yeniden çek")
    parser.add_argument("--dry-run", action="store_true", help="bankaya yazma")
    args = parser.parse_args(argv)

    payload = fetch() if args.fetch or not EXTRACT.exists() else json.loads(EXTRACT.read_text(encoding="utf-8"))
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
