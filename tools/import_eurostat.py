"""Country questions from Eurostat (EU, EFTA and candidate countries only).

Usage:  python tools/import_eurostat.py [--fetch] [--dry-run] [--show]

For each indicator in INDICATORS and each country in QUESTIONS, the most
recent value is asked, with its year in the text: "2023 verilerine göre
Türkiye'de kadınlar ilk kez ortalama kaç yaşında evlenmektedir?". Values are
only rounded. The fun fact is the EU average of the same year when Eurostat
has one, otherwise Türkiye's value.

Eurostat data may be reused with attribution, except data of non-European
countries that Eurostat republishes (USA, Japan, China ...). So only EU, EFTA
and candidate country rows are fetched (COUNTRIES); the EU aggregate is used
only in the fun facts.

--fetch calls the dissemination API (JSON-stat, no key) and writes
tools/raw/eurostat/eurostat.json (committed); without it that file is read.
--show prints every fetched value, to pick QUESTIONS. The source of a
question is the API query that returns exactly that one value.
"""

from __future__ import annotations

import argparse
import json
import random
import sys
import time
import urllib.parse
import urllib.request
from collections import Counter
from dataclasses import dataclass
from datetime import date
from pathlib import Path

from rounding import half_up, turkish_decimal

ROOT = Path(__file__).resolve().parent.parent
BANK = ROOT / "assets" / "questions" / "questions.json"
EXTRACT = ROOT / "tools" / "raw" / "eurostat" / "eurostat.json"
API = "https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/"
SEED = 20261111
USER_AGENT = "KabacaContentCheck/1.0 (https://github.com/YerdemA/aralik)"
EU = "EU27_2020"
SINCE = 2018


@dataclass(frozen=True)
class Indicator:
    code: str  # Eurostat dataset code
    filters: tuple[tuple[str, str], ...]  # every dimension except geo and time
    # {year}; {name}, {loc}: the country, and in locative.
    text: str
    unit: str
    decimals: int
    dataset: str
    note: str = ""  # appended to the fun fact (starts with a space)
    min_year: int = 2021


INDICATORS = {
    "first_marriage_f": Indicator(
        "demo_nind", (("freq", "A"), ("indic_de", "FAGEMAR1")),
        "{year} verilerine göre {loc} kadınlar ilk kez ortalama kaç yaşında evlenmektedir?",
        "yaş", 1, "es_first_marriage",
    ),
    "first_marriage_m": Indicator(
        "demo_nind", (("freq", "A"), ("indic_de", "MAGEMAR1")),
        "{year} verilerine göre {loc} erkekler ilk kez ortalama kaç yaşında evlenmektedir?",
        "yaş", 1, "es_first_marriage",
    ),
    "first_child": Indicator(
        "demo_find", (("freq", "A"), ("indic_de", "AGEMOTH1")),
        "{year} verilerine göre {loc} kadınlar ilk çocuklarını ortalama kaç yaşında doğurmaktadır?",
        "yaş", 1, "es_first_child",
    ),
    "outside_marriage": Indicator(
        "demo_find", (("freq", "A"), ("indic_de", "NMARPCT")),
        "{year} yılında {loc} doğan bebeklerin yüzde kaçı evlilik dışı doğmuştur?",
        "%", 1, "es_births_outside_marriage",
    ),
    "median_age": Indicator(
        "demo_pjanind", (("freq", "A"), ("indic_de", "MEDAGEPOP")),
        "{year} verilerine göre {name} nüfusunun ortanca yaşı kaçtır?",
        "yaş", 1, "es_median_age",
        note=" Nüfusun yarısı bu yaştan genç, yarısı yaşlıdır (1 Ocak itibarıyla).",
    ),
    "cars": Indicator(
        "road_eqs_carhab", (("freq", "A"), ("unit", "NR")),
        "{year} verilerine göre {loc} her 1.000 kişiye kaç otomobil düşmektedir?",
        "otomobil", 0, "es_cars",
    ),
    "waste": Indicator(
        "env_wasmun", (("freq", "A"), ("wst_oper", "GEN"), ("unit", "KG_HAB")),
        "{year} yılında {loc} kişi başına kaç kilogram belediye atığı (evsel çöp) oluşmuştur?",
        "kg", 0, "es_municipal_waste",
    ),
    "leaving_home": Indicator(
        "yth_demo_030", (("freq", "A"), ("unit", "AVG"), ("sex", "T")),
        "{year} verilerine göre {loc} gençler baba evinden ortalama kaç yaşında ayrılmaktadır?",
        "yaş", 1, "es_leaving_home",
    ),
    "household_size": Indicator(
        "ilc_lvph01", (("freq", "A"), ("unit", "AVG")),
        "{year} verilerine göre {loc} bir hanede ortalama kaç kişi yaşamaktadır?",
        "kişi", 1, "es_household_size",
    ),
    "home_owners": Indicator(
        "ilc_lvho02",
        (("freq", "A"), ("rskpovth", "TOTAL"), ("hhcomp", "TOTAL"), ("tenure", "OWN"), ("unit", "PC")),
        "{year} verilerine göre {name} nüfusunun yüzde kaçı kendi evinde oturmaktadır?",
        "%", 1, "es_home_owners",
    ),
}

