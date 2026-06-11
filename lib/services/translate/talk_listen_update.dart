import 'sign_language_system.dart';
import 'sign_token.dart';
import 'talk_listen_result.dart';

/// Live payload while speech is being captured and transcribed.
class TalkListenUpdate {
  const TalkListenUpdate({
    required this.transcript,
    required this.fullTranscript,
    required this.signingWord,
    required this.signTokenId,
    required this.signSystem,
    required this.signSequence,
    required this.isFinal,
    required this.elapsed,
  });

  final String transcript;
  final String fullTranscript;
  final String signingWord;
  final String signTokenId;
  final SignLanguageSystem signSystem;
  final List<SignToken> signSequence;
  final bool isFinal;
  final Duration elapsed;

  TalkListenResult toResult() {
    return TalkListenResult(
      transcript: transcript,
      fullTranscript: fullTranscript,
      signingWord: signingWord,
      signTokenId: signTokenId,
      signSystem: signSystem,
      signSequence: signSequence,
      heardDuration: TalkListenResult.formatDuration(elapsed),
    );
  }
}
