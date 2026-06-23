import '../translate/sign_token.dart';

/// Maps ASL/ISL gloss tokens to CWASA SiGML sign fragments (BSL HamNoSys).
///
/// CWASA is developed by UEA Virtual Humans and distributed under CC BY-SA.
/// See https://vh.cmp.uea.ac.uk/index.php/CWA_Signing_Avatars_Demos
abstract final class CwasaSigmlCatalog {
  static const _sigmlHeader =
      '<?xml version="1.0" encoding="utf-8"?>\n<sigml>\n';
  static const _sigmlFooter = '\n</sigml>';

  /// Full phrase SiGML hosted by UEA (used when gloss matches exactly).
  static const iTakeMugUrl =
      'https://vhg.cmp.uea.ac.uk/tech/jas/vhg2021/sigml/iTakeMug.sigml';

  static String? buildDocument(String glossPhrase) {
    final fragments = fragmentsForPhrase(glossPhrase);
    if (fragments.isEmpty) {
      return null;
    }
    return '$_sigmlHeader${fragments.join('\n')}$_sigmlFooter';
  }

  static String? buildDocumentFromSequence(List<SignToken> sequence) {
    final fragments = fragmentsForSequence(sequence);
    if (fragments.isEmpty) {
      return null;
    }
    return '$_sigmlHeader${fragments.join('\n')}$_sigmlFooter';
  }

  /// Returns only the gloss tokens appended since [previousPhrase].
  static String glossTokenDelta(String previousPhrase, String currentPhrase) {
    final previous = previousPhrase.trim();
    final current = currentPhrase.trim();
    if (current.isEmpty || current == '...') {
      return '';
    }
    if (previous.isEmpty || previous == '...') {
      return current;
    }

    final previousTokens = previous.split(RegExp(r'\s+'));
    final currentTokens = current.split(RegExp(r'\s+'));
    if (currentTokens.length < previousTokens.length) {
      return current;
    }

    for (var index = 0; index < previousTokens.length; index++) {
      if (currentTokens[index] != previousTokens[index]) {
        return current;
      }
    }

    if (currentTokens.length == previousTokens.length) {
      return '';
    }

    return currentTokens.sublist(previousTokens.length).join(' ');
  }

  /// Builds one multi-sign SiGML document for newly appended gloss tokens.
  static String? buildDocumentForDelta({
    required String previousPhrase,
    required String currentPhrase,
  }) {
    final delta = glossTokenDelta(previousPhrase, currentPhrase);
    if (delta.isEmpty) {
      return null;
    }
    return buildDocument(delta);
  }

  static String? buildDocumentForSequenceDelta({
    required List<SignToken> previous,
    required List<SignToken> current,
  }) {
    final delta = sequenceTokenDelta(previous, current);
    if (delta.isEmpty) {
      return null;
    }
    return buildDocumentFromSequence(delta);
  }

  static List<SignToken> sequenceTokenDelta(
    List<SignToken> previous,
    List<SignToken> current,
  ) {
    if (current.length <= previous.length) {
      return const [];
    }

    for (var index = 0; index < previous.length; index++) {
      final prior = previous[index];
      final next = current[index];
      if (prior.id != next.id || prior.gloss != next.gloss) {
        return current;
      }
    }

    return current.sublist(previous.length);
  }

  static int mappedSignCount(String glossPhrase) {
    return fragmentsForPhrase(glossPhrase).length;
  }

  static List<String> fragmentsForPhrase(String glossPhrase) {
    final trimmed = glossPhrase.trim();
    if (trimmed.isEmpty || trimmed == '...') {
      return const [];
    }

    return trimmed
        .split(RegExp(r'\s+'))
        .map(fragmentForToken)
        .toList(growable: false);
  }

  static List<String> fragmentsForSequence(List<SignToken> sequence) {
    final fragments = <String>[];
    for (final token in sequence) {
      if (token.id == SignToken.thinking.id) {
        continue;
      }
      fragments.add(fragmentForSignToken(token));
    }
    return fragments;
  }

  /// One SiGML document per mapped gloss token.
  static List<String> signDocumentsForPhrase(String glossPhrase) {
    return fragmentsForPhrase(glossPhrase)
        .map((fragment) => '$_sigmlHeader$fragment$_sigmlFooter')
        .toList(growable: false);
  }

