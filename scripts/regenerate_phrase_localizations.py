#!/usr/bin/env python3
"""Generate lib/services/phrases/phrase_localizations.dart from phrase_catalog.dart."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "lib/services/phrases/phrase_catalog.dart"
OUT = ROOT / "lib/services/phrases/phrase_localizations.dart"

# id -> (ML, HI, TA)
TRANSLATIONS: dict[str, tuple[str, str, str]] = {
    "greet_hello": ("നമസ്കാരം", "नमस्ते", "வணக்கம்"),
    "greet_thanks": ("നന്ദി", "धन्यवाद", "நன்றி"),
    "greet_deaf_mute": (
        "ഞാൻ ബധിരനാണ് / മൂകനാണ്",
        "मैं बहरा / मूक हूँ",
        "நான் செவிடர் / ஊமை",
    ),
    "greet_write_down": (
        "ദയവായി എഴുതിക്കൊടുക്കുക",
        "कृपया लिखकर दें",
        "தயவுசெய்து எழுதிக் காட்டுங்கள்",
    ),
    "greet_nice_meet": (
        "നിങ്ങളെ കാണാനായി സന്തോഷം",
        "आपसे मिलकर खुशी हुई",
        "உங்களை சந்தித்ததில் மகிழ்ச்சி",
    ),
    "greet_goodbye": ("വിട", "अलविदा", "பிரியாவிடை"),
    "greet_morning": ("സുപ്രഭാതം", "सुप्रभात", "காலை வணக்கம்"),
    "greet_evening": ("ശുഭ സായാഹ്നം", "शुभ संध्या", "மாலை வணக்கம்"),
    "greet_how_are_you": ("സുഖമാണോ?", "आप कैसे हैं?", "எப்படி இருக்கிறீர்கள்?"),
    "greet_please_wait": (
        "ദയവായി കാത്തിരിക്കുക",
        "कृपया प्रतीक्षा करें",
        "தயவுசெய்து காத்திருங்கள்",
    ),
    "greet_excuse_me": ("ക്ഷമിക്കണം", "माफ़ कीजिए", "மன்னிக்கவும்"),
    "greet_sorry": ("ക്ഷമിക്കണം", "माफ़ करें", "மன்னிக்கவும்"),
    "greet_welcome": ("സ്വാഗതം", "आपका स्वागत है", "வரவேற்கிறோம்"),
    "greet_see_you": ("പിന്നീട് കാണാം", "फिर मिलेंगे", "பிறகு சந்திப்போம்"),
    "greet_my_name": ("എന്റെ പേര്", "मेरा नाम", "என் பெயர்"),
    "greet_dont_understand": (
        "എനിക്ക് മനസ്സിലാകുന്നില്ല",
        "मुझे समझ नहीं आया",
        "எனக்கு புரியவில்லை",
    ),
    "greet_repeat": (
        "ദയവായി വീണ്ടും പറയുക",
        "कृपया दोहराएँ",
        "தயவுசெய்து மீண்டும் சொல்லுங்கள்",
    ),
    "greet_slowly": (
        "ദയവായി slowly പറയുക",
        "कृपया धीरे बोलें",
        "தயவுசெய்து மெதுவாகச் சொல்லுங்கள்",
    ),
    "greet_yes": ("അതെ", "हाँ", "ஆம்"),
    "greet_no": ("അല്ല", "नहीं", "இல்லை"),
    "med_doctor": ("എനിക്ക് ഒരു ഡോക്ടർ വേണം", "मुझे डॉक्टर चाहिए", "எனக்கு மருத்துவர் தேவை"),
    "med_allergy": ("എനിക്ക് അലർജി ഉണ്ട്", "मुझे एलर्जी है", "எனக்கு allergy உள்ளது"),
    "med_ambulance": ("ആംബുലൻസ് വിളിക്കുക", "एम्बुलेंस बुलाएँ", "ஆம்புலன்ஸ் அழைக்கவும்"),
    "med_medication": ("ഞാൻ മരുന്ന് കഴിക്കുന്നു", "मैं दवा लेता हूँ", "நான் மருந்து சாப்பிடுகிறேன்"),
    "med_hospital": ("ആശുപത്രി എവിടെയാണ്?", "अस्पताल कहाँ है?", "மருத்துவமனை எங்கே?"),
    "med_pain": ("എനിക്ക് ഇവിടെ വേദനയുണ്ട്", "मुझे यहाँ दर्द है", "எனக்கு இங்கே வலி"),
    "med_sick": ("എനിക്ക് അസുഖമാണ്", "मैं बीमार हूँ", "நான் உடம்பு சரியில்லை"),
    "med_help": ("എനിക്ക് സഹായം വേണം", "मुझे मदद चाहिए", "எனக்கு உதவி தேவை"),
    "med_fever": ("എനിക്ക് പനിയുണ്ട്", "मुझे बुखार है", "எனக்கு காய்ச்சல்"),
    "med_dizzy": ("എനിക്ക് തലകറക്കമുണ്ട്", "मुझे चक्कर आ रहा है", "எனக்கு தலைச்சுற்றல்"),
    "med_diabetic": ("ഞാൻ പ്രമേഹ രോഗിയാണ്", "मैं मधुमेही हूँ", "நான் நீரிழிவு நோயாளி"),
    "med_pregnant": ("ഞാൻ ഗർഭിണിയാണ്", "मैं गर्भवती हूँ", "நான் கர்ப்பமாக இருக்கிறேன்"),
    "med_blood_type": ("എന്റെ രക്തഗ്രൂപ്പ്", "मेरा रक्त समूह", "என் இரத்த வகை"),
    "med_pharmacy": ("എനിക്ക് ഫാർമസി വേണം", "मुझे फार्मेसी चाहिए", "எனக்கு மருந்தகம் தேவை"),
    "med_chest_pain": ("എനിക്ക് നെഞ്ചുവേദനയുണ്ട്", "मुझे सीने में दर्द है", "எனக்கு மார்பு வலி"),
    "med_breathe": ("എനിക്ക് ശ്വാസം കിട്ടുന്നില്ല", "मुझे साँस नहीं आ रही", "எனக்கு மூச்சு வரவில்லை"),
    "med_accident": ("എനിക്ക് അപകടം സംഭവിച്ചു", "मेरा accident हुआ", "எனக்கு விபத்து நேர்ந்தது"),
    "med_wheelchair": ("എനിക്ക് wheelchair വേണം", "मुझे wheelchair चाहिए", "எனக்கு wheelchair தேவை"),
    "med_allergic_to": ("എനിക്ക് അലർജിയുണ്ട്", "मुझे allergy है", "எனக்கு allergy உள்ளது"),
    "med_emergency": (
        "ഇത് ഒരു medical emergency ആണ്",
        "यह medical emergency है",
        "இது medical emergency",
    ),
    "trans_bus_stop": (
        "ബസ് സ്റ്റോപ്പ് എവിടെയാണ്?",
        "बस स्टॉप कहाँ है?",
        "பஸ் நிறுத்தம் எங்கே?",
    ),
    "trans_address": (
        "ഈ വിലാസത്തിലേക്ക് കൊണ്ടുപോകുക",
        "मुझे इस पते पर ले चलें",
        "இந்த முகவரிக்கு கொண்டு செல்லுங்கள்",
    ),
    "trans_ticket": ("ടിക്കറ്റ് എത്ര?", "टिकट कितने का है?", "டிக்கெட் எவ்வளவு?"),
    "trans_exit": (
        "പുറത്തേക്കുള്ള വഴി എവിടെ?",
        "बाहर निकलने का रास्ता कहाँ है?",
        "வெளியேறும் வழி எங்கே?",
    ),
    "trans_taxi": ("എനിക്ക് ടാക്സി വേണം", "मुझे taxi चाहिए", "எனக்கு taxi தேவை"),
    "trans_train": (
        "ട്രെയിൻ സ്റ്റേഷൻ എവിടെയാണ്?",
        "रेलवे स्टेशन कहाँ है?",
        "ரயில் நிலையம் எங்கே?",
    ),
    "trans_airport": (
        "എയർപോർട്ട് എവിടെയാണ്?",
        "एयरपोर्ट कहाँ है?",
        "விமான நிலையம் எங்கே?",
    ),
    "trans_platform": ("ഏത് platform?", "कौन सा platform?", "எந்த platform?"),
    "trans_one_ticket": (
        "ഒരു ടിക്കറ്റ് തരൂ",
        "एक टिकट दीजिए",
        "ஒரு டிக்கெட் தாருங்கள்",
    ),
    "trans_missed_bus": (
        "എന്റെ ബസ് നഷ്ടപ്പെട്ടു",
        "मेरी बस छूट गई",
        "என் பஸ் தவறிவிட்டது",
    ),
    "trans_right_bus": (
        "ഇതാണോ ശരിയായ ബസ്?",
        "क्या यह सही बस है?",
        "இதுதான் சரியான பஸா?",
    ),
    "trans_stop_here": ("ഇവിടെ നിർത്തൂ", "यहाँ रोक दीजिए", "இங்கே நிறுத்துங்கள்"),
    "trans_how_long": (
        "എത്ര സമയം എടുക്കും?",
        "कितना समय लगेगा?",
        "எவ்வளவு நேரம் ஆகும்?",
    ),
    "trans_directions": (
        "എനിക്ക് directions വേണം",
        "मुझे रास्ता बताइए",
        "எனக்கு வழி தேவை",
    ),
    "trans_parking": ("പാർക്കിംഗ് എവിടെയാണ്?", "पार्किंग कहाँ है?", "பார்க்கிங் எங்கே?"),
    "trans_turn_left": ("ഇടത്തോട്ട് തിരിയുക", "बाएँ मुड़ें", "இடதுபுறம் திரும்புங்கள்"),
    "trans_turn_right": ("വലത്തോട്ട് തിരിയുക", "दाएँ मुड़ें", "வலதுபுறம் திரும்புங்கள்"),
    "trans_go_straight": ("നേരെ പോകുക", "सीधे जाएँ", "நேராகச் செல்லுங்கள்"),
    "trans_lost": ("ഞാൻ നഷ്ടപ്പെട്ടു", "मैं खो गया हूँ", "நான் வழி தவறினேன்"),
    "trans_call_cab": (
        "ദയവായി cab വിളിക്കുക",
        "कृपया cab बुलाएँ",
        "தயவுசெய்து cab அழைக்கவும்",
    ),
    "shop_cost": (
        "ഇതിന്റെ വില എത്ര?",
        "इसकी कीमत कितनी है?",
        "இதன் விலை எவ்வளவு?",
    ),
    "shop_this_one": ("എനിക്ക് ഇത് വേണം", "मुझे यह चाहिए", "எனக்கு இது வேண்டும்"),
    "shop_smaller": (
        "ചെറിയ size ഉണ്ടോ?",
        "छोटा size है?",
        "சிறிய size உள்ளதா?",
    ),
    "shop_card": (
        "card കൊണ്ട് pay ചെയ്യാമോ?",
        "card से pay कर सकता हूँ?",
        "card-ஆ pay செய்யலாமா?",
    ),
    "shop_cash": ("cash സ്വീകരിക്കുമോ?", "cash लेते हैं?", "cash ஏற்றுக்கொள்கிறீர்களா?"),
    "shop_looking": (
        "ഞാൻ просто നോക്കുകയാണ്",
        "मैं बस देख रहा हूँ",
        "நான் просто பார்க்கிறேன்",
    ),
    "shop_try_on": ("ഇത് try ചെയ്യാമോ?", "इसे try कर सकता हूँ?", "இதை try செய்யலாமா?"),
    "shop_fitting": ("fitting room എവിടെ?", "fitting room कहाँ है?", "fitting room எங்கே?"),
    "shop_receipt": ("എനിക്ക് receipt വേണം", "मुझे receipt चाहिए", "எனக்கு receipt வேண்டும்"),
    "shop_discount": ("discount ഉണ്ടോ?", "discount है?", "discount உள்ளதா?"),
    "shop_expensive": (
        "ഇത് വളരെ costly ആണ്",
        "यह बहुत महँगा है",
        "இது மிகவும் дорого",
    ),
    "shop_take_it": ("ഞാൻ ഇത് എടുക്കുന്നു", "मैं यह लेता हूँ", "நான் இதை எடுக்கிறேன்"),
    "shop_color": (
        "വേറെ color-ൽ ഉണ്ടോ?",
        "दूसरे color में है?",
        "வேறு color-ல் உள்ளதா?",
    ),
    "shop_stock": ("stock-ൽ ഉണ്ടോ?", "stock में है?", "stock-ல் உள்ளதா?"),
    "shop_cashier": ("cashier എവിടെ?", "cashier कहाँ है?", "cashier எங்கே?"),
    "shop_return": (
        "ഇത് return ചെയ്യാമോ?",
        "इसे return कर सकता हूँ?",
        "இதை return செய்யலாமா?",
    ),
    "shop_bag": ("എനിക്ക് bag വേണം", "मुझे bag चाहिए", "எனக்கு bag வேண்டும்"),
    "shop_two": ("രണ്ടിന് എത്ര?", "दो का कितना?", "இரண்டுக்கு எவ்வளவு?"),
    "shop_open": ("തുറന്നിട്ടുണ്ടോ?", "खुला है?", "திறந்திருக்கிறதா?"),
    "shop_closed": ("എപ്പോൾ close ചെയ്യും?", "कब बंद होता है?", "எப்போது close?"),
    "em_help": ("സഹായം!", "मदद!", "உதவி!"),
    "em_police": ("പോലീസ് വിളിക്കുക", "पुलिस बुलाएँ", "போலீஸை அழைக்கவும்"),
    "em_lost": ("ഞാൻ നഷ്ടപ്പെട്ടു", "मैं खो गया हूँ", "நான் வழி தவறினேன்"),
    "em_assistance": ("എനിക്ക് assistance വേണം", "मुझे सहायता चाहिए", "எனக்கு உதவி தேवை"),
    "em_fire": ("തീ!", "आग!", "தீ!"),
    "em_call_emergency": (
        "emergency services വിളിക്കുക",
        "emergency services को call करें",
        "emergency services-ஐ அழைக்கவும்",
    ),
    "em_help_now": (
        "എനിക്ക് ഇപ്പോൾ സഹായം വേണം",
        "मुझे अभी मदद चाहिए",
        "எனக்கு இப்போது உதவி தேவை",
    ),
    "em_hurt": (
        "ആരോ പരിക്കേറ്റു",
        "किसी को चोट लगी है",
        "யாரோ காயமடைந்துள்ளார்",
    ),
    "em_danger": ("അപായം!", "खतरा!", "ஆபத்து!"),
    "em_evacuate": (
        "ദയവായി evacuate ചെയ്യുക",
        "कृपया evacuate करें",
        "தயவுசெய்து evacuate செய்யுங்கள்",
    ),
    "em_cannot_hear": (
        "എനിക്ക് കേൾക്കാൻ കഴിയില്ല",
        "मैं सुन नहीं सकता",
        "எனக்கு கேட்க முடியாது",
    ),
    "em_cannot_speak": (
        "എനിക്ക് സംസാരിക്കാൻ കഴിയില്ല",
        "मैं बोल नहीं सकता",
        "எனக்கு பேச முடியாது",
    ),
    "em_med_emergency": ("medical emergency", "medical emergency", "medical emergency"),
    "em_stay": (
        "ദയവായി എന്നോട് കൂടെ നിൽക്കുക",
        "कृपया मेरे साथ रहें",
        "தயவுசெய்து என்னுடன் இருங்கள்",
    ),
    "em_where_am_i": ("ഞാൻ എവിടെയാണ്?", "मैं कहाँ हूँ?", "நான் எங்கே?"),
    "em_translator": (
        "എനിക്ക് translator വേണം",
        "मुझे translator चाहिए",
        "எனக்கு translator தேवை",
    ),
    "em_call_family": (
        "ദയവായി എന്റെ കുടുംബത്തെ വിളിക്കുക",
        "कृपया मेरे परिवार को call करें",
        "தயவுசெய்து என் குடும்பத்தை அழைக்கவும்",
    ),
    "em_in_danger": (
        "ഞാൻ അപായത്തിലാണ്",
        "मैं खतरे में हूँ",
        "நான் ஆபத்தில் இருக்கிறேன்",
    ),
    "em_help_please": (
        "ദയവായി എന്നെ സഹായിക്കുക",
        "कृपया मेरी मदद करें",
        "தயவுசெய்து எனக்கு உதவுங்கள்",
    ),
    "em_sos": ("SOS", "SOS", "SOS"),
}


def dart_string(value: str) -> str:
    return repr(value)


def parse_catalog() -> list[tuple[str, str]]:
    text = CATALOG.read_text(encoding="utf-8")
    items = re.findall(r"id: '([^']+)',\s*text: '([^']*)'", text)
    items += re.findall(r'id: \'([^\']+)\',\s*text: "([^"]*)"', text)
    dedup: dict[str, str] = {}
    for phrase_id, english in items:
        dedup[phrase_id] = english
    return sorted(dedup.items())


def main() -> None:
    lines = [
        "/// Localized phrase text for display and TTS.",
        "abstract final class PhraseLocalizations {",
        "  static const _byId = <String, Map<String, String>>{",
    ]

    for phrase_id, english in parse_catalog():
        ml, hi, ta = TRANSLATIONS.get(phrase_id, (english, english, english))
        lines.extend(
            [
                f"    '{phrase_id}': {{",
                f"      'ENG': {dart_string(english)},",
                f"      'ML': {dart_string(ml)},",
                f"      'HI': {dart_string(hi)},",
                f"      'TA': {dart_string(ta)},",
                "    },",
            ]
        )

    lines.extend(
        [
            "  };",
            "",
            "  static String text(",
            "    String phraseId,",
            "    String languageCode, {",
            "    required String fallback,",
            "  }) {",
            "    final localized =",
            "        _byId[phraseId]?[languageCode.trim().toUpperCase()];",
            "    if (localized != null && localized.trim().isNotEmpty) {",
            "      return localized;",
            "    }",
            "    return fallback;",
            "  }",
            "}",
            "",
        ]
    )

    OUT.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {OUT}")


if __name__ == "__main__":
    main()
