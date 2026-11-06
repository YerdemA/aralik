"""Country questions from the World Bank's World Development Indicators.

Usage:  python tools/import_worldbank.py [--fetch] [--dry-run]

For each indicator in INDICATORS and each country in QUESTIONS, the most
recent non-empty value (API `mrnev=1`) is asked, with its year in the text:
"2025 verilerine göre Türkiye'nin kişi başına düşen gayrisafi yurt içi
hasılası kaç ABD dolarıdır?". Values are only rounded. The fun fact is the
world average of the same indicator and year (aggregate WLD).

Not asked: tourist arrivals (the latest values are from 2020, the pandemic
year) and internet users (most countries are bunched at 85-100 %). Values
older than MIN_YEAR are dropped.

--fetch calls the API (no key) and writes tools/raw/worldbank/wdi.json
(committed); without it that file is read. WDI data is CC BY 4.0
("The World Bank, World Development Indicators"). The source of a question is
the indicator's page for that country.
"""

from __future__ import annotations

import argparse
import json
import random
import sys
import urllib.request
from collections import Counter
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BANK = ROOT / "assets" / "questions" / "questions.json"
EXTRACT = ROOT / "tools" / "raw" / "worldbank" / "wdi.json"
API_URL = "https://api.worldbank.org/v2/country/{countries}/indicator/{indicator}?format=json&mrnev=1&per_page=300"
PAGE_URL = "https://data.worldbank.org/indicator/{indicator}?locations={iso2}"
MIN_YEAR = 2022
SEED = 20261110
USER_AGENT = "KabacaContentCheck/1.0 (https://github.com/YerdemA/aralik)"

# indicator → (question with {year}, {gen} = genitive, {loc} = locative; unit; decimals; data set)
INDICATORS = {
    "NY.GDP.PCAP.CD": (
        "{year} verilerine göre {gen} kişi başına düşen gayrisafi yurt içi hasılası kaç ABD dolarıdır?",
        "dolar", 0, "wdi_gdp_per_capita",
    ),
    "SP.DYN.LE00.IN": (
        "{year} verilerine göre {loc} doğumda beklenen ortalama yaşam süresi kaç yıldır?",
        "yıl", 1, "wdi_life_expectancy",
    ),
    "SP.DYN.TFRT.IN": (
        "{year} verilerine göre {loc} bir kadın ortalama kaç çocuk doğurur?",
        "çocuk", 2, "wdi_fertility",
    ),
    "AG.LND.FRST.ZS": (
        "{year} verilerine göre {gen} kara yüzölçümünün yüzde kaçı ormanla kaplıdır?",
        "%", 1, "wdi_forest",
    ),
    "SP.POP.65UP.TO.ZS": (
        "{year} verilerine göre {gen} nüfusunun yüzde kaçı 65 yaş ve üzerindedir?",
        "%", 1, "wdi_age_65",
    ),
}

# ISO3 → (genitive, locative)
COUNTRIES = {
    "TUR": ("Türkiye'nin", "Türkiye'de"), "JPN": ("Japonya'nın", "Japonya'da"), "USA": ("ABD'nin", "ABD'de"),
    "DEU": ("Almanya'nın", "Almanya'da"), "CHN": ("Çin'in", "Çin'de"), "IND": ("Hindistan'ın", "Hindistan'da"),
    "NOR": ("Norveç'in", "Norveç'te"), "CHE": ("İsviçre'nin", "İsviçre'de"), "LUX": ("Lüksemburg'un", "Lüksemburg'da"),
    "QAT": ("Katar'ın", "Katar'da"), "BRA": ("Brezilya'nın", "Brezilya'da"), "RUS": ("Rusya'nın", "Rusya'da"),
    "NGA": ("Nijerya'nın", "Nijerya'da"), "GRC": ("Yunanistan'ın", "Yunanistan'da"), "AZE": ("Azerbaycan'ın", "Azerbaycan'da"),
    "KOR": ("Güney Kore'nin", "Güney Kore'de"), "EGY": ("Mısır'ın", "Mısır'da"), "ETH": ("Etiyopya'nın", "Etiyopya'da"),
    "ISR": ("İsrail'in", "İsrail'de"), "FRA": ("Fransa'nın", "Fransa'da"), "GBR": ("Birleşik Krallık'ın", "Birleşik Krallık'ta"),
    "ITA": ("İtalya'nın", "İtalya'da"), "SAU": ("Suudi Arabistan'ın", "Suudi Arabistan'da"), "CAN": ("Kanada'nın", "Kanada'da"),
    "FIN": ("Finlandiya'nın", "Finlandiya'da"), "NER": ("Nijer'in", "Nijer'de"),
    "CAF": ("Orta Afrika Cumhuriyeti'nin", "Orta Afrika Cumhuriyeti'nde"),
}

