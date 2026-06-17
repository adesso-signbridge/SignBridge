#!/usr/bin/env python3
"""Build ISL conversational corpus fixtures and Dart phrase maps.

Regenerates:
  - test/fixtures/isl_conversational_sets.txt
  - lib/services/translate/isl_spoken_corpus.dart

Source: 100 Hindi + 100 Tamil + 100 Malayalam conversational sets.
"""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FIXTURE_PATH = ROOT / "test/fixtures/isl_conversational_sets.txt"
DART_PATH = ROOT / "lib/services/translate/isl_spoken_corpus.dart"

HINDI_ENTRIES: list[tuple[str, str]] = [
    ('मुझे एक कप चाय चाहिए।', 'ME ONE CUP CHAI WANT.'),
    ('क्या आपके पास शाकाहारी खाना है?', '[y/n-q] VEGETARIAN FOOD HAVE YOU?'),
    ('खाना बहुत तीखा है।', 'FOOD SPICY VERY.'),
    ('कृपया बिल ले आइए।', 'BILL BRING PLEASE.'),
    ('मैंने आज दोपहर का खाना नहीं खाया।', 'TODAY LUNCH ME EAT NOT.'),
    ('पानी ठंडा है या गर्म?', 'WATER COLD HOT WHICH?'),
    ('मुझे समोसा पसंद है।', 'ME SAMOSA LIKE.'),
    ('रसोई में चीनी कहाँ है?', 'KITCHEN SUGAR WHERE?'),
    ('कल हम रेस्तरां जाएंगे।', 'TOMORROW WE RESTAURANT GO.'),
    ('खाना खराब हो गया है।', 'FOOD SPOILED.'),
    ('आपका नाम क्या है?', 'YOUR NAME WHAT?'),
    ('मेरा नाम राहुल है।', 'MY NAME FS-RAHUL.'),
    ('आपके कितने भाई-बहन हैं?', 'YOUR SIBLINGS HOW-MANY?'),
    ('मेरी माँ शिक्षिका हैं।', 'MY MOTHER TEACHER.'),
    ('यह मेरा छोटा भाई है।', 'THIS MY BROTHER SMALL.'),
    ('आप कहाँ रहते हैं?', 'YOU LIVE WHERE?'),
    ('मैं दिल्ली में रहता हूँ।', 'ME DELHI LIVE.'),
    ('क्या आप शादीशुदा हैं?', '[y/n-q] YOU MARRIED?'),
    ('आज मेरे दोस्त का जन्मदिन है।', 'TODAY MY FRIEND BIRTHDAY.'),
    ('मेरे पिता कल आए थे।', 'YESTERDAY MY FATHER ARRIVE.'),
    ('रेलवे स्टेशन कहाँ है?', 'RAILWAY STATION WHERE?'),
    ('दिल्ली की ट्रेन कब आएगी?', 'DELHI TRAIN ARRIVE WHEN?'),
    ('मुझे एक ऑटो चाहिए।', 'ME AUTO NEED.'),
    ('टिकट की कीमत कितनी है?', 'TICKET COST HOW-MUCH?'),
    ('बस छूट गई।', 'BUS MISSED.'),
    ('रास्ता बहुत खराब है।', 'ROAD BAD VERY.'),
    ('एयरपोर्ट यहाँ से दूर है।', 'AIRPORT HERE FROM DEEP/FAR.'),
    ('क्या यह बस मुंबई जाती है?', '[y/n-q] THIS BUS MUMBAI GO?'),
    ('मेरी कार खराब हो गई है।', 'MY CAR BROKEN.'),
    ('मुझे खिड़की वाली सीट चाहिए।', 'ME WINDOW SEAT WANT.'),
    ('मेरे पेट में दर्द है।', 'MY STOMACH HURT.'),
    ('डॉक्टर कब आएंगे?', 'DOCTOR ARRIVE WHEN?'),
    ('मुझे तेज़ बुखार है।', 'ME FEVER HIGH.'),
    ('अस्पताल कहाँ है?', 'HOSPITAL WHERE?'),
    ('दवा दिन में दो बार लेनी है।', 'MEDICINE DAY TWO TIMES TAKE.'),
    ('मुझे चक्कर आ रहे हैं।', 'ME DIZZY.'),
    ('एम्बुलेंस को बुलाओ!', 'AMBULANCE CALL QUICK!'),
    ('क्या मुझे चोट लगी है?', 'ME INJURY HAVE?'),
    ('मेरा पैर सूज गया है।', 'MY LEG SWELLING.'),
    ('मुझे खून की जांच करानी है।', 'ME BLOOD TEST NEED.'),
    ('मैनेजर कहाँ हैं?', 'MANAGER WHERE?'),
    ('कल मीटिंग सुबह १० बजे है।', "TOMORROW MEETING MORNING 10-O'CLOCK."),
    ('मुझे बहुत काम है।', 'ME WORK MUCH.'),
    ('कंप्यूटर काम नहीं कर रहा है।', 'COMPUTER WORK NOT.'),
    ('आज मेरी छुट्टी है।', 'TODAY MY HOLIDAY.'),
    ('कृपया इस पेपर पर हस्ताक्षर करें।', 'THIS PAPER SIGN PLEASE.'),
    ('इंटरव्यू अच्छा रहा।', 'INTERVIEW GOOD.'),
    ('मुझे ईमेल भेजें।', 'ME EMAIL SEND.'),
    ('ऑफिस शनिवार को बंद रहता है।', 'OFFICE SATURDAY CLOSED.'),
    ('मुझे सैलरी मिल गई।', 'ME SALARY RECEIVE.'),
    ('स्कूल कब खुलेगा?', 'SCHOOL OPEN WHEN?'),
    ('मेरी गणित की परीक्षा है।', 'MY MATH EXAM HAVE.'),
    ('गृहकार्य पूरा हो गया है।', 'HOMEWORK FINISH.'),
    ('शिक्षक आज अनुपस्थित हैं।', 'TEACHER TODAY ABSENT.'),
    ('किताब मेज पर है।', 'BOOK TABLE UP.'),
    ('मुझे एक पेन उधार चाहिए।', 'PEN ONE BORROW NEED.'),
    ('कॉलेज की फीस कितनी है?', 'COLLEGE FEES HOW-MUCH?'),
    ('मैं आईएसएल सीख रहा हूँ।', 'ME ISL LEARN.'),
    ('क्या आपके पास नोट्स हैं?', '[y/n-q] NOTES HAVE YOU?'),
    ('पास होने के लिए कितने अंक चाहिए?', 'PASS MARKS NEED HOW-MANY?'),
    ('इस शर्ट की कीमत क्या है?', 'THIS SHIRT PRICE WHAT?'),
    ('यह बहुत महंगा है।', 'THIS EXPENSIVE VERY.'),
    ('क्या इस पर कोई छूट है?', 'DISCOUNT HAVE?'),
    ('मुझे सब्जियां खरीदनी हैं।', 'ME VEGETABLES BUY NEED.'),
    ('दुकान बंद है।', 'SHOP CLOSED.'),
    ('मुझे रसीद चाहिए।', 'ME RECEIPT WANT.'),
    ('क्या आप ऑनलाइन पेमेंट लेते हैं?', '[y/n-q] ONLINE PAYMENT ACCEPT YOU?'),
    ('कपड़े की क्वालिटी अच्छी है।', 'CLOTH QUALITY GOOD.'),
    ('यह साइज बहुत छोटा है।', 'THIS SIZE SMALL TOO-MUCH.'),
    ('मुझे पैसे वापस चाहिए।', 'ME MONEY RETURN NEED.'),
    ('आज बहुत गर्मी है।', 'TODAY HOT VERY.'),
    ('बाहर बारिश हो रही है।', 'OUTSIDE RAIN HAPPENING.'),
    ('कल बहुत ठंड थी।', 'YESTERDAY COLD VERY.'),
    ('तेज हवा चल रही है।', 'WIND STRONG BLOWING.'),
    ('आसमान में बादल हैं।', 'SKY CLOUDS HAVE.'),
    ('छाता मत भूलना।', "UMBRELLA FORGET DON'T."),
    ('धूप बहुत तेज है।', 'SUNLIGHT STRONG.'),
    ('मौसम कल साफ रहेगा।', 'TOMORROW WEATHER CLEAR WILL-BE.'),
    ('नदी गहरी है।', 'RIVER DEEP.'),
    ('बाढ़ आ गई है।', 'FLOOD ARRIVE.'),
    ('चाबी कहाँ रखी है?', 'KEY WHERE?'),
    ('दरवाजा बंद करो।', 'DOOR CLOSE.'),
    ('लाइट चली गई है।', 'ELECTRICITY GONE.'),
    ('पंखा चालू करो।', 'FAN ON.'),
    ('नल से पानी टपक रहा है।', 'TAP WATER DRIPPING.'),
    ('झाड़ू कहाँ है?', 'BROOM WHERE?'),
    ('कपड़े सुखा दो।', 'CLOTHES DRY PUT.'),
    ('फोन की बैटरी खत्म हो गई है।', 'PHONE BATTERY DEAD.'),
    ('मुझे घर जाना है।', 'ME HOME GO NEED.'),
    ('कूड़ा बाहर फेंक दो।', 'GARBAGE OUTSIDE THROW.'),
    ('पास का बैंक कहाँ है?', 'NEAR BANK WHERE?'),
    ('मुझे पैसे निकालने हैं।', 'ME MONEY WITHDRAW NEED.'),
    ('एटीएम काम नहीं कर रहा है।', 'ATM WORK NOT.'),
    ('आधार कार्ड की फोटोकॉपी चाहिए।', 'AADHAAR CARD XEROX NEED.'),
    ('पुलिस स्टेशन कहाँ है?', 'POLICE STATION WHERE?'),
    ('मेरा बटुआ चोरी हो गया।', 'MY WALLET STOLEN.'),
    ('सरकारी दफ्तर आज बंद है।', 'GOVERNMENT OFFICE TODAY CLOSED.'),
    ('खाता खुलवाना है।', 'ACCOUNT OPEN NEED.'),
    ('साइन यहाँ करना है।', 'SIGN HERE DO.'),
    ('फॉर्म जमा कर दिया है।', 'FORM SUBMIT FINISH.'),
]