# Eurostat geo code → (name, locative). EU, EFTA and candidate countries only.
COUNTRIES = {
    "TR": ("Türkiye", "Türkiye'de"),
    "DE": ("Almanya", "Almanya'da"),
    "FR": ("Fransa", "Fransa'da"),
    "IT": ("İtalya", "İtalya'da"),
    "ES": ("İspanya", "İspanya'da"),
    "EL": ("Yunanistan", "Yunanistan'da"),
    "NL": ("Hollanda", "Hollanda'da"),
    "PL": ("Polonya", "Polonya'da"),
    "SE": ("İsveç", "İsveç'te"),
    "PT": ("Portekiz", "Portekiz'de"),
    "IE": ("İrlanda", "İrlanda'da"),
    "HR": ("Hırvatistan", "Hırvatistan'da"),
    "BG": ("Bulgaristan", "Bulgaristan'da"),
    "RO": ("Romanya", "Romanya'da"),
    "HU": ("Macaristan", "Macaristan'da"),
    "DK": ("Danimarka", "Danimarka'da"),
    "FI": ("Finlandiya", "Finlandiya'da"),
    "AT": ("Avusturya", "Avusturya'da"),
    "BE": ("Belçika", "Belçika'da"),
    "CZ": ("Çekya", "Çekya'da"),
    "NO": ("Norveç", "Norveç'te"),
    "CH": ("İsviçre", "İsviçre'de"),
    "IS": ("İzlanda", "İzlanda'da"),
    "LU": ("Lüksemburg", "Lüksemburg'da"),
    "MT": ("Malta", "Malta'da"),
    "CY": ("Kıbrıs Cumhuriyeti", "Kıbrıs Cumhuriyeti'nde"),
    "AL": ("Arnavutluk", "Arnavutluk'ta"),
    "RS": ("Sırbistan", "Sırbistan'da"),
}

# (indicator, country, difficulty). Values flagged provisional (p) or with a
# different definition (d) are avoided where another country will do.
QUESTIONS: list[tuple[str, str, int]] = [
    *(("first_marriage_f", c, d) for c, d in [
        ("TR", 2), ("IT", 3), ("ES", 3), ("SE", 3), ("EL", 3), ("HU", 3), ("NL", 3),
    ]),
    *(("first_marriage_m", c, d) for c, d in [("TR", 2), ("IT", 3), ("EL", 3), ("PT", 3)]),
    *(("first_child", c, d) for c, d in [
        ("TR", 2), ("IT", 3), ("DE", 3), ("ES", 3), ("BG", 3), ("IE", 3), ("NL", 3),
    ]),
    *(("outside_marriage", c, d) for c, d in [
        ("TR", 2), ("EL", 3), ("FR", 3), ("DE", 3), ("IT", 3), ("BG", 3), ("SE", 3), ("NO", 3),
        ("HU", 3), ("ES", 3),
    ]),
    *(("median_age", c, d) for c, d in [
        ("TR", 2), ("IT", 3), ("DE", 3), ("IE", 3), ("EL", 3), ("IS", 3), ("NO", 3),
    ]),
    *(("cars", c, d) for c, d in [
        ("TR", 2), ("DE", 3), ("PL", 3), ("LU", 3), ("FI", 3), ("SE", 3), ("AL", 3), ("NL", 3),
    ]),
    *(("waste", c, d) for c, d in [
        ("TR", 2), ("AT", 3), ("DK", 3), ("DE", 3), ("RO", 3), ("PL", 3), ("IT", 3), ("NO", 3), ("CH", 3),
    ]),
    *(("leaving_home", c, d) for c, d in [
        ("TR", 2), ("FI", 3), ("DK", 3), ("IT", 3), ("HR", 3), ("DE", 3), ("FR", 3), ("ES", 3), ("SE", 3),
    ]),
    *(("household_size", c, d) for c, d in [("TR", 2), ("DE", 3), ("PL", 3)]),
    *(("home_owners", c, d) for c, d in [
        ("TR", 2), ("CH", 3), ("DE", 3), ("RO", 3), ("IT", 3), ("HU", 3), ("NO", 3), ("AT", 3),
    ]),
]


def get_json(url: str, attempts: int = 4):
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    for attempt in range(1, attempts + 1):
        try:
            with urllib.request.urlopen(request, timeout=90) as response:
                return json.loads(response.read().decode("utf-8"))
        except (TimeoutError, OSError) as error:
            if attempt == attempts:
                raise
            print(f"    tekrar deneniyor ({error})")
            time.sleep(5 * attempt)


def query(ind: Indicator, geos: list[str], year: int | None = None) -> str:
    params = [*ind.filters, *(("geo", g) for g in geos)]
    params += [("time", str(year))] if year is not None else [("sinceTimePeriod", str(SINCE))]
    params.append(("lang", "EN"))
    return f"{API}{ind.code}?{urllib.parse.urlencode(params)}"


