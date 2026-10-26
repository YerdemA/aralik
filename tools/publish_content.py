"""Publish the question bank and place data for over-the-air updates.

Usage:  python tools/publish_content.py

Copies assets/questions/questions.json and assets/data/places.json to
docs/content/ (served by GitHub Pages) and bumps the version in
docs/content/manifest.json when anything changed. Commit and push docs/ to
make the update live; apps pick it up within 6 hours of their next launch.

The bank is validated first. Apps reject a bank that does not keep every
question they ship with in the same order, so only ever append questions.
"""

from __future__ import annotations

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
}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def check_append_only(new_bank: Path, old_bank: Path) -> None:
    if not old_bank.exists():
        return
    old_ids = [q["id"] for q in json.loads(old_bank.read_text(encoding="utf-8"))]
    new_ids = [q["id"] for q in json.loads(new_bank.read_text(encoding="utf-8"))]
    if new_ids[: len(old_ids)] != old_ids:
        sys.exit(
            "HATA: Yeni banka yayındaki bankanın devamı değil (sıra değişmiş ya da soru silinmiş).\n"
            "Uygulamalar bunu reddeder. Soruları yalnızca sona ekleyin."
        )


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    validate = subprocess.run(
        [sys.executable, str(ROOT / "tools" / "validate_questions.py"), str(FILES["questions.json"])],
        check=False,
    )
    if validate.returncode != 0:
        print("HATA: Banka doğrulanamadı, yayınlanmadı.")
        return 1

    CONTENT_DIR.mkdir(parents=True, exist_ok=True)
    manifest_path = CONTENT_DIR / "manifest.json"
    manifest = (
        json.loads(manifest_path.read_text(encoding="utf-8"))
        if manifest_path.exists()
        else {"version": 0, "hashes": {}}
    )

    check_append_only(FILES["questions.json"], CONTENT_DIR / "questions.json")

    hashes = {name: sha256(src) for name, src in FILES.items()}
    if hashes == manifest.get("hashes"):
        print(f"Değişiklik yok, sürüm {manifest['version']} kaldı.")
        return 0

    for name, src in FILES.items():
        shutil.copyfile(src, CONTENT_DIR / name)
    manifest = {
        "version": manifest["version"] + 1,
        "questions": "questions.json",
        "places": "places.json",
        "hashes": hashes,
    }
    manifest_path.write_text(json.dumps(manifest, indent=1) + "\n", encoding="utf-8")
    print(f"Yayına hazır: sürüm {manifest['version']} -> docs/content/")
    print("Canlıya almak için docs/ klasörünü commit edip push edin.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
