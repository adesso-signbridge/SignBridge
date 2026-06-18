import '../../../services/home/home_ui_copy.dart';

/// Active talk/sign session mode used to decide language-change behavior.
enum AppSessionMode {
  idle,
  listenActive,
  listenStopped,
  signRecording,
  signAnalyzing,
  signSpoken,
  emergencyActive,
}

enum LanguageChangeAction {
  applyImmediate,
  confirmThenTeardown,
  block,
}

/// Callbacks registered by [HomeScreen] so [MainShell] can coordinate language
/// changes from any tab without bypassing session guards.
class HomeSessionRegistration {
  const HomeSessionRegistration({
    required this.teardownActiveSessions,
  });

  final Future<void> Function() teardownActiveSessions;
}

abstract final class LanguageChangeCoordinator {
  static LanguageChangeAction actionFor(AppSessionMode mode) {
    return switch (mode) {
      AppSessionMode.idle ||
      AppSessionMode.listenStopped ||
      AppSessionMode.signSpoken => LanguageChangeAction.applyImmediate,
      AppSessionMode.listenActive ||
      AppSessionMode.signRecording => LanguageChangeAction.confirmThenTeardown,
      AppSessionMode.signAnalyzing ||
      AppSessionMode.emergencyActive => LanguageChangeAction.block,
    };
  }

  static String blockMessageFor(AppSessionMode mode, HomeUiCopy uiCopy) {
    return switch (mode) {
      AppSessionMode.signAnalyzing => uiCopy.languageChangeBlockedAnalyzingLabel,
      AppSessionMode.emergencyActive =>
        uiCopy.languageChangeBlockedEmergencyLabel,
      _ => uiCopy.languageChangeBlockedAnalyzingLabel,
    };
  }

  static String confirmBodyFor(AppSessionMode mode, HomeUiCopy uiCopy) {
    return switch (mode) {
      AppSessionMode.listenActive => uiCopy.languageChangeConfirmListeningBody,
      AppSessionMode.signRecording => uiCopy.languageChangeConfirmRecordingBody,
      _ => uiCopy.languageChangeConfirmListeningBody,
    };
  }
}
