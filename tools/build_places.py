"""Build assets/data/places.json from tools/raw/wikidata/places_*.json.

Usage:  python tools/build_places.py

The app computes distance questions from these coordinates on device, so
every number still comes from a sourced value (Wikidata P625).
A place is dropped when its coordinate statements disagree by more than
MAX_SPREAD_KM, or when a country has more than one capital.
"""

from __future__ import annotations

import json
import math
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RAW_DIR = ROOT / "tools" / "raw" / "wikidata"
OUT_PATH = ROOT / "assets" / "data" / "places.json"

MAX_SPREAD_KM = 5
# Capitals by Turkish Wikipedia reads: Paris yes, Paramaribo no.
WORLD_LIMIT = 40
# The best-read province capitals also pair with world capitals
# ("İstanbul ile Londra arası").
MAJOR_TR_CITIES = 15


def km(a: tuple[float, float], b: tuple[float, float]) -> float:
    lat1, lon1, lat2, lon2 = map(math.radians, (*a, *b))
    h = math.sin((lat2 - lat1) / 2) ** 2 + math.cos(lat1) * math.cos(lat2) * math.sin(
        (lon2 - lon1) / 2
    ) ** 2
    return 2 * 6371.0088 * math.asin(min(1, math.sqrt(h)))


def resolve_coordinate(rows: list[dict]) -> tuple[float, float] | None:
    coords = sorted({(float(r["lat"]), float(r["lon"])) for r in rows})
    if any(km(coords[0], c) > MAX_SPREAD_KM for c in coords[1:]):
        return None
    return round(coords[0][0], 4), round(coords[0][1], 4)


def load(name: str) -> tuple[list[dict], str]:
    payload = json.loads((RAW_DIR / f"{name}.json").read_text(encoding="utf-8"))
    return payload["rows"], payload["fetched_at"]


def turkish_places() -> list[dict]:
    rows, _ = load("places_tr")
    by_city: dict[str, list[dict]] = defaultdict(list)
    for row in rows:
        by_city[row["city"]].append(row)
    places = []
    for city, city_rows in sorted(by_city.items()):
        coordinate = resolve_coordinate(city_rows)
        if coordinate is None:
            print(f"  atlandı (koordinatlar tutarsız): {city_rows[0]['cityLabel']}")
            continue
        places.append(
            {
                "id": city,
                "name": city_rows[0]["cityLabel"],
                "lat": coordinate[0],
                "lon": coordinate[1],
                "_views": max(int(r.get("city_views", 0)) for r in city_rows),
            }
        )
    by_views = sorted(places, key=lambda p: (-p["_views"], p["id"]))
    for place in by_views[:MAJOR_TR_CITIES]:
        place["major"] = True
    for place in places:
        del place["_views"]
    return places


def world_places() -> list[dict]:
    rows, _ = load("places_world")
    by_country: dict[str, list[dict]] = defaultdict(list)
    for row in rows:
        by_country[row["country"]].append(row)
    candidates = []
    for country, country_rows in by_country.items():
        name = country_rows[0]["countryLabel"]
        if len({r["city"] for r in country_rows}) > 1:
            print(f"  atlandı (birden fazla başkent): {name}")
            continue
        coordinate = resolve_coordinate(country_rows)
        if coordinate is None:
            print(f"  atlandı (koordinatlar tutarsız): {name}")
            continue
        city = country_rows[0]
        candidates.append(
            (
                max(int(r.get("city_views", 0)) for r in country_rows),
                {
                    "id": city["city"],
                    "name": city["cityLabel"],
                    "country": name,
                    "lat": coordinate[0],
                    "lon": coordinate[1],
                },
            )
        )
    candidates.sort(key=lambda c: (-c[0], c[1]["id"]))
    return sorted((p for _, p in candidates[:WORLD_LIMIT]), key=lambda p: p["id"])


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    print("Yerler hazırlanıyor:")
    tr = turkish_places()
    world = world_places()
    _, fetched_at = load("places_tr")
    payload = {
        "data_year": int(fetched_at[:4]),
        "tr": tr,
        "world": world,
    }
    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUT_PATH.write_text(
        json.dumps(payload, ensure_ascii=False, separators=(",", ":")) + "\n", encoding="utf-8"
    )
    major = sum(1 for p in tr if p.get("major"))
    pairs = len(tr) * (len(tr) - 1) // 2 + len(world) * (len(world) - 1) // 2 + major * len(world)
    size = OUT_PATH.stat().st_size
    print(f"{len(tr)} il merkezi, {len(world)} başkent, ~{pairs} mesafe çifti, {size / 1024:.1f} KB")
    print(f"Yazıldı: {OUT_PATH.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
