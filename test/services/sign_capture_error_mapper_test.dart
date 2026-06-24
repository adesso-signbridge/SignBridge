import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sign_bridge/services/home/home_ui_copy.dart';
import 'package:sign_bridge/services/translate/sign_capture_error_mapper.dart';

void main() {
  const copy = HomeUiCopy(
    emptyStateMessage: '',
    tapToListen: '',
    tapToSign: '',
    tapToTranslate: '',
    tapToStop: '',
    sendCaptionLabel: '',
    flipCameraLabel: '',
    clearCaptionLabel: '',
    recordingSignsLabel: '',
    analyzingSignsLabel: '',
    spokenLabel: '',
    signsCapturedLabel: '',
    replayLabel: '',
    cameraPermissionRequiredLabel: '',
    signCaptureFailedLabel: 'generic-failed',
    signCaptureRateLimitedLabel: 'rate-limited',
    signCaptureModelUnavailableLabel: 'model-unavailable',
    signCaptureServiceUnavailableLabel: 'service-unavailable',
    signCaptureWorkerOverloadLabel: 'worker-overload',
    signCaptureUploadTimeoutLabel: 'upload-timeout',
    signCaptureNotConfiguredLabel: 'not-configured',
    signCaptureUnauthorizedLabel: 'unauthorized',
    listeningLabel: '',
    signingPrefix: '',
    signingListeningWord: '',
    heardLabel: '',
    clearHistoryLabel: '',
    noSpeechDetectedLabel: '',
    micPermissionRequiredLabel: '',
    listenStartFailedLabel: '',
    talkTabLabel: '',
    phrasesTabLabel: '',
    settingsTitle: '',
    emergencySection: '',
    callEmergency: '',
    sos: '',
    callEmergencyConfirmTitle: '',
    callEmergencyConfirmBody: '',
    sosConfirmTitle: '',
    sosConfirmBody: '',
    emergencyCancelLabel: '',
    emergencyConfirmLabel: '',
    emergencyCallFailedLabel: '',
    sosCountdownTitle: '',
    sosCountdownBody: '',
    sosCountdownCancelLabel: '',
    emergencyPhonePermissionRequiredLabel: '',
    signRecordingTooShortLabel: '',
    signRecordingTooLargeLabel: 'too-large',
    signRecordingEmptyLabel: '',
    signNoSignsDetectedLabel: 'no-signs',
    aboutSection: '',
    appLabel: '',
    versionLabel: '',
    footerCopyright: '',
    languageChangeConfirmTitle: '',
    languageChangeConfirmLabel: '',
    languageChangeConfirmListeningBody: '',
    languageChangeConfirmRecordingBody: '',
    languageChangeBlockedAnalyzingLabel: '',
    languageChangeBlockedEmergencyLabel: '',
    languageChangedSnackbar: '',
  );

  test('maps Gemini 429 inside worker 502 to rate limit message', () {
    final message = SignCaptureErrorMapper.userMessage(
      HttpException(
        'Sign worker 502: {"error":"Sign recognition failed",'
        '"detail":"Error: Gemini 429: You exceeded quota"}',
      ),
      copy,
    );
    expect(message, 'rate-limited');
  });

  test('maps Gemini 404 model errors to model unavailable message', () {
    final message = SignCaptureErrorMapper.userMessage(
      HttpException(
        'Sign worker 502: {"error":"Sign recognition failed",'
        '"detail":"Gemini 404: models/gemini-2.5-flash not found"}',
      ),
      copy,
    );
    expect(message, 'model-unavailable');
  });

  test('maps gloss parse failures to no signs detected message', () {
    final message = SignCaptureErrorMapper.userMessage(
      HttpException(
        'Sign worker 502: {"detail":"Unable to parse gloss response"}',
      ),
      copy,
    );
    expect(message, 'no-signs');
  });

  test('maps compound worker 502 with 429, parse, and 404 to rate limit', () {
    final message = SignCaptureErrorMapper.userMessage(
      HttpException(
        'Sign worker 502: {"error":"Sign recognition failed","detail":'
        '"Error: Error: Gemini 429: You exceeded quota | '
        'Error: Unable to parse gloss response: Here is the JSON requested | '
        'Error: Gemini 404: models/gemini-2.5-flash not found","jobId":"1782186756751"}',
      ),
      copy,
    );
    expect(message, 'rate-limited');
  });

  test('maps worker 503 error code 1102 to worker overload message', () {
    final message = SignCaptureErrorMapper.userMessage(
      HttpException('Sign worker 503: error code: 1102'),
      copy,
    );
    expect(message, 'worker-overload');
  });

  test('maps TimeoutException to upload timeout message', () {
    final message = SignCaptureErrorMapper.userMessage(
      TimeoutException('Future not completed'),
      copy,
    );
    expect(message, 'upload-timeout');
  });

  test('maps 413 payload too large to recording too large message', () {
    final message = SignCaptureErrorMapper.userMessage(
      HttpException('Sign worker 413: Video too large (max 10 MB)'),
      copy,
    );
    expect(message, 'too-large');
  });
}
