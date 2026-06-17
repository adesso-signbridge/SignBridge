#!/usr/bin/env python3
"""Regenerate assets/lexicon/english_dictionary.txt from the system word list."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "lexicon" / "english_dictionary.txt"
DICT_CANDIDATES = [
    Path("/usr/share/dict/words"),
    Path("/usr/dict/words"),
]


def main() -> None:
    dict_path = next((p for p in DICT_CANDIDATES if p.is_file()), None)
    if dict_path is None:
        raise SystemExit("No system dictionary found (install words package).")

    words: set[str] = set()
    with dict_path.open(encoding="utf-8", errors="ignore") as handle:
        for line in handle:
            raw = line.strip()
            if not raw:
                continue
            w = raw.lower().replace("'", "")
            if not w:
                continue
            if re.fullmatch(r"[a-z]+", w):
                words.add(w)
            elif re.fullmatch(r"[a-z]+(?:-[a-z]+)+", w):
                words.add(w)
                for part in w.split("-"):
                    if len(part) >= 2:
                        words.add(part)

    words.update(
        "a i am an as at be by do go he if in is it me my no of ok on or so to tv up us we".split()
    )

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text("\n".join(sorted(words)) + "\n", encoding="utf-8")
    print(f"Wrote {len(words)} words to {OUT}")


if __name__ == "__main__":
    main()
