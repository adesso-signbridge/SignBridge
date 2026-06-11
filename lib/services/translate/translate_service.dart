import '../../core/services/microservice.dart';

import 'talk_listen_result.dart';
import 'talk_listen_update.dart';

export 'sign_language_system.dart';
export 'sign_token.dart';
export 'talk_listen_result.dart';
export 'talk_listen_update.dart';

abstract class TranslateService implements Microservice {
  Future<String> getStatusMessage();

  /// Opens listen streams. Subscribe to [listenUpdates] before [activateListening].
  Future<void> prepareListening(String languageCode);

  /// Starts microphone capture and speech recognition.
  Future<bool> activateListening();

  /// Convenience wrapper: [prepareListening] then [activateListening].
  Future<bool> startListening(String languageCode) async {
    await prepareListening(languageCode);
    return activateListening();
  }

  /// Live partial/final captions and signing gloss while listening.
  Stream<TalkListenUpdate> listenUpdates();

  /// Fatal/recoverable speech errors while a listen session is active.
  Stream<String> listenErrors();

  /// Normalized microphone level (0–1) while a listen session is active.
  Stream<double> audioLevelUpdates();

  /// Stops capture and returns the final listen result.
  Future<TalkListenResult> stopListening(String languageCode);

  /// Cancels an in-flight listen session.
  Future<void> cancelListening();

  /// Returns sample payload for [languageCode] (simulator / empty stop).
  TalkListenResult peekListenResult(String languageCode);
}
