import 'sign_language_system.dart';
import 'sign_token.dart';

/// Outcome of a completed voice-listen session.
class TalkListenResult {
  const TalkListenResult({
    required this.transcript,
    required this.fullTranscript,
    required this.signingWord,
    required this.signTokenId,
    required this.signSystem,
    required this.signSequence,
    required this.heardDuration,
  });

  /// Partial transcript shown on the Heard screen.
  final String transcript;

  /// Complete transcript shown on the Signing screen.
  final String fullTranscript;

  /// Gloss label in the blue signing chip (matches avatar pose).
  final String signingWord;

  /// Native avatar pose id (e.g. `hello`, `how`).
  final String signTokenId;

  final SignLanguageSystem signSystem;

  /// Ordered ISL/ASL gloss tokens for the full utterance.
  final List<SignToken> signSequence;

  final String heardDuration;

  TalkListenResult copyWith({
    String? transcript,
    String? fullTranscript,
    String? signingWord,
    String? signTokenId,
    SignLanguageSystem? signSystem,
    List<SignToken>? signSequence,
    String? heardDuration,
  }) {
    return TalkListenResult(
      transcript: transcript ?? this.transcript,
      fullTranscript: fullTranscript ?? this.fullTranscript,
      signingWord: signingWord ?? this.signingWord,
      signTokenId: signTokenId ?? this.signTokenId,
      signSystem: signSystem ?? this.signSystem,
      signSequence: signSequence ?? this.signSequence,
      heardDuration: heardDuration ?? this.heardDuration,
    );
  }

  bool get hasTranscript => fullTranscript.trim().isNotEmpty;

  /// Result when the user stops before any speech was recognized.
  factory TalkListenResult.empty({
    required String languageCode,
    required Duration elapsed,
  }) {
    final system = SignLanguageSystem.forSpokenLanguage(languageCode);
    return TalkListenResult(
      transcript: '',
      fullTranscript: '',
      signingWord: SignToken.thinking.gloss,
      signTokenId: SignToken.thinking.id,
      signSystem: system,
      signSequence: const [],
      heardDuration: formatDuration(elapsed),
    );
  }

  static String formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
}

enum TalkSessionPhase { idle, listening, heard, signing, stopped }
