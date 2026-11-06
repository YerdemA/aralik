"""Football questions computed from openfootball match results, appended to the bank.

Usage:  python tools/import_football.py [--fetch] [--dry-run]

Two kinds of question, both computed from every match of the file:

  tournament goals  "2018 Dünya Kupası'nda toplam kaç gol atıldı?"
                    Sum of the final scores (after extra time; shoot-outs
                    do not count). FIFA World Cups 1930-2022, Euro 2020, 2024.
  champion points   "Manchester City 2017-18 Premier Lig sezonunu kaç puanla
                    şampiyon olarak tamamlamıştır?"  3 for a win, 1 for a draw.

A file is skipped when a match has no score (cancelled or unfinished
seasons). A league season is skipped when the top two have the same points:
who won then depends on the league's tie-break, which is not computed here.
Points deductions are not in the data; no champion in LEAGUES had one.

--fetch downloads the files into tools/raw/openfootball/cache/ (git-ignored)
and writes the computed totals to tools/raw/openfootball/summary.json
(committed); without it that file is read. openfootball data is in the
public domain. The source of a question is the file it is computed from.
"""

from __future__ import annotations

import argparse
import json
import random
import sys
import urllib.error
import urllib.request
from collections import Counter, defaultdict
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BANK = ROOT / "assets" / "questions" / "questions.json"
RAW = ROOT / "tools" / "raw" / "openfootball"
CACHE = RAW / "cache"
SUMMARY = RAW / "summary.json"
SEED = 20261109
USER_AGENT = "KabacaContentCheck/1.0 (https://github.com/YerdemA/aralik)"

# (key, repository, path, question text, year played, difficulty)
TOURNAMENTS = [
    *(
        (f"wc{year}", "worldcup.json", f"{year}/worldcup.json", f"{year} Dünya Kupası'nda toplam kaç gol atıldı?", year, 2 if year >= 2014 else 3)
        for year in (1930, 1934, 1938, 1950, 1954, 1958, 1962, 1966, 1970, 1974, 1978,
                     1982, 1986, 1990, 1994, 1998, 2002, 2006, 2010, 2014, 2018, 2022)
    ),
    ("euro2020", "euro.json", "2020/euro.json", "Euro 2020'de (2021'de oynandı) toplam kaç gol atıldı?", 2021, 3),
    ("euro2024", "euro.json", "2024/euro.json", "Euro 2024'te toplam kaç gol atıldı?", 2024, 2),
]

LEAGUES = {"en.1": ("Premier Lig", 2), "es.1": ("La Liga", 3), "de.1": ("Bundesliga", 3), "it.1": ("Serie A", 3)}


def seasons(first: int, last: int = 2024) -> list[str]:
    return [f"{y}-{str(y + 1)[2:]}" for y in range(first, last + 1)]


# Champion points all fall between about 75 and 100, so the same question
# many times over gets dull: the Premier League (most followed here) for ten
# seasons, the others for five plus one record season (100, 91, 102 points).
SEASONS = {
    "en.1": seasons(2015),
    "es.1": ["2012-13", *seasons(2020)],
    "de.1": ["2012-13", *seasons(2020)],
    "it.1": ["2013-14", *seasons(2020)],
}

TEAM_NAMES = {
    "Manchester City": "Manchester City", "Manchester City FC": "Manchester City",
    "Liverpool FC": "Liverpool", "Chelsea FC": "Chelsea", "Leicester City": "Leicester City",
    "FC Barcelona": "Barcelona", "Real Madrid": "Real Madrid", "Real Madrid CF": "Real Madrid",
    "Atlético Madrid": "Atlético Madrid", "Club Atlético de Madrid": "Atlético Madrid",
    "Bayern München": "Bayern Münih", "FC Bayern München": "Bayern Münih",
    "Bayer 04 Leverkusen": "Bayer Leverkusen", "Borussia Dortmund": "Borussia Dortmund",
    "Juventus": "Juventus", "FC Internazionale Milano": "Inter", "Inter": "Inter",
    "AC Milan": "Milan", "SSC Napoli": "Napoli",
}

# Official totals, only to catch a broken file (the answer is computed).
FIFA_GOALS = {
    "wc1930": 70, "wc1934": 70, "wc1938": 84, "wc1950": 88, "wc1954": 140, "wc1958": 126,
    "wc1962": 89, "wc1966": 89, "wc1970": 95, "wc1974": 97, "wc1978": 102, "wc1982": 146,
    "wc1986": 132, "wc1990": 115, "wc1994": 141, "wc1998": 171, "wc2002": 161, "wc2006": 147,
    "wc2010": 145, "wc2014": 171, "wc2018": 169, "wc2022": 172, "euro2020": 142, "euro2024": 117,
}


def raw_url(repo: str, path: str) -> str:
    return f"https://raw.githubusercontent.com/openfootball/{repo}/master/{path}"


def page_url(repo: str, path: str) -> str:
    return f"https://github.com/openfootball/{repo}/blob/master/{path}"


def download(repo: str, path: str) -> list[dict] | None:
    target = CACHE / repo / path
    if not target.exists():
        try:
            request = urllib.request.Request(raw_url(repo, path), headers={"User-Agent": USER_AGENT})
            with urllib.request.urlopen(request, timeout=60) as response:
                data = response.read()
        except urllib.error.HTTPError as error:
            print(f"  {repo}/{path}: {error.code}")
            return None
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
    return json.loads(target.read_text(encoding="utf-8"))["matches"]


def final_score(match: dict, *, extra_time: bool) -> list[int] | None:
    score = match.get("score")
    if isinstance(score, list):
        return score or None
    if not score:
        return None
    return (extra_time and score.get("et")) or score.get("ft")


