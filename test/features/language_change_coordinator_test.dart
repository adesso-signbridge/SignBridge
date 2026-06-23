import 'package:flutter_test/flutter_test.dart';
import 'package:sign_bridge/features/home/presentation/language_change_coordinator.dart';
import 'package:sign_bridge/services/home/home_ui_copy.dart';

void main() {
  const uiCopy = HomeUiCopy(
    emptyStateMessage: '',
    tapToListen: '',
    tapToSign: '',
    tapToTranslate: '',
    tapToStop: '',
    recordingSignsLabel: '',
    analyzingSignsLabel: '',
    spokenLabel: '',
    signsCapturedLabel: '',
    replayLabel: '',
    cameraPermissionRequiredLabel: '',
    signCaptureFailedLabel: '',
    signCaptureRateLimitedLabel: '',
    signCaptureModelUnavailableLabel: '',
    signCaptureServiceUnavailableLabel: '',
    signCaptureNotConfiguredLabel: '',
    signCaptureUnauthorizedLabel: '',
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
    signRecordingEmptyLabel: '',
    signNoSignsDetectedLabel: '',
    aboutSection: '',
    appLabel: '',
    versionLabel: '',
    footerCopyright: '',
    languageChangeConfirmTitle: '',
    languageChangeConfirmLabel: '',
    languageChangeConfirmListeningBody: 'listening-body',
    languageChangeConfirmRecordingBody: 'recording-body',
    languageChangeBlockedAnalyzingLabel: 'analyzing-blocked',
    languageChangeBlockedEmergencyLabel: 'emergency-blocked',
    languageChangedSnackbar: 'changed {language}',
  );

  group('LanguageChangeCoordinator', () {
    test('idle and stopped sessions apply immediately', () {
      expect(
        LanguageChangeCoordinator.actionFor(AppSessionMode.idle),
        LanguageChangeAction.applyImmediate,
      );
      expect(
        LanguageChangeCoordinator.actionFor(AppSessionMode.listenStopped),
        LanguageChangeAction.applyImmediate,
      );
      expect(
        LanguageChangeCoordinator.actionFor(AppSessionMode.signSpoken),
        LanguageChangeAction.applyImmediate,
      );
    });

    test('active listen and sign recording require confirmation', () {
      expect(
        LanguageChangeCoordinator.actionFor(AppSessionMode.listenActive),
        LanguageChangeAction.confirmThenTeardown,
      );
      expect(
        LanguageChangeCoordinator.actionFor(AppSessionMode.signRecording),
        LanguageChangeAction.confirmThenTeardown,
      );
    });

    test('analyzing and emergency sessions are blocked', () {
      expect(
        LanguageChangeCoordinator.actionFor(AppSessionMode.signAnalyzing),
        LanguageChangeAction.block,
      );
      expect(
        LanguageChangeCoordinator.actionFor(AppSessionMode.emergencyActive),
        LanguageChangeAction.block,
      );
    });

    test('confirm and block messages match session mode', () {
      expect(
        LanguageChangeCoordinator.confirmBodyFor(
          AppSessionMode.listenActive,
          uiCopy,
        ),
        'listening-body',
      );
      expect(
        LanguageChangeCoordinator.confirmBodyFor(
          AppSessionMode.signRecording,
          uiCopy,
        ),
        'recording-body',
      );
      expect(
        LanguageChangeCoordinator.blockMessageFor(
          AppSessionMode.signAnalyzing,
          uiCopy,
        ),
        'analyzing-blocked',
      );
      expect(
        LanguageChangeCoordinator.blockMessageFor(
          AppSessionMode.emergencyActive,
          uiCopy,
        ),
        'emergency-blocked',
      );
    });
  });
}