TAMIL_ENTRIES: list[tuple[str, str]] = [
    ('எனக்கு ஒரு கப் டீ வேண்டும்.', 'ME ONE CUP CHAI WANT.'),
    ('இங்கே சைவ உணவு இருக்கிறதா?', '[y/n-q] HERE VEGETARIAN FOOD HAVE?'),
    ('சாப்பாடு ரொம்ப காரமாக இருக்கிறது.', 'FOOD SPICY VERY.'),
    ('பில் கொண்டு வாருங்கள்.', 'BILL BRING PLEASE.'),
    ('நான் மதிய உணவு சாப்பிடவில்லை.', 'ME LUNCH EAT NOT.'),
    ('தண்ணீர் சுடுதண்ணீரா அல்லது குளிர்ந்த தண்ணீரா?', 'WATER HOT COLD WHICH?'),
    ('எனக்கு தோசை பிடிக்கும்.', 'ME DOSA LIKE.'),
    ('சர்க்கரை எங்கே இருக்கிறது?', 'SUGAR WHERE?'),
    ('நாளை நாம் ஹோட்டலுக்கு போவோம்.', 'TOMORROW WE RESTAURANT GO.'),
    ('சாப்பாடு கெட்டுப்போய்விட்டது.', 'FOOD SPOILED.'),
    ('உங்கள் பெயர் என்ன?', 'YOUR NAME WHAT?'),
    ('என் பெயர் ஆனந்த்.', 'MY NAME FS-ANAND.'),
    ('உங்களுக்கு எத்தனை சகோதரர்கள்?', 'YOUR BROTHERS HOW-MANY?'),
    ('என் அம்மா ஒரு ஆசிரியர்.', 'MY MOTHER TEACHER.'),
    ('இவன் என் தம்பி.', 'THIS MY BROTHER SMALL.'),
    ('நீங்கள் எங்கே வசிக்கிறீர்கள்?', 'YOU LIVE WHERE?'),
    ('நான் சென்னையில் வசிக்கிறேன்.', 'ME CHENNAI LIVE.'),
    ('உங்களுக்கு திருமணமாகிவிட்டதா?', '[y/n-q] YOU MARRIED?'),
    ('இன்று என் நண்பனின் பிறந்தநாள்.', 'TODAY MY FRIEND BIRTHDAY.'),
    ('என் அப்பா நேற்று வந்தார்.', 'YESTERDAY MY FATHER ARRIVE.'),
    ('ரயில் நிலையம் எங்கே இருக்கிறது?', 'RAILWAY STATION WHERE?'),
    ('சென்னை ரயில் எப்போது வரும்?', 'CHENNAI TRAIN ARRIVE WHEN?'),
    ('எனக்கு ஒரு ஆட்டோ வேண்டும்.', 'ME AUTO NEED.'),
    ('டிக்கெட் விலை எவ்வளவு?', 'TICKET COST HOW-MUCH?'),
    ('நான் பஸ்ஸை தவறவிட்டுவிட்டேன்.', 'ME BUS MISSED.'),
    ('ரோடு ரொம்ப மோசமாக இருக்கிறது.', 'ROAD BAD VERY.'),
    ('ஏர்போர்ட் தூரமாக இருக்கிறது.', 'AIRPORT FAR.'),
    ('இந்த பஸ் மதுரைக்கு போகுமா?', '[y/n-q] THIS BUS MADURAI GO?'),
    ('என் கார் பழுதாகிவிட்டது.', 'MY CAR BROKEN.'),
    ('எனக்கு ஜன்னல் சீட் வேண்டும்.', 'ME WINDOW SEAT WANT.'),
    ('எனக்கு வயிற்று வலி இருக்கிறது.', 'MY STOMACH HURT.'),
    ('டாக்டர் எப்போது வருவார்?', 'DOCTOR ARRIVE WHEN?'),
    ('எனக்கு கடுமையான காய்ச்சல் இருக்கிறது.', 'ME FEVER HIGH.'),
    ('மருத்துவமனை எங்கே இருக்கிறது?', 'HOSPITAL WHERE?'),
    ('இந்த மாத்திரையை ஒரு நாளைக்கு இரண்டு முறை சாப்பிட வேண்டும்.', 'MEDICINE DAY TWO TIMES TAKE.'),
    ('எனக்கு தலைச்சுற்றலாக இருக்கிறது.', 'ME DIZZY.'),
    ('ஆம்புலன்ஸை கூப்பிடுங்கள்!', 'AMBULANCE CALL QUICK!'),
    ('அடி பட்டுவிட்டதா?', 'INJURY HAVE?'),
    ('என் கால் வீங்கியிருக்கிறது.', 'MY LEG SWELLING.'),
    ('இரத்தப் பரிசோதனை செய்ய வேண்டும்.', 'ME BLOOD TEST NEED.'),
    ('மேலாளர் எங்கே?', 'MANAGER WHERE?'),
    ('நாளை காலை 10 மணிக்கு மீட்டிங் இருக்கிறது.', "TOMORROW MEETING MORNING 10-O'CLOCK."),
    ('எனக்கு வேலை அதிகமாக இருக்கிறது.', 'ME WORK MUCH.'),
    ('கம்ப்யூட்டர் வேலை செய்யவில்லை.', 'COMPUTER WORK NOT.'),
    ('இன்று எனக்கு லீவு.', 'TODAY MY HOLIDAY.'),
    ('இந்த பேப்பரில் கையெழுத்து போடுங்கள்.', 'THIS PAPER SIGN PLEASE.'),
    ('இன்டர்வியூ நன்றாக நடந்தது. /', 'INTERVIEW GOOD.'),
    ('எனக்கு மின்னஞ்சல் அனுப்புங்கள்.', 'ME EMAIL SEND.'),
    ('சனிக்கிழமை ஆபீஸ் லீவு.', 'OFFICE SATURDAY CLOSED.'),
    ('எனக்கு சம்பளம் வந்துவிட்டது.', 'ME SALARY RECEIVE.'),
    ('பள்ளி எப்போது திறக்கும்?', 'SCHOOL OPEN WHEN?'),
    ('எனக்கு கணித தேர்வு இருக்கிறது.', 'MY MATH EXAM HAVE.'),
    ('வீட்டுப்பாடம் முடிந்துவிட்டது.', 'HOMEWORK FINISH.'),
    ('இன்று ஆசிரியர் வரவில்லை.', 'TEACHER TODAY ABSENT.'),
    ('புத்தகம் மேஜை மேல் இருக்கிறது.', 'BOOK TABLE UP.'),
    ('ஒரு பேனா கடன் கொடுங்கள்.', 'PEN ONE BORROW NEED.'),
    ('கல்லூரி கட்டணம் எவ்வளவு?', 'COLLEGE FEES HOW-MUCH?'),
    ('நான் இந்திய சைகை மொழி படிக்கிறேன்.', 'ME ISL LEARN.'),
    ('உங்களிடம் குறிப்புகள் இருக்கிறதா?', '[y/n-q] NOTES HAVE YOU?'),
    ('பாஸ் மார்க் எவ்வளவு?', 'PASS MARKS NEED HOW-MANY?'),
    ('இந்த சட்டையின் விலை என்ன?', 'THIS SHIRT PRICE WHAT?'),
    ('இது விலை அதிகம்.', 'THIS EXPENSIVE VERY.'),
    ('தள்ளுபடி ஏதேனும் இருக்கிறதா?', 'DISCOUNT HAVE?'),
    ('நான் காய்கறிகள் வாங்க வேண்டும்.', 'ME VEGETABLES BUY NEED.'),
    ('கடை மூடியிருக்கிறது.', 'SHOP CLOSED.'),
    ('எனக்கு பற்றுச்சீட்டு வேண்டும்.', 'ME RECEIPT WANT.'),
    ('ஆன்லைன் பேமெண்ட் ஏற்குமா?', '[y/n-q] ONLINE PAYMENT ACCEPT YOU?'),
    ('துணி தரம் நன்றாக உள்ளது.', 'CLOTH QUALITY GOOD.'),
    ('இந்த அளவு சிறியதாக உள்ளது.', 'THIS SIZE SMALL TOO-MUCH.'),
    ('எனக்கு பணம் திரும்ப வேண்டும்.', 'ME MONEY RETURN NEED.'),
    ('இன்று வெயில் அதிகமாக உள்ளது.', 'TODAY HOT VERY.'),
    ('வெளியே மழை பெய்கிறது.', 'OUTSIDE RAIN HAPPENING.'),
    ('நேற்று குளிராக இருந்தது.', 'YESTERDAY COLD VERY.'),
    ('காற்று பலமாக வீசுகிறது.', 'WIND STRONG BLOWING.'),
    ('மேகமூட்டமாக உள்ளது.', 'SKY CLOUDS HAVE.'),
    ('குடையை மறந்துவிடாதீர்கள்.', "UMBRELLA FORGET DON'T."),
    ('வெயில் கொடுமையாக உள்ளது.', 'SUNLIGHT STRONG.'),
    ('நாளை வானிலை சீராக இருக்கும்.', 'TOMORROW WEATHER CLEAR WILL-BE.'),
    ('ஆறு ஆழமானது.', 'RIVER DEEP.'),
    ('வெள்ளம் வந்துவிட்டது.', 'FLOOD ARRIVE.'),
    ('சாவி எங்கே?', 'KEY WHERE?'),
    ('கதவை மூடு.', 'DOOR CLOSE.'),
    ('கரண்ட் போய்விட்டது.', 'ELECTRICITY GONE.'),
    ('ஃபேனை போடு.', 'FAN ON.'),
    ('குழாயில் தண்ணீர் ஒழுகுகிறது.', 'TAP WATER DRIPPING.'),
    ('துடைப்பம் எங்கே?', 'BROOM WHERE?'),
    ('துணிகளை காயப்போடு.', 'CLOTHES DRY PUT.'),
    ('போனில் சார்ஜ் இல்லை.', 'PHONE BATTERY DEAD.'),
    ('நான் வீட்டுக்கு போக வேண்டும்.', 'ME HOME GO NEED.'),
    ('குப்பையை வெளியே போடு.', 'GARBAGE OUTSIDE THROW.'),
    ('அருகில் வங்கி எங்கே உள்ளது?', 'NEAR BANK WHERE?'),
    ('நான் பணம் எடுக்க வேண்டும்.', 'ME MONEY WITHDRAW NEED.'),
    ('ஏடிஎம் வேலை செய்யவில்லை.', 'ATM WORK NOT.'),
    ('ஆதார் கார்டு ஜெராக்ஸ் வேண்டும்.', 'AADHAAR CARD XEROX NEED.'),
    ('காவல் நிலையம் எங்கே இருக்கிறது?', 'POLICE STATION WHERE?'),
    ('என் பர்ஸ் திருடப்பட்டுவிட்டது.', 'MY WALLET STOLEN.'),
    ('அரசு அலுவலகம் இன்று விடுமுறை.', 'GOVERNMENT OFFICE TODAY CLOSED.'),
    ('புதிய கணக்கு தொடங்க வேண்டும்.', 'ACCOUNT OPEN NEED.'),
    ('இங்கே கையெழுத்திட வேண்டும்.', 'SIGN HERE DO.'),
    ('படிவம் சமர்ப்பிக்கப்பட்டுவிட்டது.', 'FORM SUBMIT FINISH.'),
]

