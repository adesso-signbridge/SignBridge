#!/usr/bin/env python3
"""Build ISL master vocabulary from ASL master list + HI/TA/ML translations."""

from __future__ import annotations

import csv
import json
import re
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ASL_CSV = ROOT / "scripts/data/asl_master_vocabulary.csv"
CACHE_JSON = ROOT / "scripts/data/isl_vocabulary_translations_cache.json"
OUT_CSV = ROOT / "scripts/data/isl_master_vocabulary.csv"
OUT_TXT = ROOT / "scripts/data/isl_master_vocabulary.txt"
MANIFEST = ROOT / "assets/signs/manifest.json"

# Curated overrides for natural phrasing (english key -> hi, ta, ml).
OVERRIDES: dict[str, tuple[str, str, str]] = {
    "how are you?": ("आप कैसे हैं?", "நீங்கள் எப்படி இருக்கிறீர்கள்?", "സുഖമാണോ?"),
    "how are you": ("आप कैसे हैं?", "நீங்கள் எப்படி இருக்கிறீர்கள்?", "സുഖമാണോ?"),
    "thank you": ("धन्यवाद", "நன்றி", "നന്ദി"),
    "thanks a lot": ("बहुत धन्यवाद", "மிக்க நன்றி", "വളരെ നന്ദി"),
    "you're welcome": ("आपका स्वागत है", "வரவேற்கிறோம்", "സ്വാഗതം"),
    "excuse me": ("माफ़ कीजिए", "மன்னிக்கவும்", "ക്ഷമിക്കണം"),
    "nice to meet you": ("आपसे मिलकर खुशी हुई", "உங்களை சந்தித்ததில் மகிழ்ச்சி", "കണ്ടതിൽ സന്തോഷം"),
    "good morning": ("सुप्रभात", "காலை வணக்கம்", "സുപ്രഭാതം"),
    "good afternoon": ("नमस्कार", "மதிய வணக்கம்", "ഗുഡ് ആഫ്റ്റർനൂൺ"),
    "good evening": ("शुभ संध्या", "மாலை வணக்கம்", "ഗുഡ് ഈവനിംഗ്"),
    "see you later": ("फिर मिलेंगे", "பிறகு சந்திப்போம்", "പിന്നീട് കാണാം"),
    "see you tomorrow": ("कल मिलते हैं", "நாளை சந்திப்போம்", "നാളെ കാണാം"),
    "have a nice day": ("आपका दिन शुभ हो", "நல்ல நாள்", "ശുഭദിനം"),
    "take care": ("अपना ख्याल रखना", "பாதுகாப்பாக இருங்கள்", "ശ്രദ്ധിക്കുക"),
    "no problem": ("कोई बात नहीं", "பரவாயில்லை", "പ്രശ്നമില്ല"),
    "good luck": ("शुभकामनाएँ", "நல்வாழ்த்துகள்", "ആശംസകൾ"),
    "happy birthday": ("जन्मदिन मुबारक", "பிறந்தநாள் வாழ்த்துகள்", "ജന്മദിനാശംസകൾ"),
    "wake up": ("जागो", "எழுந்திரு", "ഉണരുക"),
    "how many": ("कितने", "எத்தனை", "എത്ര"),
    "how much": ("कितना", "எவ்வளவு", "എത്ര"),
    "how long": ("कितनी देर", "எவ்வளவு நேரம்", "എത്ര നേരം"),
    "how often": ("कितनी बार", "எவ்வளவு அடிக்கடி", "എത്ര തവണ"),
    "how far": ("कितनी दूर", "எவ்வளவு தூரம்", "എത്ര ദൂരം"),
    "how old": ("कितने साल का", "எத்தனை வயது", "എത്ര വയസ്സ്"),
    "what time": ("कितने बजे", "எத்தனை மணி", "എത്ര മണി"),
    "what kind": ("किस तरह का", "எந்த வகை", "എന്ത് തരം"),
    "for what": ("किस लिए", "எதற்காக", "എന്തിന്"),
    "since when": ("कब से", "எப்போதிருந்து", "എപ്പോൾ മുതൽ"),
    "until when": ("कब तक", "எப்போது வரை", "എപ്പോൾ വരെ"),
    "how come": ("कैसे", "எப்படி", "എങ്ങനെ"),
    "credit card": ("क्रेडिट कार्ड", "கிரெடிட் கார்டு", "ക്രെഡിറ്റ് കാർഡ്"),
    "debit card": ("डेबिट कार्ड", "டெபிட் கார்டு", "ഡെബിറ്റ് കാർഡ്"),
    "post office": ("डाकघर", "தபால் நிலையம்", "തപാൽ കാര്യാലയം"),
    "train station": ("रेलवे स्टेशन", "ரயில் நிலையம்", "റെയിൽവേ സ്റ്റേഷൻ"),
    "bus station": ("बस स्टेशन", "பேருந்து நிலையம்", "ബസ് സ്റ്റേഷൻ"),
    "police station": ("पुलिस स्टेशन", "காவல் நிலையம்", "പോലീസ് സ്റ്റേഷൻ"),
    "shopping mall": ("शॉपिंग मॉल", "ஷாப்பிங் மால்", "ഷോപ്പിംഗ് മാൾ"),
    "ice cream": ("आइसक्रीम", "ஐஸ்கிரீம்", "ഐസ്ക്രീം"),
    "good to see you": ("आपको देखकर अच्छा लगा", "உங்களை பார்த்ததில் மகிழ்ச்சி", "കണ്ടതിൽ സന്തോഷം"),
    "pardon me": ("क्षमा करें", "மன்னிக்கவும்", "ക്ഷമിക്കണം"),
    "safe trip": ("सुरक्षित यात्रा", "பாதுகாப்பான பயணம்", "സുരക്ഷിതമായ യാത്ര"),
    "bless you": ("भगवान आपका भला करे", "ஆசீர்வாதம்", "ആശീർവാദം"),
    "best friend": ("सबसे अच्छा दोस्त", "சிறந்த நண்பர்", "ഏറ്റവും നല്ല സുഹൃത്ത്"),
    "try on": ("पहनकर देखना", "போட்டுப் பார்", "അണിഞ്ഞ് നോക്കുക"),
    "traffic light": ("ट्रैफिक लाइट", "போக்குவரத்து விளக்கு", "ട്രാഫിക് ലൈറ്റ്"),
    "emergency exit": ("आपातकालीन निकास", "அவசர வெளியேற்றம்", "അടിയന്തര പുറപ്പെടൽ"),
    "emergency number": ("आपातकालीन नंबर", "அவசர எண்", "അടിയന്തര നമ്പർ"),
    "first aid": ("प्राथमिक चिकित्सा", "முதல் உதவி", "ആദ്യചികിത്സ"),
    "social media": ("सोशल मीडिया", "சமூக ஊடகம்", "സോഷ്യൽ മീഡിയ"),
    "video call": ("वीडियो कॉल", "வீடியோ அழைப்பு", "വീഡിയോ കോൾ"),
    "government office": ("सरकारी दफ्तर", "அரசு அலுவலகம்", "സർക്കാർ ഓഫീസ്"),
}