def tournament_summary(matches: list[dict]) -> dict:
    played = [s for s in (final_score(m, extra_time=True) for m in matches) if s]
    # A walkover (1938, Austria-Sweden) has no score and was not played.
    return {"matches": len(played), "goals": sum(sum(s) for s in played), "unscored": len(matches) - len(played)}


def league_summary(matches: list[dict]) -> dict:
    points: dict[str, int] = defaultdict(int)
    scored: dict[str, int] = defaultdict(int)
    unscored = 0
    for m in matches:
        score = final_score(m, extra_time=False)
        if not score:
            unscored += 1
            continue
        home, away = score
        scored[m["team1"]] += home
        scored[m["team2"]] += away
        if home > away:
            points[m["team1"]] += 3
        elif away > home:
            points[m["team2"]] += 3
        else:
            points[m["team1"]] += 1
            points[m["team2"]] += 1
    table = sorted(points.items(), key=lambda item: -item[1])
    return {
        "matches": len(matches),
        "unscored": unscored,
        "table": [{"team": team, "points": pts, "goals": scored[team]} for team, pts in table],
    }


def fetch() -> dict:
    tournaments = {}
    for key, repo, path, *_ in TOURNAMENTS:
        matches = download(repo, path)
        if matches is not None:
            tournaments[key] = {"repo": repo, "path": path, **tournament_summary(matches)}
    leagues = {}
    for code in LEAGUES:
        for season in SEASONS[code]:
            path = f"{season}/{code}.json"
            matches = download("football.json", path)
            if matches is not None:
                leagues[f"{season}/{code}"] = {"repo": "football.json", "path": path, **league_summary(matches)}
    payload = {"fetched": date.today().isoformat(), "tournaments": tournaments, "leagues": leagues}
    SUMMARY.parent.mkdir(parents=True, exist_ok=True)
    SUMMARY.write_text(json.dumps(payload, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"Yazıldı: {SUMMARY.relative_to(ROOT)} ({len(tournaments)} turnuva, {len(leagues)} sezon)")
    return payload


def turkish_decimal(value: float) -> str:
    return f"{value:.2f}".rstrip("0").rstrip(".").replace(".", ",")


def build(payload: dict, bank: list[dict]) -> tuple[list[dict], list[str]]:
    asked = {(q["source"], q["kind"], q["unit"]) for q in bank}
    texts = {q["text"].casefold() for q in bank}
    new, dropped = [], []

    def add(q: dict) -> None:
        key = (q["source"], q["kind"], q["unit"])
        if key in asked or q["text"].casefold() in texts:
            return  # imported earlier
        asked.add(key)
        texts.add(q["text"].casefold())
        new.append(q)

    for key, repo, path, text, year, difficulty in TOURNAMENTS:
        summary = payload["tournaments"].get(key)
        if summary is None:
            dropped.append(f"VERİ YOK: {key}")
            continue
        if summary["goals"] != FIFA_GOALS[key]:
            dropped.append(f"RESMÎ TOPLAMLA TUTMUYOR: {key}: {summary['goals']} (resmî {FIFA_GOALS[key]})")
            continue
        add(
            {
                "text": text,
                "answer": summary["goals"],
                "unit": "gol",
                "kind": "magnitude",
                "category": "spor",
                "source": page_url(repo, path),
                "data_year": year,
                "fun_fact": f"{summary['matches']} maç oynandı, maç başına {turkish_decimal(summary['goals'] / summary['matches'])} gol.",
                "difficulty": difficulty,
                "dataset": "football_tournaments",
            }
        )

    for season_code, summary in payload["leagues"].items():
        season, code = season_code.split("/")
        league, difficulty = LEAGUES[code]
        label = f"{league} {season}"
        expected = len(summary["table"]) * (len(summary["table"]) - 1)
        if summary["unscored"] or summary["matches"] != expected:
            dropped.append(f"EKSİK MAÇ: {label} ({summary['unscored']} skorsuz, {summary['matches']}/{expected})")
            continue
        first, second = summary["table"][:2]
        if first["points"] == second["points"]:
            dropped.append(f"PUAN EŞİT, ŞAMPİYON BELİRSİZ: {label}")
            continue
        team = TEAM_NAMES.get(first["team"])
        if team is None:
            sys.exit(f"HATA: TEAM_NAMES içinde yok: {first['team']} ({label})")
        add(
            {
                "text": f"{team}, {season} {league} sezonunu kaç puanla şampiyon olarak tamamlamıştır?",
                "answer": first["points"],
                "unit": "puan",
                "kind": "magnitude",
                "category": "spor",
                "source": page_url(summary["repo"], summary["path"]),
                "data_year": 2000 + int(season[-2:]),
                "fun_fact": f"Sezon boyunca {first['goals']} gol attı, ikinciyle arasında {first['points'] - second['points']} puan vardı.",
                "difficulty": difficulty,
                "dataset": "football_league_points",
            }
        )
    return new, dropped


def main(argv: list[str]) -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--fetch", action="store_true", help="openfootball dosyalarını indirip yeniden hesapla")
    parser.add_argument("--dry-run", action="store_true", help="bankaya yazma")
    args = parser.parse_args(argv)

    payload = fetch() if args.fetch or not SUMMARY.exists() else json.loads(SUMMARY.read_text(encoding="utf-8"))
    bank = json.loads(BANK.read_text(encoding="utf-8"))
    new, dropped = build(payload, bank)
    for line in dropped:
        print(f"  - {line}")
    for q in new:
        print(f"  + z{q['difficulty']} {q['text']} = {q['answer']} {q['unit']}  [{q['fun_fact']}]")
    print(f"{len(new)} yeni, {len(dropped)} düşürüldü.")
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
