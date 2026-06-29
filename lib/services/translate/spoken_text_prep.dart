/// Prepares speech-to-text captions for gloss mapping (Tier 1 / Tier 2 flow).
library;

import 'isl_spoken_corpus.dart';
import 'isl_hindi_lexicon.dart';

abstract final class SpokenTextPrep {
  /// Maps Hindi / Tamil / Malayalam tokens to English grammar words for ISL rules.
  static String normalizeForGloss(String transcript, String languageCode) {
    if (transcript.trim().isEmpty) {
      return transcript;
    }

    final corpus = switch (languageCode) {
      'HI' => IslSpokenCorpus.hindiPhrases,
      'TA' => IslSpokenCorpus.tamilPhrases,
      'ML' => IslSpokenCorpus.malayalamPhrases,
      _ => null,
    };
    if (corpus != null) {
      final trimmed = transcript.trim();
      if (corpus.containsKey(trimmed)) {
        return corpus[trimmed]!;
      }
      final normalized = _normalizeNative(trimmed);
      for (final entry in corpus.entries) {
        if (_normalizeNative(entry.key) == normalized) {
          return entry.value;
        }
      }
    }

    final map = switch (languageCode) {
      'HI' => _hindiGrammarTokens,
      'TA' => _tamilGrammarTokens,
      'ML' => _malayalamGrammarTokens,
      _ => null,
    };
    if (map == null) {
      return transcript;
    }

    final out = <String>[];
    for (final raw in transcript.split(RegExp(r'\s+'))) {
      if (raw.isEmpty) {
        continue;
      }
      final stripped = raw.replaceAll(
        RegExp(r"^[\p{P}\p{S}']+|[\p{P}\p{S}']+$", unicode: true),
        '',
      );
      if (stripped.isEmpty) {
        continue;
      }
      final mapped = map[stripped] ?? map[stripped.toLowerCase()];
      if (mapped == null) {
        if (languageCode == 'HI') {
          final hindiEnglish = IslHindiLexicon.englishFor(stripped);
          if (hindiEnglish != null && hindiEnglish.isNotEmpty) {
            out.add(hindiEnglish);
            continue;
          }
        }
        out.add(raw);
      } else if (mapped.isNotEmpty) {
        out.add(mapped);
      }
    }
    return out.join(' ');
  }

  static String _normalizeNative(String text) {
    return text
        .trim()
        .replaceAll(RegExp(r'[\s]+'), ' ')
        .replaceAll(RegExp(r'[.!?।,;:]+$'), '');
  }

