"""Publish the question bank, daily schedule and place data for over-the-air updates.

Usage:  python tools/publish_content.py [--reset] [--leaderboard URL] [--scoring-v3-day N] [--app-build N]
        [--ios-build N] [--app-store-id ID]

Copies the question bank, the daily schedule and the place data to
docs/content/ (served by GitHub Pages) and bumps the version in
docs/content/manifest.json when anything changed. Commit and push docs/ to
make the update live; apps pick it up within 6 hours of their next launch.

Bank and schedule are validated first. Apps reject a bank or a schedule
that does not keep everything they ship with in the same order, so only
ever append questions and days.

--reset publishes even when the new content does not continue the published
one. Use it only before the first player: installed apps would reject it.

--scoring-v2-day N makes the daily sets and duels of day N on use the
scaled scoring rule (lib/core/answer_scale.dart); app and leaderboard
server both read it. -1 removes it.

--scoring-v3-day N does the same for rule v3: from day N on, a question
with its own "scale" (tools/scales.json) is scored by it. Set it only once
the app version that reads it is out and widely installed; older apps keep
showing their own (v2) points while the board uses v3. -1 removes it.

--app-build N announces that build N (pubspec's "+N") is on Google Play:
apps with an older build offer the update. Set it only once the release is
live on Play, or players are sent to a store page without the update.

--ios-build N does the same for the App Store, and --app-store-id ID gives
the app's numeric App Store id (App Store Connect → App Information → Apple
ID), which the iOS update notice needs to open the store page.
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
    parser.add_argument(
        "--leaderboard",
        metavar="URL",
        help="liderlik sunucusunun https adresi (manifest'e yazılır; '' kapatır)",
    )
    parser.add_argument(
        "--app-build",
        type=int,
        metavar="N",
        help="Play'de yayındaki en yeni build numarası (eskiler güncelleme önerir; 0 kapatır)",
    )
    parser.add_argument(
        "--ios-build",
        type=int,
        metavar="N",
        help="App Store'da yayındaki en yeni build numarası (0 kapatır)",
    )
    parser.add_argument(
        "--app-store-id",
        metavar="ID",
        help="uygulamanın App Store sayısal kimliği ('' kaldırır)",
    )
    parser.add_argument(
        "--scoring-v2-day",
        type=int,
        metavar="N",
        help="günlük set ve düellolar bu gün indeksinden itibaren ölçekli puanla (-1 kaldırır)",
    )
    parser.add_argument(
        "--scoring-v3-day",
        type=int,
        metavar="N",
        help="günlük set ve düellolar bu gün indeksinden itibaren sorunun kendi ölçeğiyle (kural v3; -1 kaldırır)",
    )
    args = parser.parse_args(argv)
    if args.app_build is not None and args.app_build < 0:
        print("HATA: --app-build 0 ya da pozitif olmalı.")
        return 1
    if args.ios_build is not None and args.ios_build < 0:
        print("HATA: --ios-build 0 ya da pozitif olmalı.")
        return 1
    if args.app_store_id and not (
        args.app_store_id.isdigit() and 6 <= len(args.app_store_id) <= 12
    ):
        print("HATA: --app-store-id yalnızca rakamlardan oluşmalı (ör. 6740000000).")
        return 1
    if args.leaderboard and not args.leaderboard.startswith("https://"):
        print("HATA: --leaderboard bir https adresi olmalı.")
        return 1

    # Each question's own scale (rule v3) from tools/scales.json, also for
    # questions the import scripts added since the last publish.
    subprocess.run([sys.executable, str(ROOT / "tools" / "apply_scales.py")], check=True)

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

    # The leaderboard address and the latest app build are read on every
    # manifest check, so changing them needs no new content version.
    extras = {
        "leaderboard": (
            manifest.get("leaderboard")
            if args.leaderboard is None
            else args.leaderboard or None
        ),
        "app_build": (
            manifest.get("app_build")
            if args.app_build is None
            else args.app_build or None
        ),
        "ios_build": (
            manifest.get("ios_build")
            if args.ios_build is None
            else args.ios_build or None
        ),
        "app_store_id": (
            manifest.get("app_store_id")
            if args.app_store_id is None
            else args.app_store_id or None
        ),
        "scoring_v2_day": (
            manifest.get("scoring_v2_day")
            if args.scoring_v2_day is None
            else (None if args.scoring_v2_day < 0 else args.scoring_v2_day)
        ),
        "scoring_v3_day": (
            manifest.get("scoring_v3_day")
            if args.scoring_v3_day is None
            else (None if args.scoring_v3_day < 0 else args.scoring_v3_day)
        ),
    }

    def with_extras(m: dict) -> dict:
        for key, value in extras.items():
            if value is not None and value is not False:
                m[key] = value
            else:
                m.pop(key, None)
        return m

    hashes = {name: sha256(src) for name, src in FILES.items()}
    if hashes == manifest.get("hashes"):
        if any(extras[k] != manifest.get(k) for k in extras):
            manifest_path.write_text(
                json.dumps(with_extras(manifest), indent=1) + "\n",
                encoding="utf-8",
            )
            print(f"Liderlik adresi: {extras['leaderboard'] or 'kapalı'}")
            print(f"Güncelleme önerilen build: {extras['app_build'] or 'kapalı'}")
            print(f"iOS: build {extras['ios_build'] or 'kapalı'}, App Store kimliği {extras['app_store_id'] or 'yok'}")
            print(f"Ölçekli puan başlangıç günü: {extras['scoring_v2_day'] if extras['scoring_v2_day'] is not None else 'yok'}")
            print(f"Kural v3 başlangıç günü: {extras['scoring_v3_day'] if extras['scoring_v3_day'] is not None else 'yok'}")
            print("Canlıya almak için docs/ klasörünü commit edip push edin.")
            return 0
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
    with_extras(manifest)
    manifest_path.write_text(json.dumps(manifest, indent=1) + "\n", encoding="utf-8")
    print(f"Yayına hazır: sürüm {manifest['version']} -> docs/content/")
    print("Canlıya almak için docs/ klasörünü commit edip push edin.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
