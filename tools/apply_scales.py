"""Writes each question's own slider scale (rule v3) into the bank.

Usage:  python tools/apply_scales.py [--check]

tools/scales.json maps data sets (and single question ids, which win) to a
scale: {"half": N} linear guess ± N units, or {"factor": F} ÷F … ×F. The
app and the leaderboard server read it as the question's "scale" field
from the day in the manifest's scoring_v3_day on (lib/core/answer_scale.dart
refinedScaleOf, server/leaderboard/src/scoring.js refinedScaleOf).
Percentages (unit %) and year questions never get one.

--check only reports questions whose field differs (exit code 1).
publish_content.py runs this before every publish, so questions added by
the import scripts get their data set's scale.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BANK = ROOT / "assets" / "questions" / "questions.json"
SCALES = ROOT / "tools" / "scales.json"


def valid_scale(scale: object) -> bool:
    """The same rule as QuestionScale.fromJson / questionScale."""
    if not isinstance(scale, dict) or len(scale) != 1:
        return False
    half, factor = scale.get("half"), scale.get("factor")
    if half is not None:
        return isinstance(half, int) and not isinstance(half, bool) and 1 <= half <= 1000
    return isinstance(factor, (int, float)) and not isinstance(factor, bool) and 1 < factor <= 20


def load_scales() -> tuple[dict, dict]:
    data = json.loads(SCALES.read_text(encoding="utf-8"))
    datasets, questions = data.get("datasets", {}), data.get("questions", {})
    for key, scale in [*datasets.items(), *questions.items()]:
        if not valid_scale(scale):
            raise ValueError(f"scales.json: '{key}' için geçersiz ölçek {scale}")
    return datasets, questions


def wanted(q: dict, datasets: dict, questions: dict) -> dict | None:
    """The scale [q] should carry, or None."""
    if q.get("kind") != "magnitude" or q.get("unit") == "%":
        return None
    return questions.get(q["id"]) or datasets.get(q.get("dataset", ""))


def differences(bank: list, datasets: dict, questions: dict) -> list[str]:
    return [q["id"] for q in bank if q.get("scale") != wanted(q, datasets, questions)]


def apply(bank: list, datasets: dict, questions: dict) -> int:
    """Sets or removes each question's "scale"; returns how many changed."""
    changed = 0
    for q in bank:
        want = wanted(q, datasets, questions)
        if q.get("scale") == want:
            continue
        if want is None:
            q.pop("scale")
        else:
            q["scale"] = want
        changed += 1
    return changed


def main(argv: list[str]) -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    datasets, questions = load_scales()
    bank = json.loads(BANK.read_text(encoding="utf-8"))
    if "--check" in argv:
        diff = differences(bank, datasets, questions)
        if diff:
            print(f"{len(diff)} sorunun ölçeği scales.json'la uyuşmuyor: {', '.join(diff[:10])}…")
            return 1
        print("Ölçekler güncel.")
        return 0
    changed = apply(bank, datasets, questions)
    if changed:
        BANK.write_text(json.dumps(bank, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    with_scale = sum(1 for q in bank if "scale" in q)
    print(f"{changed} soru güncellendi; {with_scale} sorunun kendi ölçeği var.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
