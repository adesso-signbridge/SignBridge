import 'sign_language_system.dart';

/// One sign token in a gloss sequence — drives the chip label and avatar pose.
class SignToken {
  const SignToken({
    required this.id,
    required this.gloss,
    required this.system,
  });

  /// Stable id passed to the native avatar renderer (e.g. `hello`, `how`).
  final String id;

  /// Gloss label shown in the blue signing chip (e.g. `HELLO`, `HOW`).
  final String gloss;

  final SignLanguageSystem system;

  static const thinking = SignToken(
    id: 'thinking',
    gloss: '...',
    system: SignLanguageSystem.asl,
  );

  SignToken copyWith({String? gloss, SignLanguageSystem? system}) {
    return SignToken(
      id: id,
      gloss: gloss ?? this.gloss,
      system: system ?? this.system,
    );
  }
}
