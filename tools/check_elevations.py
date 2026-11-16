"""Cross-checks Wikidata elevations with the Turkish Wikipedia infobox.

Usage:  python tools/check_elevations.py [dataset ...]

Wikidata's elevation of a city is sometimes far off (Bilecik: 850 m on
Wikidata, 513 m in the Turkish article, 2026-11-16). For every item of the
given Wikidata dumps (default: cities_tr_elevation, capitals_elevation) the
article's lead section is read and its `rakım_m` / `rakım` / `yükselti`
field kept. build_questions.py asks an elevation only when both agree
within ELEVATION_TOLERANCE.

Writes tools/raw/wikidata/elevation_check.json: {qid: metres or null}.
Only the number is used, as a check; the answer and source stay Wikidata.
"""

from __future__ import annotations

import json
import re
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "tools" / "raw" / "wikidata"
OUT = RAW / "elevation_check.json"
API = "https://tr.wikipedia.org/w/api.php?action=parse&prop=wikitext&format=json&section=0&redirects=1&page={title}"
USER_AGENT = "KabacaQuestionBot/0.1 (https://github.com/YerdemA/aralik)"
DEFAULT = ["cities_tr_elevation", "capitals_elevation"]
FIELD = re.compile(r"^\s*\|\s*(?:rakım_m|rakım|yükselti|yükseklik_m)\s*=\s*([0-9][0-9.,]*)", re.MULTILINE | re.IGNORECASE)


def metres(text: str) -> float | None:
    """'1.900' and '1900' are 1900; '513,5' is 513.5."""
    match = FIELD.search(text)
    if not match:
        return None
    raw = match.group(1).rstrip(".,")
    if re.fullmatch(r"\d{1,3}(\.\d{3})+", raw):
        raw = raw.replace(".", "")
    try:
        return float(raw.replace(",", "."))
    except ValueError:
        return None


def lead(title: str) -> str | None:
    url = API.format(title=urllib.parse.quote(title))
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    for attempt in range(3):
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                data = json.loads(response.read().decode("utf-8"))
            return data.get("parse", {}).get("wikitext", {}).get("*")
        except OSError:
            time.sleep(3 * (attempt + 1))
    return None


def main(argv: list[str]) -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    checked = json.loads(OUT.read_text(encoding="utf-8")) if OUT.exists() else {}
    for name in argv or DEFAULT:
        rows = json.loads((RAW / f"{name}.json").read_text(encoding="utf-8"))["rows"]
        titles = {r["qid"]: r["tr_title"] for r in rows if r.get("tr_title")}
        for qid, title in titles.items():
            if qid in checked:
                continue
            text = lead(title)
            checked[qid] = metres(text) if text else None
            print(f"  {qid} {title}: {checked[qid]}")
            time.sleep(0.3)
    OUT.write_text(json.dumps(dict(sorted(checked.items())), ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"Yazıldı: {OUT.relative_to(ROOT)} ({len(checked)} öğe)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
