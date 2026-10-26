"""Validate assets/questions/questions.json and assets/questions/schedule.json.

Usage:  python tools/validate_questions.py [questions.json] [schedule.json]

Also checks that every question's data set belongs to a source that is
"in_use" in tools/sources.json (so its attribution is shown in the app), and
warns when the bank strays from the target mix in docs/SOURCES.md (no
category above 25%, no data set above 10%).

Exits with code 1 if any error is found. Warnings do not fail the run.
"""

from __future__ import annotations

import json
import re
import sys
from collections import Counter
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_PATH = ROOT / "assets" / "questions" / "questions.json"
DEFAULT_SCHEDULE = ROOT / "assets" / "questions" / "schedule.json"
SOURCES_PATH = ROOT / "tools" / "sources.json"
MAX_CATEGORY_SHARE = 0.25
MAX_DATASET_SHARE = 0.10

KINDS = {"magnitude", "year"}
# "diğer" is the app's fallback for categories it does not know yet; it is
# never written to the bank.
CATEGORIES = {"coğrafya", "tarih", "türkiye", "bilim", "spor", "gündelik", "hayvanlar", "şirketler"}
REQUIRED = {
    "id": str,
    "text": str,
    "answer": (int, float),
    "unit": str,
    "kind": str,
    "category": str,
    "source": str,
    "data_year": int,
}
OPTIONAL = {
    "fun_fact": (str, type(None)),
    "difficulty": int,
    "dataset": str,
    "anchor": dict,
}
ANCHOR_FIELDS = {"text": str, "value": (int, float), "unit": str, "source": str}
ID_PATTERN = re.compile(r"^q(\d{4,})$")
SOURCE_PATTERN = re.compile(r"^https://\S+$")
QUESTIONS_PER_DAY = 5


def in_use_datasets() -> dict[str, str]:
    """data set → source id, for sources whose attribution the app shows."""
    sources = json.loads(SOURCES_PATH.read_text(encoding="utf-8"))["sources"]
    return {ds: s["id"] for s in sources if s["status"] == "in_use" for ds in s.get("datasets", [])}