  /// Returns a remote SiGML URL when the full gloss matches a hosted phrase.
  static String? remoteUrlForPhrase(String glossPhrase) {
    final normalized = _normalizePhrase(glossPhrase);
    switch (normalized) {
      case 'ME WANT MUG':
      case 'I WANT MUG':
      case 'I TAKE MUG':
        return iTakeMugUrl;
      default:
        return null;
    }
  }

  static String fragmentForToken(String rawToken) {
    final normalized = _normalizeToken(rawToken);
    return _specificFragment(normalized) ?? _fallbackFragmentForToken(normalized);
  }

  static String fragmentForSignToken(SignToken token) {
    if (token.id == SignToken.thinking.id) {
      return _iSign;
    }

    final fromGloss = _specificFragment(_normalizeToken(token.gloss));
    if (fromGloss != null) {
      return fromGloss;
    }

    return _fragmentForSignId(token.id);
  }

  static String? _specificFragment(String normalized) {
    switch (normalized) {
      case 'I':
      case 'ME':
      case 'MY':
      case 'MINE':
      case 'YOU':
      case 'YOUR':
      case 'YOURS':
      case 'WE':
      case 'OUR':
      case 'OURS':
      case 'THEY':
      case 'THEM':
      case 'THEIR':
      case 'HE':
      case 'SHE':
      case 'HIM':
      case 'HER':
      case 'HIS':
      case 'ITS':
        return _iSign;
      case 'THIS':
      case 'THAT':
      case 'THESE':
      case 'THOSE':
      case 'HERE':
      case 'THERE':
      case 'WHERE':
      case 'WHO':
      case 'WHOM':
      case 'WHICH':
        return _iSign;
      case 'HELLO':
      case 'HI':
      case 'HEY':
      case 'HOW':
      case 'WHAT':
      case 'WHY':
      case 'WHEN':
        return _takeSign;
      case 'WANT':
      case 'NEED':
      case 'TAKE':
      case 'GET':
      case 'RECEIVE':
      case 'BUY':
      case 'PASS':
      case 'PASS-ME':
      case 'BRING':
      case 'GIVE':
      case 'TELL':
      case 'SAY':
      case 'SPEAK':
      case 'ASK':
      case 'UNDERSTAND':
      case 'KNOW':
      case 'LEARN':
      case 'TALK':
      case 'CHAT':
      case 'CALL':
      case 'TEXT':
      case 'MESSAGE':
      case 'Q':
      case 'QUESTION':
      case 'TIME':
      case 'CLOCK':
      case 'HOUR':
      case 'MINUTE':
      case 'DAY':
      case 'WEEK':
      case 'MONTH':
      case 'YEAR':
      case 'IS':
      case 'ARE':
      case 'AM':
      case 'BE':
      case 'WAS':
      case 'WERE':
      case 'DO':
      case 'DOES':
      case 'DID':
      case 'CAN':
      case 'COULD':
      case 'WILL':
      case 'WOULD':
      case 'SHOULD':
      case 'MAY':
      case 'MIGHT':
      case 'MUST':
      case 'HAVE':
      case 'HAS':
      case 'HAD':
      case 'GO':
      case 'COME':
      case 'WORK':
      case 'MEET':
      case 'SEE':
      case 'LOOK':
      case 'WATCH':
      case 'LISTEN':
      case 'HEAR':
      case 'THINK':
      case 'FEEL':
      case 'TRY':
      case 'START':
      case 'STOP':
      case 'WAIT':
      case 'HELP':
      case 'PLEASE':
        return _takeSign;
      case 'GOOD':
      case 'FINE':
      case 'OK':
      case 'YES':
      case 'GREAT':
      case 'NICE':
      case 'WELL':
      case 'BETTER':
      case 'BEST':
      case 'THANK':
      case 'THANKS':
      case 'THANK-YOU':
      case 'SORRY':
      case 'WELCOME':
      case 'MORNING':
      case 'AFTERNOON':
      case 'EVENING':
      case 'NIGHT':
      case 'TODAY':
      case 'TOMORROW':
      case 'YESTERDAY':
      case 'NOW':
      case 'LATER':
      case 'SOON':
        return _mugSign;
      case 'NO':
      case 'NOT':
      case 'NEVER':
      case 'NONE':
      case 'BAD':
      case 'WRONG':
        return _mugSign;
      case 'MUG':
      case 'CUP':
      case 'COFFEE':
      case 'DRINK':
      case 'TEA':
      case 'WATER':
      case 'HOT':
      case 'FOOD':
      case 'EAT':
      case 'HUNGRY':
        return _mugSign;
      case 'THE':
      case 'A':
      case 'AN':
      case 'AND':
      case 'OR':
      case 'BUT':
      case 'IF':
      case 'SO':
      case 'TO':
      case 'FOR':
      case 'WITH':
      case 'FROM':
      case 'IN':
      case 'ON':
      case 'AT':
      case 'OF':
      case 'BY':
      case 'ABOUT':
      case 'UP':
      case 'DOWN':
      case 'OUT':
      case 'OVER':
      case 'UNDER':
        return _iSign;
      default:
        return null;
    }
  }

