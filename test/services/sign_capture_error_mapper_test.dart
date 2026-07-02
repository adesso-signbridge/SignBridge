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
    tapToRecordSign: '',
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
    signRecordingEmptyLabel: 'recording-empty',
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

  group('worker HTTP status', () {
    test('401 maps to unauthorized', () {
      expect(
        SignCaptureErrorMapper.userMessage(
          HttpException('Sign worker 401: {"error":"Unauthorized"}'),
          copy,
        ),
        'unauthorized',
      );
    });

    test('400 missing video maps to recording empty', () {
      expect(
        SignCaptureErrorMapper.userMessage(
          HttpException('Sign worker 400: {"error":"Missing video file"}'),
          copy,
        ),
        'recording-empty',
      );
    });

    test('400 other maps to generic failure', () {
      expect(
        SignCaptureErrorMapper.userMessage(
          HttpException('Sign worker 400: {"error":"Expected multipart form data"}'),
          copy,
        ),
        'generic-failed',
      );
    });

    test('404 maps to service unavailable', () {
      expect(
        SignCaptureErrorMapper.userMessage(
          HttpException('Sign worker 404: Not Found'),
          copy,
        ),
        'service-unavailable',
      );
    });

    test('413 maps to recording too large', () {
      expect(
        SignCaptureErrorMapper.userMessage(
          HttpException('Sign worker 413: Video too large (max 10 MB)'),
          copy,
        ),
        'too-large',
      );
    });

    test('429 maps to rate limited', () {
      expect(
        SignCaptureErrorMapper.userMessage(
          HttpException('Sign worker 429: Too Many Requests'),
          copy,
        ),
        'rate-limited',
      );
    });

    test('503 with 1102 maps to worker overload', () {
      expect(
        SignCaptureErrorMapper.userMessage(
          HttpException('Sign worker 503: error code: 1102'),
          copy,
        ),
        'worker-overload',
      );
    });

    test('503 without 1102 maps to service unavailable', () {
      expect(
        SignCaptureErrorMapper.userMessage(
          HttpException('Sign worker 503: Service Unavailable'),
          copy,
        ),
        'service-unavailable',
      );
    });

    test('504 maps to upload timeout', () {
      expect(
        SignCaptureErrorMapper.userMessage(
          HttpException('Sign worker 504: Gateway Timeout'),
          copy,
        ),
        'upload-timeout',
      );
    });

    test('500 maps to service unavailable', () {
      expect(
        SignCaptureErrorMapper.userMessage(
          HttpException('Sign worker 500: Internal Server Error'),
          copy,
        ),
        'service-unavailable',
      );
    });
  });

  group('worker 502 upstream detail', () {
    test('maps Gemini 429 inside worker 502 to rate limit message', () {
      expect(
        SignCaptureErrorMapper.userMessage(
          HttpException(
            'Sign worker 502: {"error":"Sign recognition failed",'
            '"detail":"Error: Gemini 429: You exceeded quota"}',
          ),
          copy,
        ),
        'rate-limited',
      );
    });

    test('maps Gemini 404 model errors to model unavailable message', () {
      expect(
        SignCaptureErrorMapper.userMessage(
          HttpException(
            'Sign worker 502: {"error":"Sign recognition failed",'
            '"detail":"Gemini 404: models/gemini-2.5-flash not found"}',
          ),
          copy,
        ),
        'model-unavailable',
      );
    });

    test('maps gloss parse failures to no signs detected message', () {
      expect(
        SignCaptureErrorMapper.userMessage(
          HttpException(
            'Sign worker 502: {"detail":"Unable to parse gloss response"}',
          ),
          copy,
        ),
        'no-signs',
      );
    });

    test('maps compound worker 502 with 429, parse, and 404 to rate limit', () {
      expect(
        SignCaptureErrorMapper.userMessage(
          HttpException(
            'Sign worker 502: {"error":"Sign recognition failed","detail":'
            '"Error: Error: Gemini 429: You exceeded quota | '
            'Error: Unable to parse gloss response: Here is the JSON requested | '
            'Error: Gemini 404: models/gemini-2.5-flash not found","jobId":"1782186756751"}',
          ),
          copy,
        ),
        'rate-limited',
      );
    });

    test('maps Gemini 503 high demand inside worker 502 to rate limit message', () {
      expect(
        SignCaptureErrorMapper.userMessage(
          HttpException(
            'Sign worker 502: {"error":"Sign recognition failed",'
            '"detail":"Error: Gemini 503: The model is overloaded. Please try again later."}',
          ),
          copy,
        ),
        'rate-limited',
      );
    });

    test('maps Gemini 504 inside worker 502 to upload timeout', () {
      expect(
        SignCaptureErrorMapper.userMessage(
          HttpException(
            'Sign worker 502: {"error":"Sign recognition failed",'
            '"detail":"Gemini 504: Deadline exceeded"}',
          ),
          copy,
        ),
        'upload-timeout',
      );
    });

    test('maps unrecognized worker 502 detail to service unavailable', () {
      expect(
        SignCaptureErrorMapper.userMessage(
          HttpException(
            'Sign worker 502: {"error":"Sign recognition failed",'
            '"detail":"Unexpected upstream failure"}',
          ),
          copy,
        ),
        'service-unavailable',
      );
    });

    test('maps gemini_key not configured inside worker 502', () {
      expect(
        SignCaptureErrorMapper.userMessage(
          HttpException(
            'Sign worker 502: {"detail":"GEMINI_KEY not configured"}',
          ),
          copy,
        ),
        'not-configured',
      );
    });
  });

  group('non-http errors', () {
    test('maps TimeoutException to upload timeout message', () {
      expect(
        SignCaptureErrorMapper.userMessage(
          TimeoutException('Future not completed'),
          copy,
        ),
        'upload-timeout',
      );
    });

    test('maps SocketException to service unavailable', () {
      expect(
        SignCaptureErrorMapper.userMessage(
          const SocketException('Failed host lookup'),
          copy,
        ),
        'service-unavailable',
      );
    });
  });
}
