#!/usr/bin/env python3
"""Build ASL sign lexicon from ASL-LEX 2.0 SignData (CC BY-NC 4.0).

Source: https://asl-lex.org/download.html
CSV: scripts/data/asl_lex_signdata.csv (from ASL-LEX/asl-lex GitHub)

Output: assets/lexicon/asl_sign_lexicon.txt
  Format per line: english_word|GLOSS|sign_id
"""

from __future__ import annotations

import csv
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CSV_PATH = ROOT / "scripts/data/asl_lex_signdata.csv"
OUT_PATH = ROOT / "assets/lexicon/asl_sign_lexicon.txt"


def normalize_word(word: str) -> str:
    return re.sub(r"[^a-z0-9'-]", "", word.strip().lower())


def normalize_id(value: str) -> str:
    cleaned = re.sub(r"[^a-zA-Z0-9]+", "_", value.strip().lower())
    return cleaned.strip("_")


def main() -> None:
    if not CSV_PATH.is_file():
        raise SystemExit(f"Missing source CSV: {CSV_PATH}")

    best: dict[str, tuple[str, str, float]] = {}

    with CSV_PATH.open(newline="", encoding="latin-1") as handle:
        reader = csv.DictReader(handle)
        for row in reader:
            try:
                frequency = float(row.get("SignFrequency(M)") or 0)
            except ValueError:
                frequency = 0.0

            lemma = (row.get("LemmaID") or "").strip().lower()
            entry = (row.get("EntryID") or "").strip().lower()
            bank = (row.get("SignBankLemmaID") or "").strip()
            dominant = (row.get("DominantTranslation") or "").strip().lower()
            translations = (row.get("SignBankEnglishTranslations") or "").strip()

            gloss = (
                bank.upper().replace(" ", "_")
                if bank
                else lemma.upper().replace(" ", "_")
            )
            sign_id = normalize_id(lemma or entry)

            sources: list[str] = []
            if lemma:
                sources.append(lemma)
            if entry and entry != lemma:
                sources.append(entry)
            if dominant:
                sources.append(dominant)
            if translations:
                sources.extend(part.strip().lower() for part in translations.split(","))

            for raw in sources:
                word = normalize_word(raw)
                if len(word) < 2:
                    continue
                prev = best.get(word)
                if prev is None or frequency > prev[2]:
                    best[word] = (gloss, sign_id, frequency)

    lines = [
        f"{word}|{gloss}|{sign_id}"
        for word, (gloss, sign_id, _) in sorted(best.items())
    ]
    OUT_PATH.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Wrote {len(lines)} ASL sign entries to {OUT_PATH}")


if __name__ == "__main__":
    main()