MALAYALAM_ENTRIES: list[tuple[str, str]] = [
    ('എനിക്ക് ഒരു കപ്പ് ചായ വേണം.', 'ME ONE CUP CHAI WANT.'),
    ('ഇവിടെ വെജിറ്റേറിയൻ ഭക്ഷണം ഉണ്ടോ?', '[y/n-q] HERE VEGETARIAN FOOD HAVE?'),
    ('ഭക്ഷണത്തിന് നല്ല എരിവുണ്ട്.', 'FOOD SPICY VERY.'),
    ('ബില്ല് കൊണ്ടുവരൂ.', 'BILL BRING PLEASE.'),
    ('ഞാൻ ഉച്ചഭക്ഷണം കഴിച്ചില്ല.', 'ME LUNCH EAT NOT.'),
    ('വെള്ളം ചൂടുള്ളതാണോ തണുത്തതാണോ?', 'WATER HOT COLD WHICH?'),
    ('എനിക്ക് ദോശ ഇഷ്ടമാണ്.', 'ME DOSA LIKE.'),
    ('പഞ്ചസാര എവിടെയാണ് ഇരിക്കുന്നത്?', 'SUGAR WHERE?'),
    ('നാളെ നമുക്ക് ഹോട്ടലിൽ പോകാം.', 'TOMORROW WE RESTAURANT GO.'),
    ('ഭക്ഷണം കേടായിപ്പോയി.', 'FOOD SPOILED.'),
    ('നിങ്ങളുടെ പേരെന്താണ്?', 'YOUR NAME WHAT?'),
    ('എന്റെ പേര് വിനു എന്നാണ്.', 'MY NAME FS-VINU.'),
    ('നിങ്ങൾക്ക് എത്ര സഹോദരങ്ങളുണ്ട്?', 'YOUR SIBLINGS HOW-MANY?'),
    ('എന്റെ അമ്മ അധ്യാപികയാണ്.', 'MY MOTHER TEACHER.'),
    ('ഇവൻ എന്റെ അനിയനാണ്.', 'THIS MY BROTHER SMALL.'),
    ('നിങ്ങൾ എവിടെയാണ് താമസിക്കുന്നത്?', 'YOU LIVE WHERE?'),
    ('ഞാൻ കൊച്ചിയിലാണ് താമസിക്കുന്നത്.', 'ME KOCHI LIVE.'),
    ('നിങ്ങൾ വിവാഹിതനാണോ?', '[y/n-q] YOU MARRIED?'),
    ('ഇന്ന് എന്റെ സുഹൃത്തിന്റെ ജന്മദിനമാണ്.', 'TODAY MY FRIEND BIRTHDAY.'),
    ('എന്റെ അച്ഛൻ ഇന്നലെ വന്നു.', 'YESTERDAY MY FATHER ARRIVE.'),
    ('റെയിൽവേ സ്റ്റേഷൻ എവിടെയാണ്?', 'RAILWAY STATION WHERE?'),
    ('കൊച്ചിയിലേക്കുള്ള ട്രെയിൻ എപ്പോഴാണ് വരുക?', 'KOCHI TRAIN ARRIVE WHEN?'),
    ('എനിക്ക് ഒരു ഓട്ടോ വേണം.', 'ME AUTO NEED.'),
    ('ടിക്കറ്റ് നിരക്ക് എത്രയാണ്?', 'TICKET COST HOW-MUCH?'),
    ('എനിക്ക് ബസ് നഷ്ടപ്പെട്ടു.', 'ME BUS MISSED.'),
    ('റോഡ് വളരെ മോശമാണ്.', 'ROAD BAD VERY.'),
    ('എയർപോർട്ട് ദൂരെയാണ്.', 'AIRPORT FAR.'),
    ('ഈ ബസ് തിരുവനന്തപുരത്തേക്ക് പോകുമോ?', '[y/n-q] THIS BUS TRIVANDRUM GO?'),
    ('എന്റെ കാർ കേടായി.', 'MY CAR BROKEN.'),
    ('എനിക്ക് വിൻഡോ സീറ്റ് വേണം.', 'ME WINDOW SEAT WANT.'),
    ('എനിക്ക് വയറുവേദനയുണ്ട്.', 'MY STOMACH HURT.'),
    ('ഡോക്ടർ എപ്പോൾ വരും?', 'DOCTOR ARRIVE WHEN?'),
    ('എനിക്ക് കടുത്ത പനിയുണ്ട്.', 'ME FEVER HIGH.'),
    ('ആശുപത്രി എവിടെയാണ്?', 'HOSPITAL WHERE?'),
    ('ഈ ഗുളിക ദിവസത്തിൽ രണ്ടുതവണ കഴിക്കണം.', 'MEDICINE DAY TWO TIMES TAKE.'),
    ('എനിക്ക് തലകറക്കം തോന്നുന്നു.', 'ME DIZZY.'),
    ('ആംബുലൻസ് വിളിക്കൂ!', 'AMBULANCE CALL QUICK!'),
    ('എനിക്ക് പരിക്കേറ്റിട്ടുണ്ടോ?', 'INJURY HAVE?'),
    ('എന്റെ കാലിൽ നീരുണ്ട്.', 'MY LEG SWELLING.'),
    ('രക്തപരിശോധന നടത്തണം.', 'ME BLOOD TEST NEED.'),
    ('മാനേജർ എവിടെ?', 'MANAGER WHERE?'),
    ('നാളെ രാവിലെ 10 മണിക്ക് മീറ്റിംഗ് ഉണ്ട്.', "TOMORROW MEETING MORNING 10-O'CLOCK."),
    ('എനിക്ക് ജോലി കൂടുതലുണ്ട്.', 'ME WORK MUCH.'),
    ('കമ്പ്യൂട്ടർ പ്രവർത്തിക്കുന്നില്ല.', 'COMPUTER WORK NOT.'),
    ('ഇന്ന് എനിക്ക് അവധിയാണ്.', 'TODAY MY HOLIDAY.'),
    ('ദയവായി ഈ പേപ്പറിൽ ഒപ്പിടൂ.', 'THIS PAPER SIGN PLEASE.'),
    ('ഇന്റർവ്യൂ നന്നായിരുന്നു.', 'INTERVIEW GOOD.'),
    ('എനിക്ക് ഇമെയിൽ അയക്കൂ.', 'ME EMAIL SEND.'),
    ('ശനിയാഴ്ച ഓഫീസ് അവധിയാണ്.', 'OFFICE SATURDAY CLOSED.'),
    ('എനിക്ക് ശമ്പളം കിട്ടി.', 'ME SALARY RECEIVE.'),
    ('സ്കൂൾ എന്ന് തുറക്കും?', 'SCHOOL OPEN WHEN?'),
    ('എനിക്ക് കണക്ക് പരീക്ഷയുണ്ട്.', 'MY MATH EXAM HAVE.'),
    ('ഹോംവർക്ക് തീർന്നു.', 'HOMEWORK FINISH.'),
    ('ഇന്ന് ടീച്ചർ വന്നിട്ടില്ല.', 'TEACHER TODAY ABSENT.'),
    ('പുസ്തകം മേശപ്പുറത്തുണ്ട്.', 'BOOK TABLE UP.'),
    ('എനിക്ക് ഒരു പേന കടം തരുമോ?', 'PEN ONE BORROW NEED.'),
    ('കോളേജ് ഫീസ് എത്രയാണ്?', 'COLLEGE FEES HOW-MUCH?'),
    ('ഞാൻ ഇന്ത്യൻ ആംഗ്യഭാഷ പഠിക്കുകയാണ്.', 'ME ISL LEARN.'),
    ('നിങ്ങളുടെ കൈയിൽ നോട്ട്സ് ഉണ്ടോ?', '[y/n-q] NOTES HAVE YOU?'),
    ('പാസ് മാർക്ക് എത്രയാണ്?', 'PASS MARKS NEED HOW-MANY?'),
    ('ഈ ഷർട്ടിന്റെ വില എത്രയാണ്?', 'THIS SHIRT PRICE WHAT?'),
    ('ഇതിന് വില കൂടുതലാണ്.', 'THIS EXPENSIVE VERY.'),
    ('ഡിസ്കൗണ്ട് വല്ലതുമുണ്ടോ?', 'DISCOUNT HAVE?'),
    ('എനിക്ക് പച്ചക്കറികൾ വാങ്ങണം.', 'ME VEGETABLES BUY NEED.'),
    ('കട അടച്ചിരിക്കുകയാണ്.', 'SHOP CLOSED.'),
    ('എനിക്ക് ബിൽ വേണം.', 'ME RECEIPT WANT.'),
    ('ഓൺലൈൻ പേയ്മെന്റ് സ്വീകരിക്കുമോ?', '[y/n-q] ONLINE PAYMENT ACCEPT YOU?'),
    ('തുണിയുടെ ക്വാളിറ്റി നല്ലതാണ്.', 'CLOTH QUALITY GOOD.'),
    ('ഈ സൈസ് വളരെ ചെറുതാണ്.', 'THIS SIZE SMALL TOO-MUCH.'),
    ('എനിക്ക് പണം തിരികെ വേണം.', 'ME MONEY RETURN NEED.'),
    ('ഇന്ന് നല്ല ചൂടാണ്.', 'TODAY HOT VERY.'),
    ('പുറത്ത് മഴ പെയ്യുന്നുണ്ട്.', 'OUTSIDE RAIN HAPPENING.'),
    ('ഇന്നലെ നല്ല തണുപ്പായിരുന്നു.', 'YESTERDAY COLD VERY.'),
    ('ശക്തമായ കാറ്റടിക്കുന്നുണ്ട്.', 'WIND STRONG BLOWING.'),
    ('ആകാശം മേഘാവൃതമാണ്.', 'SKY CLOUDS HAVE.'),
    ('കുട എടുക്കാൻ മറക്കരുത്.', "UMBRELLA FORGET DON'T."),
    ('വെയിൽ കഠിനമാണ്.', 'SUNLIGHT STRONG.'),
    ('നാളെ കാലാവസ്ഥ തെളിഞ്ഞതായിരിക്കും.', 'TOMORROW WEATHER CLEAR WILL-BE.'),
    ('പുഴയ്ക്ക് നല്ല ആഴമുണ്ട്.', 'RIVER DEEP.'),
    ('വെള്ളപ്പൊക്കം ഉണ്ടായിട്ടുണ്ട്.', 'FLOOD ARRIVE.'),
    ('താക്കോൽ എവിടെയാണ് വെച്ചിരിക്കുന്നത്?', 'KEY WHERE?'),
    ('വാതിൽ അടയ്ക്കൂ.', 'DOOR CLOSE.'),
    ('കറണ്ട് പോയി.', 'ELECTRICITY GONE.'),
    ('ഫാൻ ഓൺ ചെയ്യൂ.', 'FAN ON.'),
    ('ടാപ്പിൽ നിന്ന് വെള്ളം ഒലിക്കുന്നു.', 'TAP WATER DRIPPING.'),
    ('ചൂൽ എവിടെയാണ്?', 'BROOM WHERE?'),
    ('വസ്ത്രങ്ങൾ ഉണക്കാൻ ഇടൂ.', 'CLOTHES DRY PUT.'),
    ('ഫോണിൽ ചാർജ് തീർന്നു.', 'PHONE BATTERY DEAD.'),
    ('എനിക്ക് വീട്ടിൽ പോകണം.', 'ME HOME GO NEED.'),
    ('മാലിന്യം പുറത്ത് കളയൂ.', 'GARBAGE OUTSIDE THROW.'),
    ('അടുത്തുള്ള ബാങ്ക് എവിടെയാണ്?', 'NEAR BANK WHERE?'),
    ('എനിക്ക് പണം പിൻവലിക്കണം.', 'ME MONEY WITHDRAW NEED.'),
    ('എടിഎം വർക്ക് ചെയ്യുന്നില്ല.', 'ATM WORK NOT.'),
    ('ആധാർ കാർഡിന്റെ സിറോക്സ് വേണം.', 'AADHAAR CARD XEROX NEED.'),
    ('പോലീസ് സ്റ്റേഷൻ എവിടെയാണ്?', 'POLICE STATION WHERE?'),
    ('എന്റെ പഴ്സ് മോഷണം പോയി.', 'MY WALLET STOLEN.'),
    ('സർക്കാർ ഓഫീസ് ഇന്ന് അവധിയാണ്.', 'GOVERNMENT OFFICE TODAY CLOSED.'),
    ('അക്കൗണ്ട് തുടങ്ങണം.', 'ACCOUNT OPEN NEED.'),
    ('ഇവിടെ ഒപ്പിടണം.', 'SIGN HERE DO.'),
    ('ഫോം സമർപ്പിച്ചു കഴിഞ്ഞു.', 'FORM SUBMIT FINISH.'),
]