def parse(stat: dict) -> dict[str, dict[str, dict]]:
    """JSON-stat 2.0 with one value per (geo, time) → {geo: {year: {value, flag}}}."""
    ids, sizes = stat["id"], stat["size"]
    for dim, size in zip(ids, sizes):
        if dim not in ("geo", "time") and size != 1:
            raise ValueError(f"{dim}: {size} değer, filtre eksik")
    index = {d: {pos: code for code, pos in stat["dimension"][d]["category"]["index"].items()} for d in ids}
    flags = stat.get("status", {})
    out: dict[str, dict[str, dict]] = {}
    for flat, value in stat["value"].items():
        rest, coords = int(flat), {}
        for dim, size in reversed(list(zip(ids, sizes))):
            coords[dim] = index[dim][rest % size]
            rest //= size
        out.setdefault(coords["geo"], {})[coords["time"]] = {"value": value, "flag": flags.get(flat, "")}
    return out


def fetch() -> dict:
    values = {}
    for name, ind in INDICATORS.items():
        values[name] = parse(get_json(query(ind, [*COUNTRIES, EU])))
        print(f"  {name}: {len(values[name])} ülke")
    payload = {"source": API, "fetched": date.today().isoformat(), "values": values}
    EXTRACT.parent.mkdir(parents=True, exist_ok=True)
    EXTRACT.write_text(json.dumps(payload, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"Yazıldı: {EXTRACT.relative_to(ROOT)}")
    return payload


def latest(series: dict[str, dict] | None, min_year: int) -> tuple[int, dict] | None:
    if not series:
        return None
    year = max(series, key=int)
    return (int(year), series[year]) if int(year) >= min_year else None


def shown(value: float, ind: Indicator) -> str:
    number = turkish_decimal(value, ind.decimals, grouping=True)
    return f"%{number}" if ind.unit == "%" else f"{number} {ind.unit}"


def fun_fact(ind: Indicator, country: str, year: int, values: dict) -> str | None:
    """The EU average of the year; without one (marriage ages), Türkiye's value."""
    eu = values.get(EU, {}).get(str(year))
    turkey = values.get("TR", {}).get(str(year))
    if eu:
        text = f"Aynı yıl AB ortalaması: {shown(eu['value'], ind)}."
    elif turkey and country != "TR":
        text = f"Aynı yıl Türkiye'de: {shown(turkey['value'], ind)}."
    else:
        text = ""
    return (text + ind.note).strip() or None


def show(payload: dict) -> None:
    for name, ind in INDICATORS.items():
        values = payload["values"].get(name, {})
        print(f"\n{name} ({ind.code}, {ind.unit})")
        found = [(g, latest(values.get(g), ind.min_year)) for g in [*COUNTRIES, EU]]
        found = sorted(((g, f) for g, f in found if f), key=lambda gf: gf[1][1]["value"])
        for geo, (year, v) in found:
            print(f"  {geo:10} {year} {v['value']:>10} {v['flag']}")


def build(payload: dict, bank: list[dict]) -> tuple[list[dict], list[str]]:
    asked = {(q["source"], q["kind"], q["unit"]) for q in bank}
    texts = {q["text"].casefold() for q in bank}
    new, dropped = [], []
    for name, country, difficulty in QUESTIONS:
        ind = INDICATORS[name]
        values = payload["values"].get(name, {})
        label = f"{name} {country}"
        found = latest(values.get(country), ind.min_year)
        if found is None or found[1]["value"] <= 0:
            dropped.append(f"DEĞER YOK / ESKİ: {label}")
            continue
        year, v = found
        name, loc = COUNTRIES[country]
        text = ind.text.format(year=year, name=name, loc=loc)
        source = query(ind, [country], year)
        key = (source, "magnitude", ind.unit)
        if key in asked or text.casefold() in texts:
            continue  # imported earlier
        asked.add(key)
        texts.add(text.casefold())
        new.append(
            {
                "text": text,
                "answer": half_up(v["value"], ind.decimals),
                "unit": ind.unit,
                "kind": "magnitude",
                "category": "türkiye" if country == "TR" else "coğrafya",
                "source": source,
                "data_year": year,
                "fun_fact": fun_fact(ind, country, year, values),
                "difficulty": difficulty,
                "dataset": ind.dataset,
            }
        )
    return new, dropped


def main(argv: list[str]) -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--fetch", action="store_true", help="Eurostat API'sinden yeniden çek")
    parser.add_argument("--dry-run", action="store_true", help="bankaya yazma")
    parser.add_argument("--show", action="store_true", help="çekilen tüm değerleri listele")
    args = parser.parse_args(argv)

    payload = fetch() if args.fetch or not EXTRACT.exists() else json.loads(EXTRACT.read_text(encoding="utf-8"))
    if args.show:
        show(payload)
        return 0
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
