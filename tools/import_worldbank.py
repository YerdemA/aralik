"""Country questions from the World Bank's World Development Indicators.

Usage:  python tools/import_worldbank.py [--fetch] [--dry-run]

For each indicator in INDICATORS and each country in QUESTIONS, the most
recent non-empty value (API `mrnev=1`) is asked, with its year in the text:
"2025 verilerine göre Türkiye'nin kişi başına düşen gayrisafi yurt içi
hasılası kaç ABD dolarıdır?". Values are only rounded. The fun fact is the
world average of the same indicator and year (aggregate WLD).

Tourist arrivals (ST.INT.ARVL) are no longer updated: the latest values are
from 2020, the pandemic year, so the year is in the text ("2020 yılında
Türkiye'ye kaç uluslararası turist geldi?") and the fun fact gives the 2019
value of the same series. Some countries count same-day visitors too (France
218 million in 2019, the USA 165 million); the series has no footnote to tell
them apart, so only countries whose figure matches their overnight tourists
are asked (TOURISM_COUNTRIES, checked by hand on 2026-11-06).

Values older than the indicator's minimum year are dropped.

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
import time
import urllib.request
from collections import Counter
from dataclasses import dataclass
from datetime import date
from pathlib import Path

from rounding import half_up, turkish_decimal

ROOT = Path(__file__).resolve().parent.parent
BANK = ROOT / "assets" / "questions" / "questions.json"
EXTRACT = ROOT / "tools" / "raw" / "worldbank" / "wdi.json"
API_URL = "https://api.worldbank.org/v2/country/{countries}/indicator/{indicator}?format=json&{when}&per_page=300"
PAGE_URL = "https://data.worldbank.org/indicator/{indicator}?locations={iso2}"
SEED = 20261110
USER_AGENT = "KabacaContentCheck/1.0 (https://github.com/YerdemA/aralik)"
TOURISM = "ST.INT.ARVL"
PANDEMIC_YEARS = (2020, 2021)


@dataclass(frozen=True)
class Indicator:
    # {year}; {gen}, {loc}, {dat}: the country in genitive, locative, dative.
    text: str
    unit: str
    decimals: int
    dataset: str
    min_year: int = 2022


INDICATORS = {
    "NY.GDP.PCAP.CD": Indicator(
        "{year} verilerine göre {gen} kişi başına düşen gayrisafi yurt içi hasılası kaç ABD dolarıdır?",
        "dolar", 0, "wdi_gdp_per_capita",
    ),
    "SP.DYN.LE00.IN": Indicator(
        "{year} verilerine göre {loc} doğumda beklenen ortalama yaşam süresi kaç yıldır?",
        "yıl", 1, "wdi_life_expectancy",
    ),
    "SP.DYN.TFRT.IN": Indicator(
        "{year} verilerine göre {loc} bir kadın ortalama kaç çocuk doğurur?",
        "çocuk", 2, "wdi_fertility",
    ),
    "AG.LND.FRST.ZS": Indicator(
        "{year} verilerine göre {gen} kara yüzölçümünün yüzde kaçı ormanla kaplıdır?",
        "%", 1, "wdi_forest",
    ),
    "SP.POP.65UP.TO.ZS": Indicator(
        "{year} verilerine göre {gen} nüfusunun yüzde kaçı 65 yaş ve üzerindedir?",
        "%", 1, "wdi_age_65",
    ),
    "IT.NET.USER.ZS": Indicator(
        "{year} verilerine göre {gen} nüfusunun yüzde kaçı internet kullanmaktadır?",
        "%", 1, "wdi_internet",
    ),
    TOURISM: Indicator(
        "{year} yılında {dat} kaç uluslararası turist geldi?",
        "kişi", 0, "wdi_tourism", min_year=2019,
    ),
}

# ISO3 → (genitive, locative, dative)
COUNTRIES = {
    "TUR": ("Türkiye'nin", "Türkiye'de", "Türkiye'ye"),
    "JPN": ("Japonya'nın", "Japonya'da", "Japonya'ya"),
    "USA": ("ABD'nin", "ABD'de", "ABD'ye"),
    "DEU": ("Almanya'nın", "Almanya'da", "Almanya'ya"),
    "CHN": ("Çin'in", "Çin'de", "Çin'e"),
    "IND": ("Hindistan'ın", "Hindistan'da", "Hindistan'a"),
    "NOR": ("Norveç'in", "Norveç'te", "Norveç'e"),
    "CHE": ("İsviçre'nin", "İsviçre'de", "İsviçre'ye"),
    "LUX": ("Lüksemburg'un", "Lüksemburg'da", "Lüksemburg'a"),
    "QAT": ("Katar'ın", "Katar'da", "Katar'a"),
    "BRA": ("Brezilya'nın", "Brezilya'da", "Brezilya'ya"),
    "RUS": ("Rusya'nın", "Rusya'da", "Rusya'ya"),
    "NGA": ("Nijerya'nın", "Nijerya'da", "Nijerya'ya"),
    "GRC": ("Yunanistan'ın", "Yunanistan'da", "Yunanistan'a"),
    "AZE": ("Azerbaycan'ın", "Azerbaycan'da", "Azerbaycan'a"),
    "KOR": ("Güney Kore'nin", "Güney Kore'de", "Güney Kore'ye"),
    "EGY": ("Mısır'ın", "Mısır'da", "Mısır'a"),
    "ETH": ("Etiyopya'nın", "Etiyopya'da", "Etiyopya'ya"),
    "ISR": ("İsrail'in", "İsrail'de", "İsrail'e"),
    "FRA": ("Fransa'nın", "Fransa'da", "Fransa'ya"),
    "GBR": ("Birleşik Krallık'ın", "Birleşik Krallık'ta", "Birleşik Krallık'a"),
    "ITA": ("İtalya'nın", "İtalya'da", "İtalya'ya"),
    "SAU": ("Suudi Arabistan'ın", "Suudi Arabistan'da", "Suudi Arabistan'a"),
    "CAN": ("Kanada'nın", "Kanada'da", "Kanada'ya"),
    "FIN": ("Finlandiya'nın", "Finlandiya'da", "Finlandiya'ya"),
    "NER": ("Nijer'in", "Nijer'de", "Nijer'e"),
    "CAF": ("Orta Afrika Cumhuriyeti'nin", "Orta Afrika Cumhuriyeti'nde", "Orta Afrika Cumhuriyeti'ne"),
    "AUT": ("Avusturya'nın", "Avusturya'da", "Avusturya'ya"),
    "ARE": ("Birleşik Arap Emirlikleri'nin", "Birleşik Arap Emirlikleri'nde", "Birleşik Arap Emirlikleri'ne"),
    "THA": ("Tayland'ın", "Tayland'da", "Tayland'a"),
    "PAK": ("Pakistan'ın", "Pakistan'da", "Pakistan'a"),
    "IDN": ("Endonezya'nın", "Endonezya'da", "Endonezya'ya"),
}

# Overnight tourists, not same-day visitors (see the module docstring).
TOURISM_COUNTRIES = [
    ("TUR", 2), ("DEU", 3), ("GBR", 3), ("AUT", 3), ("JPN", 3), ("RUS", 3),
    ("GRC", 3), ("AZE", 3), ("ARE", 3), ("EGY", 3), ("THA", 3),
]
# Appended to the fun fact (starts with a space).
TOURISM_NOTES = {"TUR": " Yurt dışında yaşayan vatandaşlar da sayılır."}

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
    # Spread out, not the many countries bunched at 85-100 %.
    *(("IT.NET.USER.ZS", c, d) for c, d in [
        ("TUR", 2), ("IND", 3), ("NGA", 3), ("ETH", 3), ("PAK", 3), ("IDN", 3), ("EGY", 3),
        ("NER", 3), ("JPN", 3), ("BRA", 3),
    ]),
    *((TOURISM, c, d) for c, d in TOURISM_COUNTRIES),
]


def get_json(url: str, attempts: int = 4):
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    for attempt in range(1, attempts + 1):
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                return json.loads(response.read().decode("utf-8"))
        except (TimeoutError, OSError) as error:  # the API times out now and then
            if attempt == attempts:
                raise
            print(f"    tekrar deneniyor ({error})")
            time.sleep(5 * attempt)


def rows(countries: list[str], indicator: str, when: str) -> list[dict]:
    url = API_URL.format(countries=";".join(countries), indicator=indicator, when=when)
    return [r for r in get_json(url)[1] or [] if r["value"] is not None]


def fetch() -> dict:
    values: dict[str, dict] = {}
    for indicator in INDICATORS:
        countries = sorted({c for i, c, _ in QUESTIONS if i == indicator})
        found = {
            r["countryiso3code"]: {"iso2": r["country"]["id"], "year": int(r["date"]), "value": r["value"]}
            for r in rows(countries, indicator, "mrnev=1")
        }
        # World averages of the years asked, for the fun facts.
        for year in sorted({v["year"] for v in found.values()}):
            for r in rows(["WLD"], indicator, f"date={year}"):
                found[f"WLD:{year}"] = {"iso2": "1W", "year": year, "value": r["value"]}
        if indicator == TOURISM:  # the last year before the pandemic
            for r in rows(countries, indicator, "date=2019"):
                found[f"{r['countryiso3code']}:2019"] = {"iso2": r["country"]["id"], "year": 2019, "value": r["value"]}
        values[indicator] = found
        print(f"  {indicator}: {len(found)} değer")
    payload = {"source": "https://api.worldbank.org/v2/", "fetched": date.today().isoformat(), "values": values}
    EXTRACT.parent.mkdir(parents=True, exist_ok=True)
    EXTRACT.write_text(json.dumps(payload, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"Yazıldı: {EXTRACT.relative_to(ROOT)}")
    return payload


def rounded(value: float, decimals: int) -> int | float:
    return half_up(value, decimals)


def turkish_number(value: float, decimals: int) -> str:
    return turkish_decimal(value, decimals, grouping=True)


def millions(value: float) -> str:
    return f"{turkish_number(value / 1e6, 1)} milyon"


def shown(value: float, ind: Indicator) -> str:
    number = turkish_number(value, ind.decimals)
    if ind.unit == "%":
        return f"%{number}"
    if ind.unit == "dolar":
        return f"{number} dolar"
    return f"{number} {ind.unit}"


def fun_fact(indicator: str, country: str, found: dict, values: dict) -> str | None:
    ind = INDICATORS[indicator]
    if indicator == TOURISM:
        # No world total: WLD adds up countries that count same-day visitors.
        note = TOURISM_NOTES.get(country, "")
        before = values.get(f"{country}:2019")
        if found["year"] in PANDEMIC_YEARS and before is not None:
            return f"COVID-19 salgını yüzünden çok düşük: 2019'da {millions(before['value'])} turist gelmişti.{note}"
        return f"Salgından önceki son yılın verisi.{note}"
    world = values.get(f"WLD:{found['year']}")
    return None if world is None else f"Aynı yıl dünya ortalaması: {shown(world['value'], ind)}."


def build(payload: dict, bank: list[dict]) -> tuple[list[dict], list[str]]:
    asked = {(q["source"], q["kind"], q["unit"]) for q in bank}
    texts = {q["text"].casefold() for q in bank}
    new, dropped = [], []
    for indicator, country, difficulty in QUESTIONS:
        ind = INDICATORS[indicator]
        values = payload["values"].get(indicator, {})
        label = f"{indicator} {country}"
        found = values.get(country)
        if found is None or found["value"] <= 0:
            dropped.append(f"DEĞER YOK: {label}")
            continue
        if found["year"] < ind.min_year:
            dropped.append(f"ESKİ VERİ ({found['year']}): {label}")
            continue
        gen, loc, dat = COUNTRIES[country]
        text = ind.text.format(year=found["year"], gen=gen, loc=loc, dat=dat)
        source = PAGE_URL.format(indicator=indicator, iso2=found["iso2"])
        key = (source, "magnitude", ind.unit)
        if key in asked or text.casefold() in texts:
            continue  # imported earlier
        asked.add(key)
        texts.add(text.casefold())
        new.append(
            {
                "text": text,
                "answer": rounded(found["value"], ind.decimals),
                "unit": ind.unit,
                "kind": "magnitude",
                "category": "türkiye" if country == "TUR" else "coğrafya",
                "source": source,
                "data_year": found["year"],
                "fun_fact": fun_fact(indicator, country, found, values),
                "difficulty": difficulty,
                "dataset": ind.dataset,
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