DATASETS: dict[str, tuple[str, list[tuple[str, str]]]] = {
    "HI": ("hindiPhrases", HINDI_ENTRIES),
    "TA": ("tamilPhrases", TAMIL_ENTRIES),
    "ML": ("malayalamPhrases", MALAYALAM_ENTRIES),
}


def normalize_gloss(raw: str) -> str:
    """Return space-separated gloss tokens without trailing sentence punctuation."""
    gloss = raw.strip()
    if gloss.endswith("."):
        gloss = gloss[:-1]
    return gloss.strip()


def gloss_to_english_intermediate(gloss: str) -> str:
    """Lowercase gloss tokens; strip yes/no question marker for grammar input."""
    cleaned = normalize_gloss(gloss)
    cleaned = re.sub(r"^\[y/n-q\]\s*", "", cleaned)
    tokens: list[str] = []
    for token in cleaned.split():
        token = token.rstrip("?!.")
        tokens.append(token.lower())
    return " ".join(tokens)


def dart_escape(value: str) -> str:
    return value.replace("\\", "\\\\").replace("'", "\\'")


def render_dart_map(name: str, entries: list[tuple[str, str]]) -> str:
    lines = [f"  static const {name} = {{"]
    for native, gloss in entries:
        english = gloss_to_english_intermediate(gloss)
        lines.append(
            f"    '{dart_escape(native)}': '{dart_escape(english)}',"
        )
    lines.append("  };")
    return "\n".join(lines)


def write_fixture() -> int:
    lines: list[str] = []
    for lang_code, (_, entries) in DATASETS.items():
        for native, gloss in entries:
            lines.append(f"{lang_code}|{native}|{normalize_gloss(gloss)}")
    FIXTURE_PATH.parent.mkdir(parents=True, exist_ok=True)
    FIXTURE_PATH.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return len(lines)


def write_dart() -> None:
    body = "\n\n".join(
        render_dart_map(dart_name, entries)
        for _, (dart_name, entries) in DATASETS.items()
    )
    content = f"""abstract final class IslSpokenCorpus {{
{body}
}}
"""
    DART_PATH.parent.mkdir(parents=True, exist_ok=True)
    DART_PATH.write_text(content, encoding="utf-8")


def main() -> None:
    total = sum(len(entries) for _, entries in DATASETS.values())
    if total != 300:
        raise SystemExit(f"Expected 300 entries, found {total}")

    count = write_fixture()
    write_dart()
    print(f"Wrote {count} fixture lines to {FIXTURE_PATH}")
    print(f"Wrote Dart corpus to {DART_PATH}")
    print(f"Confirmed {total} conversational entries (HI/TA/ML).")


if __name__ == "__main__":
    main()