# (indicator, country, difficulty)
QUESTIONS = [
    *(("NY.GDP.PCAP.CD", c, d) for c, d in [
        ("TUR", 2), ("USA", 2), ("DEU", 3), ("JPN", 3), ("CHN", 3), ("IND", 3), ("NOR", 3), ("CHE", 3),
        ("LUX", 3), ("QAT", 3), ("RUS", 3), ("NGA", 3), ("GRC", 3), ("AZE", 3), ("KOR", 3), ("EGY", 3),
    ]),
    *(("SP.DYN.LE00.IN", c, d) for c, d in [
        ("TUR", 2), ("JPN", 2), ("USA", 3), ("NGA", 3), ("CHE", 3), ("IND", 3), ("CHN", 3), ("RUS", 3),
        ("KOR", 3), ("CAF", 3), ("AZE", 3), ("ITA", 3),
    ]),
    *(("SP.DYN.TFRT.IN", c, d) for c, d in [
        ("TUR", 2), ("KOR", 3), ("NER", 3), ("JPN", 3), ("CHN", 3), ("ISR", 3), ("FRA", 3), ("IND", 3),
        ("NGA", 3), ("USA", 3),
    ]),
    *(("AG.LND.FRST.ZS", c, d) for c, d in [
        ("TUR", 2), ("FIN", 3), ("JPN", 3), ("KOR", 3), ("BRA", 3), ("RUS", 3), ("DEU", 3), ("GBR", 3),
        ("SAU", 3), ("ISR", 3), ("CAN", 3), ("CHN", 3),
    ]),
    *(("SP.POP.65UP.TO.ZS", c, d) for c, d in [
        ("TUR", 2), ("JPN", 3), ("ITA", 3), ("NGA", 3), ("DEU", 3), ("CHN", 3), ("KOR", 3), ("IND", 3), ("QAT", 3),
    ]),
]


def get_json(url: str):
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=60) as response:
        return json.loads(response.read().decode("utf-8"))


def fetch() -> dict:
    values: dict[str, dict] = {}
    for indicator in INDICATORS:
        countries = sorted({c for i, c, _ in QUESTIONS if i == indicator})
        rows = get_json(API_URL.format(countries=";".join(countries), indicator=indicator))[1] or []
        values[indicator] = {
            r["countryiso3code"]: {"iso2": r["country"]["id"], "year": int(r["date"]), "value": r["value"]}
            for r in rows
            if r["value"] is not None
        }
        # World averages of the years asked, for the fun facts.
        for year in sorted({v["year"] for v in values[indicator].values()}):
            world = get_json(
                f"https://api.worldbank.org/v2/country/WLD/indicator/{indicator}?format=json&date={year}"
            )[1] or []
            if world and world[0]["value"] is not None:
                values[indicator][f"WLD:{year}"] = {"iso2": "1W", "year": year, "value": world[0]["value"]}
        print(f"  {indicator}: {len(values[indicator])} değer")
    payload = {"source": "https://api.worldbank.org/v2/", "fetched": date.today().isoformat(), "values": values}
    EXTRACT.parent.mkdir(parents=True, exist_ok=True)
    EXTRACT.write_text(json.dumps(payload, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"Yazıldı: {EXTRACT.relative_to(ROOT)}")
    return payload


def rounded(value: float, decimals: int) -> int | float:
    return int(round(value)) if decimals == 0 else round(value, decimals)


def turkish_number(value: float, decimals: int) -> str:
    text = f"{value:,.{decimals}f}"
    whole, _, fraction = text.partition(".")
    whole = whole.replace(",", ".")
    return f"{whole},{fraction}" if fraction else whole


def build(payload: dict, bank: list[dict]) -> tuple[list[dict], list[str]]:
    asked = {(q["source"], q["kind"], q["unit"]) for q in bank}
    texts = {q["text"].casefold() for q in bank}
    new, dropped = [], []
    for indicator, country, difficulty in QUESTIONS:
        template, unit, decimals, dataset = INDICATORS[indicator]
        label = f"{indicator} {country}"
        found = payload["values"][indicator].get(country)
        if found is None or found["value"] <= 0:
            dropped.append(f"DEĞER YOK: {label}")
            continue
        if found["year"] < MIN_YEAR:
            dropped.append(f"ESKİ VERİ ({found['year']}): {label}")
            continue
        gen, loc = COUNTRIES[country]
        text = template.format(year=found["year"], gen=gen, loc=loc)
        source = PAGE_URL.format(indicator=indicator, iso2=found["iso2"])
        key = (source, "magnitude", unit)
        if key in asked or text.casefold() in texts:
            continue  # imported earlier
        asked.add(key)
        texts.add(text.casefold())
        world = payload["values"][indicator].get(f"WLD:{found['year']}")
        suffix = "" if unit in ("%", "dolar") else f" {unit}"
        prefix = "%" if unit == "%" else ""
        fact = None
        if world is not None:
            shown = turkish_number(world["value"], decimals)
            fact = f"Aynı yıl dünya ortalaması: {prefix}{shown}{' dolar' if unit == 'dolar' else suffix}."
        new.append(
            {
                "text": text,
                "answer": rounded(found["value"], decimals),
                "unit": unit,
                "kind": "magnitude",
                "category": "türkiye" if country == "TUR" else "coğrafya",
                "source": source,
                "data_year": found["year"],
                "fun_fact": fact,
                "difficulty": difficulty,
                "dataset": dataset,
            }
        )
    return new, dropped


def main(argv: list[str]) -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--fetch", action="store_true", help="Dünya Bankası API'sinden yeniden çek")
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
