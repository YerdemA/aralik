"""Publish the question bank, daily schedule and place data for over-the-air updates.

Usage:  python tools/publish_content.py [--reset]

Copies the question bank, the daily schedule and the place data to
docs/content/ (served by GitHub Pages) and bumps the version in
docs/content/manifest.json when anything changed. Commit and push docs/ to
make the update live; apps pick it up within 6 hours of their next launch.

Bank and schedule are validated first. Apps reject a bank or a schedule
that does not keep everything they ship with in the same order, so only
ever append questions and days.

--reset publishes even when the new content does not continue the published
one. Use it only before the first player: installed apps would reject it.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONTENT_DIR = ROOT / "docs" / "content"
FILES = {
    "questions.json": ROOT / "assets" / "questions" / "questions.json",
    "places.json": ROOT / "assets" / "data" / "places.json",
    "schedule.json": ROOT / "assets" / "questions" / "schedule.json",
}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def check_append_only() -> None:
    """Exit unless the bank and the schedule continue the published ones."""
    old_bank = CONTENT_DIR / "questions.json"
    if old_bank.exists():
        old_ids = [q["id"] for q in json.loads(old_bank.read_text(encoding="utf-8"))]
        new_ids = [q["id"] for q in json.loads(FILES["questions.json"].read_text(encoding="utf-8"))]
        if new_ids[: len(old_ids)] != old_ids:
            sys.exit(
                "HATA: Yeni banka yayındaki bankanın devamı değil (sıra değişmiş ya da soru silinmiş).\n"
                "Uygulamalar bunu reddeder. Soruları yalnızca sona ekleyin."
            )
    old_schedule = CONTENT_DIR / "schedule.json"
    if old_schedule.exists():
        old_days = json.loads(old_schedule.read_text(encoding="utf-8"))["days"]
        new_days = json.loads(FILES["schedule.json"].read_text(encoding="utf-8"))["days"]
        if new_days[: len(old_days)] != old_days:
            sys.exit(
                "HATA: Yeni takvim yayındaki takvimin devamı değil (bir gün değişmiş ya da silinmiş).\n"
                "Uygulamalar bunu reddeder. Günleri yalnızca sona ekleyin."
            )


def main(argv: list[str]) -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "--reset",
        action="store_true",
        help="yayındakinin devamı olma şartını atla (yalnızca ilk oyuncudan önce)",
    )
    args = parser.parse_args(argv)

    validate = subprocess.run(
        [
            sys.executable,
            str(ROOT / "tools" / "validate_questions.py"),
            str(FILES["questions.json"]),
            str(FILES["schedule.json"]),
        ],
        check=False,
    )
    if validate.returncode != 0:
        print("HATA: Banka ya da takvim doğrulanamadı, yayınlanmadı.")
        return 1

    CONTENT_DIR.mkdir(parents=True, exist_ok=True)
    manifest_path = CONTENT_DIR / "manifest.json"
    manifest = (
        json.loads(manifest_path.read_text(encoding="utf-8"))
        if manifest_path.exists()
        else {"version": 0, "hashes": {}}
    )

    if args.reset:
        print("UYARI: --reset: yayındaki içeriğin devamı olma şartı atlandı.")
    else:
        check_append_only()

    hashes = {name: sha256(src) for name, src in FILES.items()}
    if hashes == manifest.get("hashes"):
        print(f"Değişiklik yok, sürüm {manifest['version']} kaldı.")
        return 0

    for name, src in FILES.items():
        shutil.copyfile(src, CONTENT_DIR / name)
    manifest = {
        # Always increases, also after --reset: apps only take newer versions.
        "version": manifest["version"] + 1,
        "questions": "questions.json",
        "places": "places.json",
        "schedule": "schedule.json",
        "hashes": hashes,
    }
    manifest_path.write_text(json.dumps(manifest, indent=1) + "\n", encoding="utf-8")
    print(f"Yayına hazır: sürüm {manifest['version']} -> docs/content/")
    print("Canlıya almak için docs/ klasörünü commit edip push edin.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
