"""Build assets/questions/schedule.json: which five questions come on which day.

Usage:  python tools/build_schedule.py [--days N] [--fresh] [--dry-run] [--bank PATH]

Every day has 2 easy + 2 medium + 1 hard question (the bank's "difficulty"),
from at least 3 categories, never two from the same data set and never two
about the same item (e.g. a company's founding year and its employees).
Within a day they are ordered easy → hard.

The schedule is append-only: existing days are kept and new days are added
until the schedule has N days (default 45). --fresh rebuilds it from
scratch; use it only before the first player has the app. Questions that
are never scheduled feed free play.

The build is deterministic (fixed seed). When a difficulty runs out it stops
and reports how many days it could make instead of loosening the rules.
"""

from __future__ import annotations

import argparse
import json
import random
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BANK_PATH = ROOT / "assets" / "questions" / "questions.json"
OUT_PATH = ROOT / "assets" / "questions" / "schedule.json"

SEED = 20261101
DEFAULT_DAYS = 45
# How many questions of each difficulty a day takes, in play order.
DAY_SHAPE = {1: 2, 2: 2, 3: 1}
MIN_CATEGORIES_PER_DAY = 3
ATTEMPTS_PER_DAY = 200


def make_day(pool: dict[int, list[dict]], rng: random.Random) -> list[dict] | None:
    """One day from [pool] (by difficulty), or None if the rules can't be met.

    Prefers data sets with many questions left, so small ones are not used
    up early and later days keep their variety."""
    remaining = Counter(q["dataset"] for qs in pool.values() for q in qs)
    for _ in range(ATTEMPTS_PER_DAY):
        day: list[dict] = []
        datasets: set[str] = set()
        sources: set[str] = set()
        for difficulty, count in DAY_SHAPE.items():
            candidates = [
                q for q in pool[difficulty] if q["dataset"] not in datasets and q["source"] not in sources
            ]
            rng.shuffle(candidates)
            candidates.sort(key=lambda q: -remaining[q["dataset"]] * rng.uniform(0.5, 1.0))
            for q in candidates:
                if len([d for d in day if d.get("difficulty") == difficulty]) == count:
                    break
                if q["dataset"] in datasets or q["source"] in sources:
                    continue
                day.append(q)
                datasets.add(q["dataset"])
                sources.add(q["source"])
        complete = len(day) == sum(DAY_SHAPE.values())
        if complete and len({q["category"] for q in day}) >= MIN_CATEGORIES_PER_DAY:
            return day
    return None


def main(argv: list[str]) -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--days", type=int, default=DEFAULT_DAYS, help="takvimin toplam gün sayısı")
    parser.add_argument("--fresh", action="store_true", help="mevcut takvimi yok say")
    parser.add_argument("--dry-run", action="store_true", help="dosyaya yazma")
    parser.add_argument("--bank", type=Path, default=BANK_PATH, help="soru bankası (deneme için)")
    args = parser.parse_args(argv)

    bank = json.loads(args.bank.read_text(encoding="utf-8"))
    by_id = {q["id"]: q for q in bank}
    days: list[list[str]] = []
    if OUT_PATH.exists() and not args.fresh:
        days = json.loads(OUT_PATH.read_text(encoding="utf-8"))["days"]
    scheduled = {qid for day in days for qid in day}
    missing = scheduled - by_id.keys()
    if missing:
        sys.exit(f"HATA: takvimdeki sorular bankada yok: {sorted(missing)}")

    unrated = [q["id"] for q in bank if q.get("difficulty") not in DAY_SHAPE or "dataset" not in q]
    if unrated:
        print(f"UYARI: zorluğu ya da veri seti olmayan {len(unrated)} soru takvime alınmadı.")
    pool: dict[int, list[dict]] = {d: [] for d in DAY_SHAPE}
    for q in bank:
        if q["id"] not in scheduled and q["id"] not in unrated:
            pool[q["difficulty"]].append(q)
    for qs in pool.values():
        qs.sort(key=lambda q: q["id"])  # independent of file order

    rng = random.Random(f"{SEED}:{len(days)}")
    added = 0
    while len(days) < args.days:
        day = make_day(pool, rng)
        if day is None:
            break
        for q in day:
            pool[q["difficulty"]].remove(q)
        day.sort(key=lambda q: q["difficulty"])  # easy → hard
        days.append([q["id"] for q in day])
        added += 1

    left = Counter({d: len(qs) for d, qs in pool.items()})
    print(f"{len(days) - added} mevcut + {added} yeni = {len(days)} gün (hedef {args.days}).")
    print(f"Takvim dışı kalan (serbest mod): kolay {left[1]}, orta {left[2]}, zor {left[3]}.")
    if len(days) < args.days:
        need = {d: n * (args.days - len(days)) for d, n in DAY_SHAPE.items()}
        print(
            "EKSİK: hedefe ulaşmak için en az şu kadar uygun soru daha gerekiyor: "
            f"kolay {max(0, need[1] - left[1])}, orta {max(0, need[2] - left[2])}, "
            f"zor {max(0, need[3] - left[3])} (kategori/veri seti kuralları ayrıca kısıtlar)."
        )
    if args.dry_run:
        return 0 if len(days) >= args.days else 1
    lines = ",\n".join("  " + json.dumps(day, ensure_ascii=False) for day in days)
    OUT_PATH.write_text('{"days": [\n' + lines + "\n]}\n", encoding="utf-8")
    print(f"Yazıldı: {OUT_PATH.relative_to(ROOT)}")
    return 0 if len(days) >= args.days else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