def validate(questions: object) -> tuple[list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = []
    if not isinstance(questions, list):
        return ["Kök öğe bir liste olmalı."], warnings

    this_year = date.today().year
    attributed = in_use_datasets()
    seen_ids: set[str] = set()
    seen_texts: dict[str, str] = {}
    seen_sources: dict[tuple[str, str, str], str] = {}
    previous_number = 0

    for index, q in enumerate(questions):
        where = f"#{index}"
        if not isinstance(q, dict):
            errors.append(f"{where}: nesne olmalı.")
            continue
        qid = q.get("id")
        if isinstance(qid, str):
            where = qid

        for key, expected in REQUIRED.items():
            if key not in q:
                errors.append(f"{where}: '{key}' alanı eksik.")
            elif not isinstance(q[key], expected) or isinstance(q[key], bool):
                errors.append(f"{where}: '{key}' tipi hatalı ({type(q[key]).__name__}).")
        for key, expected in OPTIONAL.items():
            if key in q and not isinstance(q[key], expected):
                errors.append(f"{where}: '{key}' tipi hatalı.")
        unknown = set(q) - set(REQUIRED) - set(OPTIONAL)
        if unknown:
            warnings.append(f"{where}: bilinmeyen alan(lar): {', '.join(sorted(unknown))}")
        if any(key not in q for key in REQUIRED):
            continue

        # id: unique and strictly increasing, so the file order never changes.
        match = ID_PATTERN.match(q["id"])
        if not match:
            errors.append(f"{where}: id biçimi 'q0001' olmalı.")
        else:
            number = int(match.group(1))
            if number <= previous_number:
                errors.append(f"{where}: id'ler dosya sırasında artan olmalı.")
            previous_number = number
        if q["id"] in seen_ids:
            errors.append(f"{where}: yinelenen id.")
        seen_ids.add(q["id"])

        text = q["text"].strip()
        if not text:
            errors.append(f"{where}: soru metni boş.")
        elif not text.endswith("?"):
            errors.append(f"{where}: soru metni '?' ile bitmeli.")
        if text != q["text"]:
            warnings.append(f"{where}: soru metninin başında/sonunda boşluk var.")
        normalized = " ".join(text.casefold().split())
        if normalized in seen_texts:
            errors.append(f"{where}: aynı soru metni {seen_texts[normalized]} ile yineleniyor.")
        seen_texts[normalized] = q["id"]

        if q["kind"] not in KINDS:
            errors.append(f"{where}: kind '{q['kind']}' geçersiz.")
        if q["category"] not in CATEGORIES:
            errors.append(f"{where}: kategori '{q['category']}' geçersiz.")

        answer = q["answer"]
        if q["kind"] == "magnitude":
            if answer <= 0:
                errors.append(f"{where}: magnitude cevabı pozitif olmalı.")
            if not q["unit"].strip():
                errors.append(f"{where}: magnitude sorusunda birim boş olamaz.")
        elif q["kind"] == "year":
            if not isinstance(answer, int):
                errors.append(f"{where}: year cevabı tam sayı olmalı.")
            elif not -5000 <= answer <= this_year:
                errors.append(f"{where}: yıl {answer} makul aralıkta değil.")

        if not SOURCE_PATTERN.match(q["source"]):
            errors.append(f"{where}: kaynak bir https bağlantısı olmalı.")
        key = (q["source"], q["kind"], q["unit"])
        if key in seen_sources:
            errors.append(f"{where}: aynı kaynak/tür {seen_sources[key]} ile yineleniyor.")
        seen_sources[key] = q["id"]

        if not 1800 <= q["data_year"] <= this_year + 1:
            errors.append(f"{where}: data_year {q['data_year']} makul değil.")

        fun_fact = q.get("fun_fact")
        if isinstance(fun_fact, str) and not fun_fact.strip():
            warnings.append(f"{where}: fun_fact boş metin; null kullan.")

        difficulty = q.get("difficulty")
        if "difficulty" in q and (isinstance(difficulty, bool) or difficulty not in (1, 2, 3)):
            errors.append(f"{where}: difficulty 1, 2 ya da 3 olmalı.")
        dataset = q.get("dataset")
        if isinstance(dataset, str) and dataset not in attributed:
            errors.append(
                f"{where}: '{dataset}' veri seti tools/sources.json içinde kullanımdaki bir kaynağa bağlı değil."
            )
        anchor = q.get("anchor")
        if isinstance(anchor, dict):
            for key, expected in ANCHOR_FIELDS.items():
                if not isinstance(anchor.get(key), expected) or isinstance(anchor.get(key), bool):
                    errors.append(f"{where}: anchor.{key} eksik ya da hatalı.")
            if isinstance(anchor.get("source"), str) and not SOURCE_PATTERN.match(anchor["source"]):
                errors.append(f"{where}: anchor kaynağı bir https bağlantısı olmalı.")

    valid = [q for q in questions if isinstance(q, dict)]
    if valid:
        for category, count in Counter(q.get("category") for q in valid).items():
            if count / len(valid) > MAX_CATEGORY_SHARE:
                warnings.append(f"'{category}' kategorisinin bankadaki payı %{100 * count // len(valid)} (hedef ≤ %25).")
        for dataset, count in Counter(q.get("dataset") for q in valid if q.get("dataset")).items():
            if count / len(valid) > MAX_DATASET_SHARE:
                warnings.append(f"'{dataset}' veri setinin bankadaki payı %{100 * count // len(valid)} (hedef ≤ %10).")

    return errors, warnings


def validate_schedule(schedule: object, questions: list) -> tuple[list[str], list[str]]:
    """Shape and references of schedule.json; the day rules as warnings."""
    errors: list[str] = []
    warnings: list[str] = []
    days = schedule.get("days") if isinstance(schedule, dict) else None
    if not isinstance(days, list):
        return ['Takvim {"days": [...]} biçiminde olmalı.'], warnings
    by_id = {q.get("id"): q for q in questions if isinstance(q, dict)}
    seen: set[str] = set()
    for i, day in enumerate(days):
        where = f"Gün {i}"
        if not isinstance(day, list) or len(day) != QUESTIONS_PER_DAY or not all(isinstance(x, str) for x in day):
            errors.append(f"{where}: tam {QUESTIONS_PER_DAY} soru id'si olmalı.")
            continue
        for qid in day:
            if qid in seen:
                errors.append(f"{where}: {qid} takvimde ikinci kez geçiyor.")
            seen.add(qid)
            if qid not in by_id:
                errors.append(f"{where}: {qid} bankada yok.")
        qs = [by_id[x] for x in day if x in by_id]
        if len({q.get("category") for q in qs}) < 3:
            warnings.append(f"{where}: 3'ten az kategori.")
        datasets = Counter(q.get("dataset") for q in qs if q.get("dataset"))
        if any(n > 1 for n in datasets.values()):
            warnings.append(f"{where}: aynı veri setinden birden çok soru.")
        if sorted(q.get("difficulty") for q in qs) != [1, 1, 2, 2, 3]:
            warnings.append(f"{where}: 2 kolay + 2 orta + 1 zor değil.")
    return errors, warnings


def main(argv: list[str]) -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    path = Path(argv[0]) if argv else DEFAULT_PATH
    schedule_path = Path(argv[1]) if len(argv) > 1 else DEFAULT_SCHEDULE
    try:
        questions = json.loads(path.read_text(encoding="utf-8"))
        schedule = json.loads(schedule_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        print(f"HATA: okunamadı: {error}")
        return 1

    errors, warnings = validate(questions)
    if isinstance(questions, list):
        schedule_errors, schedule_warnings = validate_schedule(schedule, questions)
        errors += schedule_errors
        warnings += schedule_warnings
    for message in warnings:
        print(f"UYARI: {message}")
    for message in errors:
        print(f"HATA: {message}")

    if isinstance(questions, list):
        valid = [q for q in questions if isinstance(q, dict)]
        categories = Counter(q.get("category") for q in valid)
        kinds = Counter(q.get("kind") for q in valid)
        days = schedule.get("days", []) if isinstance(schedule, dict) else []
        print(
            f"{len(questions)} soru, takvimde {len(days)} gün. "
            + ", ".join(f"{k}: {v}" for k, v in sorted(categories.items(), key=str))
            + " | "
            + ", ".join(f"{k}: {v}" for k, v in sorted(kinds.items(), key=str))
        )
    print(f"{len(errors)} hata, {len(warnings)} uyarı.")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
