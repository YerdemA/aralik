"""Check tools/curated/selection.txt against Wikipedia and append it to the bank.

Usage:  python tools/import_curated.py [--dry-run] [--report PATH]

For each selected question the Wikipedia article is fetched and the answer
must appear in its text. The check only proves the number is in the article,
so --report writes the matching sentence of every question for a human read;
questions whose answer turned out wrong are fixed or removed in selection.txt.

Dropped automatically: article not found, answer not in the article, the same
Wikidata item already asked in the bank with that kind and unit, and repeats
of an article + kind + unit (validate_questions.py forbids them).

The bank stays append-only. Fetched articles are cached in tools/raw/wikipedia/
(git-ignored); only the numbers are used, no text is copied.
"""

from __future__ import annotations

import argparse
import json
import random
import re
import sys
import time
import urllib.parse
import urllib.request
from collections import Counter
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SELECTION = ROOT / "tools" / "curated" / "selection.txt"
BANK = ROOT / "assets" / "questions" / "questions.json"
CACHE = ROOT / "tools" / "raw" / "wikipedia"
USER_AGENT = "KabacaContentCheck/1.0 (https://github.com/YerdemA/aralik)"
LEAD_CHARS = 1500
SEED = 20261102


def parse_selection() -> list[dict]:
    rows: list[dict] = []
    dataset = category = None
    for line in SELECTION.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        if line.startswith("#"):
            header = re.fullmatch(r"#\s*(\w+)\|(\S+)", line)
            if header:
                dataset, category = header.groups()
            continue
        difficulty, answer, unit, article, text = line.split("|", 4)
        lang, title = article.split(":", 1)
        rows.append(
            {
                "text": text,
                "answer": float(answer) if "." in answer else int(answer),
                "unit": unit,
                "kind": "magnitude" if unit else "year",
                "category": category,
                "difficulty": int(difficulty),
                "dataset": dataset,
                "lang": lang,
                "title": title,
            }
        )
    return rows


def fetch(lang: str, title: str) -> dict | None:
    """{title, text, qid} of an article, following redirects; None if missing."""
    path = CACHE / lang / (re.sub(r'[\\/:*?"<>|]', "_", title) + ".json")
    if path.exists():
        return json.loads(path.read_text(encoding="utf-8")) or None
    query = urllib.parse.urlencode(
        {
            "action": "query",
            "format": "json",
            "prop": "extracts|pageprops",
            "explaintext": 1,
            "redirects": 1,
            "titles": title,
        }
    )
    request = urllib.request.Request(
        f"https://{lang}.wikipedia.org/w/api.php?{query}", headers={"User-Agent": USER_AGENT}
    )
    for attempt in range(4):
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                pages = json.load(response)["query"]["pages"]
            break
        except OSError:
            time.sleep(3 * (attempt + 1))
    else:
        sys.exit(f"HATA: indirilemedi: {lang}:{title}")
    page = next(iter(pages.values()))
    result = None
    if "missing" not in page and page.get("extract"):
        result = {
            "title": page["title"],
            "text": page["extract"],
            "qid": page.get("pageprops", {}).get("wikibase_item"),
        }
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(result or {}, ensure_ascii=False), encoding="utf-8")
    time.sleep(0.1)
    return result


def number_pattern(answer: int | float) -> re.Pattern:
    """The answer as written in an article: 1280, 1,280, 1.280, 1 280, 43,3."""
    whole, _, fraction = str(answer).partition(".")
    if len(whole) > 3:
        groups = re.findall(r"\d{1,3}(?=(?:\d{3})*$)", whole)
        whole = "(?:" + whole + "|" + r"[,.\s ]".join(groups) + ")"
    tail = rf"[.,]{fraction}" if fraction else r"(?![.,]?\d)"
    return re.compile(rf"(?<![\d.,]){whole}{tail}")


def find_evidence(text: str, answer: int | float) -> tuple[str, str] | None:
    """(where, sentence) of the first mention of the answer."""
    match = number_pattern(answer).search(text)
    if not match:
        return None
    start = max(text.rfind(". ", 0, match.start()) + 2, match.start() - 110)
    end = min(match.end() + 70, len(text))
    sentence = " ".join(text[start:end].split())
    return ("giriş" if match.start() < LEAD_CHARS else "gövde", sentence)


def source_url(lang: str, title: str) -> str:
    quoted = urllib.parse.quote(title.replace(" ", "_"), safe="_(),'!-.~")
    return f"https://{lang}.wikipedia.org/wiki/{quoted}"


def main(argv: list[str]) -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--dry-run", action="store_true", help="bankaya yazma")
    parser.add_argument("--report", type=Path, help="kanıt cümlelerini bu dosyaya yaz")
    args = parser.parse_args(argv)

    bank = json.loads(BANK.read_text(encoding="utf-8"))
    bank_keys = {(q["source"], q["kind"], q["unit"]) for q in bank}
    bank_texts = {" ".join(q["text"].casefold().split()) for q in bank}
    wikidata_keys = {
        (q["source"].rsplit("/", 1)[-1], q["kind"], q["unit"])
        for q in bank
        if "wikidata.org" in q["source"]
    }

    rows = parse_selection()
    dropped: list[str] = []
    accepted: list[dict] = []
    seen: set[tuple[str, str, str]] = set()
    report: list[str] = []
    for row in rows:
        page = fetch(row["lang"], row["title"])
        label = f"{row['text']} = {row['answer']} [{row['lang']}:{row['title']}]"
        if page is None:
            dropped.append(f"MADDE YOK: {label}")
            continue
        evidence = find_evidence(page["text"], row["answer"])
        if evidence is None:
            dropped.append(f"CEVAP YOK: {label}")
            continue
        if (page["qid"], row["kind"], row["unit"]) in wikidata_keys:
            dropped.append(f"BANKADA VAR ({page['qid']}): {label}")
            continue
        source = source_url(row["lang"], page["title"])
        key = (source, row["kind"], row["unit"])
        if key in seen:
            dropped.append(f"AYNI MADDE: {label}")
            continue
        seen.add(key)
        report.append(f"{evidence[0]}|{row['answer']}|{row['text']}|{evidence[1]}")
        if key in bank_keys:  # imported earlier
            continue
        if " ".join(row["text"].casefold().split()) in bank_texts:
            dropped.append(f"AYNI METİN: {label}")
            continue
        accepted.append(
            {
                "text": row["text"],
                "answer": row["answer"],
                "unit": row["unit"],
                "kind": row["kind"],
                "category": row["category"],
                "source": source,
                "data_year": date.today().year,
                "fun_fact": None,
                "difficulty": row["difficulty"],
                "dataset": row["dataset"],
            }
        )

    for line in dropped:
        print(f"  - {line}")
    print(f"{len(rows)} seçili, {len(accepted)} yeni, {len(dropped)} düşürüldü.")
    print("Yeni, kategori:", dict(Counter(q["category"] for q in accepted)))
    print("Yeni, zorluk:", dict(sorted(Counter(q["difficulty"] for q in accepted).items())))
    if args.report:
        args.report.write_text("\n".join(report) + "\n", encoding="utf-8")
    if args.dry_run or not accepted:
        return 0

    # Like build_questions.py: the order is no ranking.
    random.Random(f"{SEED}:{len(bank)}").shuffle(accepted)
    next_number = max(int(q["id"][1:]) for q in bank) + 1
    new = [{"id": f"q{next_number + i:04d}", **q} for i, q in enumerate(accepted)]
    BANK.write_text(json.dumps(bank + new, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"Yazıldı: {BANK.relative_to(ROOT)} ({len(bank)} + {len(new)} soru)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