  static String _fragmentForSignId(String id) {
    return switch (id) {
      'hello' ||
      'how' ||
      'please' ||
      'help' ||
      'looking' ||
      'question' ||
      'time' ||
      'talk' ||
      'meet' ||
      'work' ||
      'today' ||
      'tomorrow' ||
      'yesterday' =>
        _takeSign,
      'you' ||
      'my' ||
      'name' ||
      'is' ||
      'this' ||
      'that' ||
      'here' ||
      'there' ||
      'who' ||
      'what' ||
      'where' ||
      'when' ||
      'why' =>
        _iSign,
      'good' ||
      'yes' ||
      'no' ||
      'thank_you' ||
      'everything' ||
      'morning' ||
      'afternoon' ||
      'evening' ||
      'night' ||
      'sorry' ||
      'welcome' =>
        _mugSign,
      'thinking' => _iSign,
      _ => _fallbackFragmentForToken(id),
    };
  }

  static String _fallbackFragmentForToken(String token) {
    if (token.isEmpty) {
      return _iSign;
    }

    final bucket = token.codeUnits.fold<int>(0, (sum, unit) => sum + unit) % 3;
    return switch (bucket) {
      0 => _iSign,
      1 => _takeSign,
      _ => _mugSign,
    };
  }

  static String _normalizePhrase(String phrase) {
    return phrase
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  static String _normalizeToken(String token) {
    return token.trim().toUpperCase().replaceAll('_', '-');
  }

  // Fragments from UEA iTakeMug.sigml (CC BY-SA).
  static const _iSign = '''
<hamgestural_sign gloss="i">
  <sign_nonmanual>
    <mouthing_tier>
      <mouth_picture picture="a_I"/>
    </mouthing_tier>
  </sign_nonmanual>
  <sign_manual>
    <handconfig handshape="finger2" thumbpos="across"/>
    <handconfig extfidir="il"/>
    <handconfig palmor="r"/>
    <location_bodyarm location="chest" contact="touch"/>
  </sign_manual>
</hamgestural_sign>''';

  static const _takeSign = '''
<hamgestural_sign gloss="take">
  <sign_nonmanual>
    <mouthing_tier>
      <mouth_picture picture="te_Ik"/>
    </mouthing_tier>
  </sign_nonmanual>
  <sign_manual>
    <handconfig handshape="ceeall"/>
    <handconfig extfidir="ol"/>
    <handconfig palmor="l"/>
    <location_bodyarm location="shoulders" side="left_beside" contact="armextended"/>
    <tgt_motion>
      <changeposture/>
      <handconfig extfidir="l" palmor="l"/>
      <location_bodyarm location="chest" contact="close"/>
    </tgt_motion>
  </sign_manual>
</hamgestural_sign>''';

  static const _mugSign = '''
<hamgestural_sign gloss="mug">
  <sign_nonmanual>
    <mouthing_tier>
      <mouth_picture picture="mVg"/>
    </mouthing_tier>
  </sign_nonmanual>
  <sign_manual>
    <handconfig handshape="fist" thumbpos="across"/>
    <handconfig extfidir="ol"/>
    <handconfig palmor="l"/>
    <location_bodyarm location="shoulders"/>
    <par_motion>
      <directedmotion direction="u" curve="u"/>
      <tgt_motion>
        <changeposture/>
        <handconfig extfidir="ul" palmor="dl"/>
      </tgt_motion>
    </par_motion>
  </sign_manual>
</hamgestural_sign>''';
}
