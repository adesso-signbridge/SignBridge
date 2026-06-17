import 'sign_language_system.dart';
import 'sign_token.dart';

/// Non-manual markers (NMM) per ASL Gloss Engine Specification Module 6.
abstract final class AslNmmMarkers {
  static const whQ = 'nmm:wh-q';
  static const ynQ = 'nmm:y-n-q';
  static const rhQ = 'nmm:rh-q';
  static const headshake = 'nmm:headshake';
  static const mm = 'nmm:mm';
  static const cha = 'nmm:cha';
  static const th = 'nmm:th';
  static const cs = 'nmm:cs';
  static const roleShift = 'nmm:role-shift';

  static const allMarkers = {
    whQ,
    ynQ,
    rhQ,
    headshake,
    mm,
    cha,
    th,
    cs,
    roleShift,
  };

  static const _glossLabels = {
    whQ: '[wh-q]',
    ynQ: '[y/n-q]',
    rhQ: '[rh-q]',
    headshake: '[headshake]',
    mm: '[mm]',
    cha: '[cha]',
    th: '[th]',
    cs: '[cs]',
    roleShift: '[role-shift]',
  };

  static bool isMarker(String word) => word.startsWith('nmm:');

  static SignToken token(String markerId, SignLanguageSystem system) {
    final gloss =
        _glossLabels[markerId] ?? '[${markerId.replaceFirst('nmm:', '')}]';
    return SignToken(
      id: markerId.replaceAll(':', '_'),
      gloss: gloss,
      system: system,
    );
  }
}
