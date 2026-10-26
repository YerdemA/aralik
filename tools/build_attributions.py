"""Build the attribution list from tools/sources.json.

Usage:  python tools/build_attributions.py

Writes
  assets/data/attributions.json  shown in the app (Ayarlar → Veri kaynakları)
  docs/attributions.md           published next to the privacy policy

Only sources with status "in_use" are listed: crediting a source the bank
does not use would be misleading. Planned sources show up as soon as their
status changes. validate_questions.py checks that every question's data set
belongs to an in-use source.
"""

from __future__ import annotations

import json
import sys
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCES_PATH = ROOT / "tools" / "sources.json"
APP_PATH = ROOT / "assets" / "data" / "attributions.json"
DOC_PATH = ROOT / "docs" / "attributions.md"

STATUSES = {"in_use", "planned", "reference_only", "do_not_use"}
REQUIRED = ("id", "name", "license", "license_url", "url", "attribution", "status")
APP_FIELDS = ("name", "attribution", "license", "license_url", "url")


def load_sources() -> list[dict]:
    """Sources from tools/sources.json, checked. Exits on an invalid entry."""
    sources = json.loads(SOURCES_PATH.read_text(encoding="utf-8"))["sources"]
    errors = []
    seen_ids: set[str] = set()
    seen_datasets: dict[str, str] = {}
    for s in sources:
        missing = [k for k in REQUIRED if not s.get(k)]
        if missing:
            errors.append(f"{s.get('id', '?')}: eksik alan(lar): {', '.join(missing)}")
            continue
        if s["id"] in seen_ids:
            errors.append(f"{s['id']}: yinelenen id")
        seen_ids.add(s["id"])
        if s["status"] not in STATUSES:
            errors.append(f"{s['id']}: geçersiz durum '{s['status']}'")
        for key in ("url", "license_url"):
            if not s[key].startswith("https://"):
                errors.append(f"{s['id']}: {key} https ile başlamalı")
        for ds in s.get("datasets", []):
            if ds in seen_datasets:
                errors.append(f"{ds}: hem {seen_datasets[ds]} hem {s['id']} kaynağında")
            seen_datasets[ds] = s["id"]
    if errors:
        sys.exit("HATA: tools/sources.json geçersiz:\n  " + "\n  ".join(errors))
    return sources


def dataset_sources(sources: list[dict]) -> dict[str, dict]:
    """data set name → its source."""
    return {ds: s for s in sources for ds in s.get("datasets", [])}


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    in_use = [s for s in load_sources() if s["status"] == "in_use"]

    APP_PATH.parent.mkdir(parents=True, exist_ok=True)
    app = [{k: s[k] for k in APP_FIELDS} for s in in_use]
    APP_PATH.write_text(json.dumps(app, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")

    lines = [
        "# Kabaca: Veri kaynakları ve lisanslar",
        "",
        "Kabaca'daki sorular ve cevapları aşağıdaki kaynaklara dayanır. Her soruda, cevabın",
        "görüldüğü sayfanın bağlantısı ayrıca gösterilir. Bu liste `tools/sources.json`",
        "dosyasından üretilir; uygulamada Ayarlar → Veri kaynakları ve lisanslar ekranında",
        "aynı liste yer alır.",
        "",
    ]
    for s in in_use:
        lines += [
            f"## {s['name']}",
            f"- {s['attribution']}",
            f"- Lisans: [{s['license']}]({s['license_url']})",
            f"- Adres: {s['url']}",
            "",
        ]
    lines += [f"*Son güncelleme: {date.today().isoformat()}*", ""]
    DOC_PATH.write_text("\n".join(lines), encoding="utf-8")

    print(f"{len(in_use)} kullanımdaki kaynak yazıldı:")
    print(f"  {APP_PATH.relative_to(ROOT)}")
    print(f"  {DOC_PATH.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
