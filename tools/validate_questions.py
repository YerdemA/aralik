"""Validate assets/questions/questions.json.

Usage:  python tools/validate_questions.py [path]

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

KINDS = {"magnitude", "year"}
CATEGORIES = {"coğrafya", "tarih", "türkiye", "bilim", "spor", "gündelik"}
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
OPTIONAL = {"fun_fact": (str, type(None))}
ID_PATTERN = re.compile(r"^q(\d{4,})$")
SOURCE_PATTERN = re.compile(r"^https://\S+$")
QUESTIONS_PER_DAY = 5


def validate(questions: object) -> tuple[list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = []
    if not isinstance(questions, list):
        return ["Kök öğe bir liste olmalı."], warnings

    this_year = date.today().year
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

    # The same entity twice on one day spoils the second question.
    for start in range(0, len(questions), QUESTIONS_PER_DAY):
        day = [q for q in questions[start : start + QUESTIONS_PER_DAY] if isinstance(q, dict)]
        sources = Counter(q.get("source") for q in day)
        for source, count in sources.items():
            if count > 1:
                warnings.append(
                    f"Gün {start // QUESTIONS_PER_DAY}: aynı kaynak {count} kez ({source})."
                )

    return errors, warnings


def main(argv: list[str]) -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    path = Path(argv[0]) if argv else DEFAULT_PATH
    try:
        questions = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        print(f"HATA: {path} okunamadı: {error}")
        return 1

    errors, warnings = validate(questions)
    for message in warnings:
        print(f"UYARI: {message}")
    for message in errors:
        print(f"HATA: {message}")

    if isinstance(questions, list):
        valid = [q for q in questions if isinstance(q, dict)]
        categories = Counter(q.get("category") for q in valid)
        kinds = Counter(q.get("kind") for q in valid)
        print(
            f"{len(questions)} soru, {len(questions) // QUESTIONS_PER_DAY} günlük set. "
            + ", ".join(f"{k}: {v}" for k, v in sorted(categories.items(), key=str))
            + " | "
            + ", ".join(f"{k}: {v}" for k, v in sorted(kinds.items(), key=str))
        )
    print(f"{len(errors)} hata, {len(warnings)} uyarı.")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