  /// WH questions when STT omits `?` (तुमारा नाम क्या है / tumara nam kya hai).
  static bool inferWhQuestion(String clause) {
    final trimmed = clause.trim();
    if (trimmed.isEmpty || trimmed.endsWith('?')) {
      return false;
    }
    final lower = trimmed
        .toLowerCase()
        .replaceAll(RegExp(r"[\p{P}\p{S}']", unicode: true), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    const whFragments = [
      'kya hai',
      'kya ho',
      'kya hain',
      'kab hai',
      'kahan hai',
      'kaha hai',
      'kaun hai',
      'kitna hai',
      'kitni hai',
      'क्या है',
      'कहाँ है',
      'कहां है',
      'कब है',
    ];
    for (final fragment in whFragments) {
      if (lower.contains(fragment)) {
        return true;
      }
    }
    return false;
  }

  /// Y/N when STT omits trailing `?` (Are you… / Do you… / क्या आप…).
  static bool inferYesNoQuestion(String clause) {
    final trimmed = clause.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    if (trimmed.endsWith('?')) {
      return true;
    }

    final lower = trimmed
        .toLowerCase()
        .replaceAll(RegExp(r"[\p{P}\p{S}']", unicode: true), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    for (final pattern in _yesNoLeadPatterns) {
      if (pattern.hasMatch(lower)) {
        return true;
      }
    }

    for (final prefix in _yesNoHindiPrefixes) {
      if (trimmed.startsWith(prefix)) {
        return true;
      }
    }

    for (final suffix in _yesNoTamilSuffixes) {
      if (trimmed.contains(suffix)) {
        return true;
      }
    }

    for (final suffix in _yesNoMalayalamSuffixes) {
      if (trimmed.contains(suffix)) {
        return true;
      }
    }

    return false;
  }

  static const _yesNoTamilSuffixes = ['இருக்கிறதா', 'போகுமா', 'ஏற்குமா', 'விட்டதா'];
  static const _yesNoMalayalamSuffixes = ['ഉണ്ടോ', 'പോകുമോ', 'സ്വീകരിക്കുമോ', 'എട്ടിട്ടുണ്ടോ'];

  static final _yesNoLeadPatterns = [
    RegExp(r'^are you\b'),
    RegExp(r'^are we\b'),
    RegExp(r'^are they\b'),
    RegExp(r'^is (he|she|it|this|that|there)\b'),
    RegExp(r'^is your\b'),
    RegExp(r'^do you\b'),
    RegExp(r'^do we\b'),
    RegExp(r'^do they\b'),
    RegExp(r'^does (he|she|it)\b'),
    RegExp(r'^can you\b'),
    RegExp(r'^can we\b'),
    RegExp(r'^could you\b'),
    RegExp(r'^will you\b'),
    RegExp(r'^will we\b'),
    RegExp(r'^would you\b'),
    RegExp(r'^have you\b'),
    RegExp(r'^have we\b'),
    RegExp(r'^has (he|she|it)\b'),
    RegExp(r'^did you\b'),
    RegExp(r'^did we\b'),
    RegExp(r'^was (he|she|it|that)\b'),
    RegExp(r'^were you\b'),
    RegExp(r'^were we\b'),
    RegExp(r'^am i\b'),
  ];

  static const _yesNoHindiPrefixes = ['क्या', 'क्या आप', 'क्या तुम'];

  static const _hindiGrammarTokens = {
    'मैं': 'I',
    'मेरा': 'my',
    'मेरी': 'my',
    'मेरे': 'my',
    'मुझे': 'me',
    'आप': 'you',
    'आपका': 'your',
    'आपकी': 'your',
    'आपके': 'your',
    'तुम': 'you',
    'तुम्हारा': 'your',
    'तुम्हारी': 'your',
    'तुम्हारे': 'your',
    'नाम': 'name',
    'हम': 'we',
    'हमारा': 'our',
    'वे': 'they',
    'वह': 'he',
    'उस': 'he',
    'इस': 'this',
    'नहीं': 'not',
    'नमस्ते': 'hello',
    'कैसे': 'how',
    'कहाँ': 'where',
    'कहां': 'where',
    'क्या': 'what',
    'कौन': 'who',
    'कब': 'when',
    'क्यों': 'why',
    'आज': 'today',
    'कल': 'yesterday',
    'स्कूल': 'school',
    'स्कूल में': 'school',
    'घर': 'home',
    'पुस्तक': 'book',
    'किताब': 'book',
    'सेब': 'apple',
    'खाना': 'eat',
    'जाना': 'go',
    'जाता': 'go',
    'जाती': 'go',
    'जाते': 'go',
    'हूँ': '',
    'हूं': '',
    'है': '',
    'हैं': '',
    'था': '',
    'थे': '',
    'थी': '',
    'को': '',
    'में': 'in',
    'पर': 'on',
    'से': 'from',
    'और': '',
    'एक': 'a',
    // Romanized Hindi (common STT output on phones)
    'main': 'I',
    'mein': 'I',
    'mera': 'my',
    'meri': 'my',
    'mere': 'my',
    'mujhe': 'me',
    'mujhko': 'me',
    'aap': 'you',
    'app': 'you',
    'ap': 'you',
    'aapka': 'your',
    'aapki': 'your',
    'aapke': 'your',
    'apka': 'your',
    'apki': 'your',
    'apke': 'your',
    'tum': 'you',
    'tu': 'you',
    'tumhara': 'your',
    'tumhari': 'your',
    'tumhare': 'your',
    'tumara': 'your',
    'tumari': 'your',
    'tumare': 'your',
    'nam': 'name',
    'naam': 'name',
    'kya': 'what',
    'kaun': 'who',
    'kab': 'when',
    'kahan': 'where',
    'kaha': 'where',
    'kyun': 'why',
    'kyon': 'why',
    'kaise': 'how',
    'nahi': 'not',
    'nahin': 'not',
    'mat': "don't",
    'hai': '',
    'hain': '',
    'ho': '',
    'hun': '',
    'hoon': '',
    'tha': '',
    'the': '',
    'thi': '',
    'aaj': 'today',
    'kal': 'yesterday',
    'ghar': 'home',
    'school': 'school',
    'khana': 'eat',
    'jana': 'go',
    'jao': 'go',
    'chahiye': 'want',
    'chahie': 'want',
  };

  static const _tamilGrammarTokens = {
    'நான்': 'I',
    'என்': 'my',
    'நீ': 'you',
    'நீங்கள்': 'you',
    'நாங்கள்': 'we',
    'அவர்': 'he',
    'அவள்': 'she',
    'அவர்கள்': 'they',
    'இது': 'this',
    'அது': 'that',
    'வணக்கம்': 'hello',
    'எப்படி': 'how',
    'எங்கே': 'where',
    'என்ன': 'what',
    'இன்று': 'today',
    'பள்ளி': 'school',
    'வீடு': 'home',
    'சாப்பிட': 'eat',
    'போ': 'go',
    'இல்லை': 'not',
  };

  static const _malayalamGrammarTokens = {
    'ഞാൻ': 'I',
    'എന്റെ': 'my',
    'നീ': 'you',
    'നിങ്ങൾ': 'you',
    'ഞങ്ങൾ': 'we',
    'അവൻ': 'he',
    'അവൾ': 'she',
    'അവർ': 'they',
    'ഇത്': 'this',
    'അത്': 'that',
    'ഹലോ': 'hello',
    'എങ്ങനെ': 'how',
    'എവിടെ': 'where',
    'എന്ത്': 'what',
    'ഇന്ന്': 'today',
    'സ്കൂൾ': 'school',
    'വീട്': 'home',
    'തിന്ന': 'eat',
    'പോ': 'go',
    'ഇല്ല': 'not',
  };
}