def norm_key(english: str) -> str:
    return english.strip().lower().rstrip("?")


def load_cache() -> dict[str, dict[str, str]]:
    if CACHE_JSON.exists():
        return json.loads(CACHE_JSON.read_text(encoding="utf-8"))
    return {}


def save_cache(cache: dict[str, dict[str, str]]) -> None:
    CACHE_JSON.write_text(
        json.dumps(cache, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def translate_batch(missing: list[str]) -> dict[str, dict[str, str]]:
    from deep_translator import GoogleTranslator

    out: dict[str, dict[str, str]] = {}
    translators = {
        "hindi": GoogleTranslator(source="en", target="hi"),
        "tamil": GoogleTranslator(source="en", target="ta"),
        "malayalam": GoogleTranslator(source="en", target="ml"),
    }
    for index, english in enumerate(missing, start=1):
        key = norm_key(english)
        if key in OVERRIDES:
            hi, ta, ml = OVERRIDES[key]
            out[key] = {"hindi": hi, "tamil": ta, "malayalam": ml}
            continue
        try:
            out[key] = {
                lang: translators[lang].translate(english)
                for lang in translators
            }
        except Exception as error:  # noqa: BLE001
            print(f"[warn] translate failed for '{english}': {error}")
            out[key] = {"hindi": english, "tamil": english, "malayalam": english}
        if index % 25 == 0:
            print(f"  translated {index}/{len(missing)}")
            time.sleep(0.5)
        else:
            time.sleep(0.12)
    return out


def has_isl_video(english: str, isl_entries: set[str], aliases: dict[str, str]) -> bool:
    key = re.sub(r"[^a-z0-9]+", "_", norm_key(english)).strip("_")
    if key in isl_entries:
        return True
    if key in aliases and aliases[key] in isl_entries:
        return True
    return False


def main() -> None:
    if not ASL_CSV.exists():
        raise SystemExit(f"Missing {ASL_CSV}")

    manifest = json.loads(MANIFEST.read_text(encoding="utf-8")) if MANIFEST.exists() else {}
    isl_entries = set(manifest.get("isl", {}))
    aliases = manifest.get("aliases", {}).get("isl", {})

    asl_rows = list(csv.DictReader(ASL_CSV.open(encoding="utf-8")))
    cache = load_cache()
    missing = [
        norm_key(row["english"])
        for row in asl_rows
        if norm_key(row["english"]) not in cache and norm_key(row["english"]) not in OVERRIDES
    ]
    if missing:
        print(f"Translating {len(missing)} new entries...")
        cache.update(translate_batch(missing))
        save_cache(cache)

    out_rows = []
    for row in asl_rows:
        key = norm_key(row["english"])
        if key in OVERRIDES:
            hi, ta, ml = OVERRIDES[key]
        else:
            tr = cache.get(key, {})
            hi = tr.get("hindi", row["english"])
            ta = tr.get("tamil", row["english"])
            ml = tr.get("malayalam", row["english"])
        out_rows.append(
            {
                "sno": row["sno"],
                "category": row["category"],
                "english": row["english"],
                "hindi": hi,
                "tamil": ta,
                "malayalam": ml,
                "isl_gloss": row["asl_gloss"],
                "meaning": row["meaning"],
                "has_local_video": "yes"
                if has_isl_video(row["english"], isl_entries, aliases)
                else "no",
            }
        )

    OUT_CSV.parent.mkdir(parents=True, exist_ok=True)
    fields = [
        "sno",
        "category",
        "english",
        "hindi",
        "tamil",
        "malayalam",
        "isl_gloss",
        "meaning",
        "has_local_video",
    ]
    with OUT_CSV.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        writer.writerows(out_rows)

    have = sum(1 for row in out_rows if row["has_local_video"] == "yes")
    with OUT_TXT.open("w", encoding="utf-8") as handle:
        handle.write("ISL Master Vocabulary — Sign Bridge Curriculum\n")
        handle.write("Languages: English · Hindi · Tamil · Malayalam\n")
        handle.write("=" * 100 + "\n\n")
        handle.write(f"Total entries: {len(out_rows)}\n")
        handle.write(f"Local ISL video available: {have}\n")
        handle.write(f"Video still needed: {len(out_rows) - have}\n\n")
        current = None
        for row in out_rows:
            if row["category"] != current:
                current = row["category"]
                handle.write(f"\n## {current}\n")
                handle.write(
                    f'{"#":<4}{"English":<22}{"Hindi":<18}{"Tamil":<18}{"Malayalam":<18}{"ISL":<14}Vid\n'
                )
                handle.write("-" * 100 + "\n")
            vid = "Y" if row["has_local_video"] == "yes" else "-"
            handle.write(
                f'{row["sno"]:<4}{row["english"]:<22}{row["hindi"]:<18}{row["tamil"]:<18}'
                f'{row["malayalam"]:<18}{row["isl_gloss"]:<14}{vid}\n'
            )

    print(f"Wrote {len(out_rows)} entries to {OUT_CSV}")
    print(f"Wrote {OUT_TXT}")
    print(f"ISL videos: {have}/{len(out_rows)}")


if __name__ == "__main__":
    main()
