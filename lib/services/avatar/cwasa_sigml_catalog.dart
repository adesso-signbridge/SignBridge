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

  static int mappedSignCount(String glossPhrase) {
    return fragmentsForPhrase(glossPhrase).length;
  }

  static List<String> fragmentsForPhrase(String glossPhrase) {
    final trimmed = glossPhrase.trim();
    if (trimmed.isEmpty || trimmed == '...') {
      return const [];
    }

    final fragments = <String>[];
    for (final raw in trimmed.split(RegExp(r'\s+'))) {
      final fragment = fragmentForToken(raw);
      if (fragment != null) {
        fragments.add(fragment);
      }
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

  static String? fragmentForToken(String rawToken) {
    switch (_normalizeToken(rawToken)) {
      case 'I':
      case 'ME':
      case 'MY':
      case 'YOU':
      case 'YOUR':
      case 'WE':
      case 'OUR':
        return _iSign;
      case 'HELLO':
      case 'HI':
      case 'HEY':
      case 'HOW':
      case 'WHAT':
      case 'WHY':
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
        return _takeSign;
      case 'GOOD':
      case 'FINE':
      case 'OK':
      case 'YES':
        return _mugSign;
      case 'TELL':
      case 'SAY':
      case 'SPEAK':
      case 'ASK':
      case 'UNDERSTAND':
      case 'KNOW':
      case 'LEARN':
      case 'Q':
      case 'QUESTION':
        return _takeSign;
      case 'MUG':
      case 'CUP':
      case 'COFFEE':
      case 'DRINK':
      case 'TEA':
      case 'WATER':
      case 'HOT':
        return _mugSign;
      default:
        return null;
    }
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
