import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/platform/camera_permission.dart';
import '../../../core/platform/sign_camera_test_mode.dart';
import '../../../core/platform/microphone_permission.dart';
import '../../../core/platform/speech_permission.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../services/gloss/gloss_sequence_mapper.dart';
import '../../../services/avatar/sign_asset_catalog.dart';
import '../../../services/gloss/cloudflare_gloss_config.dart';
import '../../../services/gloss/cloudflare_gloss_service.dart';
import '../../../services/gloss/gloss_caption_delta.dart';
import '../../../services/gloss/gloss_service.dart';
import '../../../services/home/home_service.dart';
import '../../../services/phrases/phrase_speech_service.dart';
import '../../../services/translate/sign_capture_config.dart';
import '../../../services/translate/sign_capture_error_mapper.dart';
import '../../../services/translate/sign_capture_service.dart';
import '../../../services/translate/sign_language_system.dart';
import '../../../services/translate/translate_service.dart';
import 'language_change_coordinator.dart';
import 'widgets/talk_audio_waveform.dart';
import 'widgets/talk_session_content.dart';
import 'widgets/talk_sign_session_content.dart';

enum SignFlowPhase { idle, recording, analyzing, spoken }

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.homeService,
    required this.translateService,
    required this.signCaptureService,
    required this.phraseSpeechService,
    required this.glossService,
    required this.localGlossService,
    required this.selectedLanguageCode,
    required this.uiCopy,
    required this.emergencyActive,
    required this.onMenuTap,
    required this.onLanguageChanged,
    required this.onRegisterSession,
    required this.onUnregisterSession,
    required this.onSessionModeChanged,
  });

  final HomeService homeService;
  final TranslateService translateService;
  final SignCaptureService signCaptureService;
  final PhraseSpeechService phraseSpeechService;
  final GlossService glossService;
  final GlossService localGlossService;
  final String selectedLanguageCode;
  final HomeUiCopy uiCopy;
  final bool emergencyActive;
  final VoidCallback onMenuTap;
  final ValueChanged<String> onLanguageChanged;
  final ValueChanged<HomeSessionRegistration> onRegisterSession;
  final VoidCallback onUnregisterSession;
  final ValueChanged<AppSessionMode> onSessionModeChanged;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  HomeContent? _content;
  bool _languageMenuOpen = false;
  TalkSessionPhase _sessionPhase = TalkSessionPhase.idle;
  TalkListenResult? _listenResult;
  bool _listenInFlight = false;
  bool _stopInFlight = false;
  int _listenGeneration = 0;
  int _signPulse = 0;
  double _audioLevel = 0;
  StreamSubscription<TalkListenUpdate>? _listenSubscription;
  StreamSubscription<String>? _listenErrorSubscription;
  StreamSubscription<double>? _audioLevelSubscription;
  SignFlowPhase _signPhase = SignFlowPhase.idle;
  SignCaptureResult? _signResult;
  bool _signRecordingActive = false;
  bool _uploadAfterStop = false;
  DateTime? _signRecordingStartedAt;
  Duration? _signClipDuration;
  int _signGeneration = 0;
  int _signSpeakGeneration = 0;
  bool _cloudGlossInFlight = false;
  String? _cloudGlossWord;
  String? _stitchedGlossVideoUrl;
  final List<String> _accumulatedGlossTokens = [];
  Timer? _liveGlossDebounceTimer;
  int _glossRequestGeneration = 0;
  String? _lastFetchedGlossCaption;
  String? _glossInFlightEndCaption;

  @override
  void dispose() {
    widget.onUnregisterSession();
    _cancelLiveGlossDebounce();
    _cancelSessionTimers();
    _listenSubscription?.cancel();
    _listenErrorSubscription?.cancel();
    _stopAudioLevelSubscription();
    unawaited(widget.translateService.cancelListening());
    super.dispose();
  }

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    widget.onSessionModeChanged(_appSessionMode);
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.emergencyActive != widget.emergencyActive) {
      widget.onSessionModeChanged(_appSessionMode);
    }
    if (oldWidget.selectedLanguageCode != widget.selectedLanguageCode) {
      _handleLanguageApplied(
        oldCode: oldWidget.selectedLanguageCode,
        newCode: widget.selectedLanguageCode,
      );
    }
  }

  AppSessionMode get _appSessionMode {
    if (widget.emergencyActive) {
      return AppSessionMode.emergencyActive;
    }
    return switch (_signPhase) {
      SignFlowPhase.recording => AppSessionMode.signRecording,
      SignFlowPhase.analyzing => AppSessionMode.signAnalyzing,
      SignFlowPhase.spoken => AppSessionMode.signSpoken,
      SignFlowPhase.idle => switch (_sessionPhase) {
        TalkSessionPhase.listening ||
        TalkSessionPhase.heard ||
        TalkSessionPhase.signing => AppSessionMode.listenActive,
        TalkSessionPhase.stopped => AppSessionMode.listenStopped,
        TalkSessionPhase.idle => AppSessionMode.idle,
      },
    };
  }

  Future<void> _teardownActiveSessions() async {
    if (_isActiveListenPhase) {
      await _abortListenSessionForLanguageChange();
    }
    if (_signPhase == SignFlowPhase.recording) {
      ++_signGeneration;
      await widget.phraseSpeechService.stop();
      if (!mounted) {
        return;
      }
      setState(() {
        _signPhase = SignFlowPhase.idle;
        _signRecordingActive = false;
        _resetSignCaptureState();
      });
    }
  }

  void _handleLanguageApplied({
    required String oldCode,
    required String newCode,
  }) {
    if (_signPhase == SignFlowPhase.spoken) {
      return;
    }
    if (_sessionPhase != TalkSessionPhase.stopped || _listenResult == null) {
      return;
    }
    final oldSystem = SignLanguageSystem.forSpokenLanguage(oldCode);
    final newSystem = SignLanguageSystem.forSpokenLanguage(newCode);
    if (oldSystem == newSystem) {
      return;
    }

    final result = _listenResult!;
    _resetLiveGlossState();
    setState(() {
      _listenResult = _listenResultForAvatar(result);
    });
    if (result.hasTranscript) {
      unawaited(_refreshLiveGloss());
    }
  }

  bool get _isActiveListenPhase {
    return switch (_sessionPhase) {
      TalkSessionPhase.listening ||
      TalkSessionPhase.heard ||
      TalkSessionPhase.signing => true,
      TalkSessionPhase.idle || TalkSessionPhase.stopped => false,
    };
  }

  void _cancelSessionTimers() {
    _cancelLiveGlossDebounce();
  }

  void _resetSignCaptureState() {
    _uploadAfterStop = false;
    _signRecordingStartedAt = null;
    _signClipDuration = null;
  }

  void _returnToSignPreview({bool clearUploadFlag = true}) {
    if (clearUploadFlag) {
      _uploadAfterStop = false;
    }
    _signRecordingActive = false;
    _signRecordingStartedAt = null;
    _signClipDuration = null;
  }

  void _cancelLiveGlossDebounce() {
    _liveGlossDebounceTimer?.cancel();
    _liveGlossDebounceTimer = null;
  }

  void _resetLiveGlossState() {
    _cancelLiveGlossDebounce();
    _glossRequestGeneration++;
    _cloudGlossWord = null;
    _stitchedGlossVideoUrl = null;
    _accumulatedGlossTokens.clear();
    _lastFetchedGlossCaption = null;
    _glossInFlightEndCaption = null;
  }

  String _normalizeGlossCaption(String caption) => caption.trim();

  String? _glossCaptionDelta(String caption) {
    return GlossCaptionDelta.compute(
      fullCaption: _normalizeGlossCaption(caption),
      glossedPrefix: _lastFetchedGlossCaption ?? '',
    );
  }

  bool _needsGlossRefresh(String caption) {
    final normalized = _normalizeGlossCaption(caption);
    if (normalized.isEmpty) {
      return false;
    }
    if (_glossCaptionDelta(normalized) == null) {
      return false;
    }
    if (_cloudGlossInFlight && normalized == _glossInFlightEndCaption) {
      return false;
    }
    return true;
  }

  void _stopAudioLevelSubscription() {
    _audioLevelSubscription?.cancel();
    _audioLevelSubscription = null;
    _audioLevel = 0;
  }

  @override
  void initState() {
    super.initState();
    widget.onRegisterSession(
      HomeSessionRegistration(
        teardownActiveSessions: _teardownActiveSessions,
      ),
    );
    widget.onSessionModeChanged(_appSessionMode);
    widget.homeService.fetchHomeContent().then((content) {
      if (mounted) {
        setState(() => _content = content);
      }
    });
  }

  HomeLanguage? get _selectedLanguage {
    final content = _content;
    if (content == null) {
      return null;
    }
    return content.languages.firstWhere(
      (language) => language.code == widget.selectedLanguageCode,
      orElse: () => content.languages.first,
    );
  }

  TalkListenResult? get _heardForSignFlow {
    final result = _listenResult;
    if (result != null && result.hasTranscript) {
      return result;
    }
    return null;
  }

  bool get _isSignFlowActive => _signPhase != SignFlowPhase.idle;

  String? get _signRecordingStatusLabel {
    if (_signRecordingActive) {
      return widget.uiCopy.recordingSignsLabel;
    }
    return widget.uiCopy.flipCameraLabel;
  }

  void _onSignRecordTap() {
    if (_signPhase != SignFlowPhase.recording || _signRecordingActive) {
      return;
    }
    setState(() => _signRecordingActive = true);
    debugPrint('[SignBridge/SignCapture] clip recording started');
  }

  void _onSignStopTap() {
    if (_signPhase != SignFlowPhase.recording) {
      return;
    }

    if (signCameraTestModeEnabled) {
      if (_signRecordingActive) {
        _uploadAfterStop = true;
        setState(() => _signRecordingActive = false);
        unawaited(_analyzeSignVideo('mock-sign-capture.mp4'));
      }
      return;
    }

    if (!_signRecordingActive) {
      return;
    }

    _uploadAfterStop = true;
    setState(() => _signRecordingActive = false);
  }

  /// Clear history after listen stops or sign translation finishes — never
  /// while sign recording or analysis is in progress.
  bool get _showClearHistory {
    return switch (_signPhase) {
      SignFlowPhase.recording || SignFlowPhase.analyzing => false,
      SignFlowPhase.spoken => true,
      SignFlowPhase.idle => _sessionPhase == TalkSessionPhase.stopped,
    };
  }

  Future<void> _startSignRecording() async {
    if (_signPhase != SignFlowPhase.idle || _isActiveListenPhase) {
      return;
    }

    final generation = ++_signGeneration;
    _resetSignCaptureState();

    if (signCameraTestModeEnabled) {
      if (!mounted || generation != _signGeneration) {
        return;
      }
      setState(() {
        _signPhase = SignFlowPhase.recording;
        _signRecordingActive = true;
        _signRecordingStartedAt = DateTime.now();
      });
      return;
    }

    final cameraGranted = await cameraPermissionRequester();
    if (!cameraGranted) {
      if (mounted) {
        _showSignMessage(widget.uiCopy.cameraPermissionRequiredLabel);
      }
      return;
    }
    if (!mounted || generation != _signGeneration) {
      return;
    }
    setState(() {
      _signPhase = SignFlowPhase.recording;
      _signRecordingActive = false;
    });
    debugPrint('[SignBridge/SignCapture] camera preview (flip, then tap to record)');
  }

  void _onSignRecordingStopped(String videoPath, Duration recordingDuration) {
    final generation = _signGeneration;
    if (!mounted || generation != _signGeneration) {
      return;
    }

    _signClipDuration = recordingDuration;
    debugPrint(
      '[SignBridge/SignCapture] clip saved '
      '${recordingDuration.inMilliseconds}ms',
    );

    if (!_uploadAfterStop) {
      return;
    }

    _uploadAfterStop = false;
    unawaited(_analyzeSignVideo(videoPath));
  }

  Future<void> _analyzeSignVideo(String videoPath) async {
    final generation = _signGeneration;
    final recordingDuration = _signClipDuration ?? Duration.zero;
    _signClipDuration = null;
    _signRecordingStartedAt = null;

    if (!signCameraTestModeEnabled &&
        recordingDuration <
            SignCaptureConfig.minRecordingDuration -
                const Duration(milliseconds: 300)) {
      if (!mounted || generation != _signGeneration) {
        return;
      }
      setState(() {
        _signPhase = SignFlowPhase.recording;
        _returnToSignPreview();
      });
      _showSignMessage(widget.uiCopy.signRecordingTooShortLabel);
      return;
    }

    if (!signCameraTestModeEnabled &&
        recordingDuration >
            SignCaptureConfig.maxRecordingDuration +
                const Duration(milliseconds: 500)) {
      if (!mounted || generation != _signGeneration) {
        return;
      }
      setState(() {
        _signPhase = SignFlowPhase.recording;
        _returnToSignPreview();
      });
      _showSignMessage(widget.uiCopy.signRecordingTooLargeLabel);
      return;
    }

    if (!signCameraTestModeEnabled) {
      final videoFile = File(videoPath);
      if (!await videoFile.exists()) {
        if (!mounted || generation != _signGeneration) {
          return;
        }
        setState(() {
          _signPhase = SignFlowPhase.recording;
          _returnToSignPreview();
        });
        _showSignMessage(widget.uiCopy.signCaptureFailedLabel);
        return;
      }
      final videoBytes = await videoFile.length();
      debugPrint(
        '[SignBridge/SignCapture] clip ${recordingDuration.inMilliseconds}ms, '
        '${(videoBytes / (1024 * 1024)).toStringAsFixed(2)} MB → worker',
      );
      if (videoBytes < 1024) {
        if (!mounted || generation != _signGeneration) {
          return;
        }
        setState(() {
          _signPhase = SignFlowPhase.recording;
          _returnToSignPreview();
        });
        _showSignMessage(widget.uiCopy.signRecordingEmptyLabel);
        return;
      }
      if (videoBytes > SignCaptureConfig.maxUploadBytes) {
        if (!mounted || generation != _signGeneration) {
          return;
        }
        setState(() {
          _signPhase = SignFlowPhase.recording;
          _returnToSignPreview();
        });
        _showSignMessage(widget.uiCopy.signRecordingTooLargeLabel);
        return;
      }
    }

    setState(() => _signPhase = SignFlowPhase.analyzing);
    try {
      final result = await widget.signCaptureService.analyzeRecording(
        videoPath: videoPath,
        languageCode: widget.selectedLanguageCode,
        recordingDuration: recordingDuration,
        conversationContext: _heardForSignFlow?.fullTranscript,
      );
      if (!mounted || generation != _signGeneration) {
        return;
      }
      setState(() {
        _signResult = result;
        _signPhase = SignFlowPhase.spoken;
        _sessionPhase = TalkSessionPhase.stopped;
      });
      debugPrint(
        '[SignBridge/SignCapture] model: ${result.modelUsed ?? 'unknown'}',
      );
      debugPrint(
        '[SignBridge/Sign] Spoken text (${recordingDuration.inMilliseconds}ms clip): ${result.text}',
      );
      _scheduleSignSpeechAfterTextShown(result, generation);
    } on Object catch (error) {
      if (!mounted || generation != _signGeneration) {
        return;
      }
      debugPrint('Sign analysis failed: $error');
      setState(() {
        _signPhase = SignFlowPhase.recording;
        _returnToSignPreview();
      });
      _showSignError(error);
    }
  }

  /// Shows sign-flow snackbars with user-friendly messages for worker/Gemini errors.
  void _showSignError(Object error) {
    final message = SignCaptureErrorMapper.userMessage(error, widget.uiCopy);
    final duration = SignCaptureErrorMapper.snackbarDuration(error);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSignMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Shows gloss + spoken text on screen first, then plays TTS.
  void _scheduleSignSpeechAfterTextShown(
    SignCaptureResult result,
    int signGeneration,
  ) {
    final speakGeneration = ++_signSpeakGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted ||
          signGeneration != _signGeneration ||
          speakGeneration != _signSpeakGeneration) {
        return;
      }
      // Brief pause so the user reads captured signs and text before audio.
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (!mounted ||
          signGeneration != _signGeneration ||
          speakGeneration != _signSpeakGeneration) {
        return;
      }
      if (_signPhase != SignFlowPhase.spoken ||
          _signResult?.text != result.text) {
        return;
      }
      await _speakSignResult(result);
    });
  }

  Future<void> _speakSignResult(SignCaptureResult result) async {
    if (!result.hasText) {
      return;
    }
    await widget.translateService.cancelListening();
    await widget.phraseSpeechService.speak(
      result.text,
      widget.selectedLanguageCode,
    );
  }

  Future<void> _replaySpoken() async {
    final result = _signResult;
    if (result == null) {
      return;
    }
    await _speakSignResult(result);
  }

  Future<void> _startListening() async {
    if (_listenInFlight ||
        _isSignFlowActive ||
        (_sessionPhase != TalkSessionPhase.idle &&
            _sessionPhase != TalkSessionPhase.stopped)) {
      return;
    }

    final generation = ++_listenGeneration;

    final micGranted = await microphonePermissionRequester();
    if (!micGranted) {
      if (mounted) {
        _showListenError(widget.uiCopy.micPermissionRequiredLabel);
      }
      return;
    }

    final speechGranted = await speechPermissionRequester();
    if (!speechGranted) {
      if (mounted) {
        _showListenError(widget.uiCopy.listenStartFailedLabel);
      }
      return;
    }

    if (!mounted || generation != _listenGeneration) {
      return;
    }

    setState(() {
      _listenInFlight = true;
      _sessionPhase = TalkSessionPhase.listening;
      _listenResult = null;
      _audioLevel = 0;
      _signPulse = 0;
    });
    _resetLiveGlossState();

    await _listenSubscription?.cancel();
    _listenSubscription = null;
    await _listenErrorSubscription?.cancel();
    _listenErrorSubscription = null;
    await _audioLevelSubscription?.cancel();
    _audioLevelSubscription = null;

    await widget.translateService.prepareListening(widget.selectedLanguageCode);

    if (!mounted || generation != _listenGeneration) {
      return;
    }

    _listenSubscription = widget.translateService.listenUpdates().listen(
      (update) => _onListenUpdate(update, generation),
    );

    _listenErrorSubscription = widget.translateService.listenErrors().listen(
      (message) => unawaited(_handleListenSessionError(generation, message)),
    );

    _audioLevelSubscription = widget.translateService
        .audioLevelUpdates()
        .listen((level) {
          if (!mounted || generation != _listenGeneration) {
            return;
          }
          setState(() => _audioLevel = level);
        });

    final started = await widget.translateService.activateListening();

    if (!mounted || generation != _listenGeneration) {
      return;
    }

    if (!started) {
      await _endListenSession(
        generation: generation,
        message: widget.uiCopy.listenStartFailedLabel,
      );
      return;
    }
  }

  Future<void> _handleListenSessionError(int generation, String message) async {
    if (!mounted || generation != _listenGeneration) {
      return;
    }
    await _endListenSession(generation: generation, message: message);
  }

  Future<void> _endListenSession({
    required int generation,
    required String message,
  }) async {
    _cancelSessionTimers();
    _listenSubscription?.cancel();
    _listenSubscription = null;
    _listenErrorSubscription?.cancel();
    _listenErrorSubscription = null;
    _stopAudioLevelSubscription();
    await widget.translateService.cancelListening();
    if (!mounted || generation != _listenGeneration) {
      return;
    }
    setState(() {
      _listenInFlight = false;
      _sessionPhase = TalkSessionPhase.idle;
      _listenResult = null;
    });
    _showListenError(message);
  }

  void _showListenError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _onListenUpdate(TalkListenUpdate update, int generation) {
    if (!mounted || generation != _listenGeneration) {
      return;
    }

    final previousTokenId = _listenResult?.signTokenId;
    setState(() {
      _listenInFlight = false;
      _listenResult = _listenResultForAvatar(update.toResult());
      if (_cloudGlossWord != null &&
          previousTokenId != _listenResult?.signTokenId) {
        _signPulse++;
      }
    });

    if (_sessionPhase != TalkSessionPhase.listening) {
      return;
    }

    final caption = _normalizeGlossCaption(update.fullTranscript);
    if (caption.isNotEmpty && _needsGlossRefresh(caption)) {
      _scheduleLiveGlossUpdate();
    }

    if (update.isFinal && caption.isEmpty) {
      unawaited(_handleNoSpeechDetected(generation));
    }
  }

  /// Keeps transcript live while the avatar waits for cloud gloss.
  TalkListenResult _listenResultForAvatar(TalkListenResult raw) {
    if (_cloudGlossWord != null && _listenResult != null) {
      return raw.copyWith(
        signingWord: _listenResult!.signingWord,
        signTokenId: _listenResult!.signTokenId,
        signSequence: _listenResult!.signSequence,
        signSystem: _listenResult!.signSystem,
      );
    }

    final system = SignLanguageSystem.forSpokenLanguage(
      widget.selectedLanguageCode,
    );
    return raw.copyWith(
      signingWord: SignToken.thinking.gloss,
      signTokenId: SignToken.thinking.id,
      signSequence: const [],
      signSystem: system,
    );
  }

  Future<void> _handleNoSpeechDetected(int generation) async {
    _cancelSessionTimers();
    _listenSubscription?.cancel();
    _listenSubscription = null;
    _listenErrorSubscription?.cancel();
    _listenErrorSubscription = null;
    _stopAudioLevelSubscription();
    await widget.translateService.cancelListening();
    if (!mounted || generation != _listenGeneration) {
      return;
    }
    setState(() {
      _listenInFlight = false;
      _sessionPhase = TalkSessionPhase.idle;
      _listenResult = null;
    });
    _showListenError(widget.uiCopy.noSpeechDetectedLabel);
  }

  Future<void> _abortListenSessionForLanguageChange() async {
    _cancelSessionTimers();
    ++_listenGeneration;
    _listenSubscription?.cancel();
    _listenSubscription = null;
    _listenErrorSubscription?.cancel();
    _listenErrorSubscription = null;
    _stopAudioLevelSubscription();
    await widget.translateService.cancelListening();
    await widget.phraseSpeechService.stop();
    if (!mounted) {
      return;
    }
    _resetLiveGlossState();
    setState(() {
      _listenInFlight = false;
      _sessionPhase = TalkSessionPhase.idle;
      _listenResult = null;
    });
  }

  Future<void> _stopListening() async {
    if (_sessionPhase == TalkSessionPhase.idle ||
        _sessionPhase == TalkSessionPhase.stopped) {
      return;
    }
    if (_stopInFlight) {
      return;
    }

    setState(() => _stopInFlight = true);

    _cancelSessionTimers();
    final generation = ++_listenGeneration;
    _listenSubscription?.cancel();
    _listenSubscription = null;
    _listenErrorSubscription?.cancel();
    _listenErrorSubscription = null;
    _stopAudioLevelSubscription();

    final TalkListenResult result;
    if (_sessionPhase == TalkSessionPhase.listening) {
      result = await widget.translateService.stopListening(
        widget.selectedLanguageCode,
      );
    } else {
      result =
          _listenResult ??
          TalkListenResult.empty(
            languageCode: widget.selectedLanguageCode,
            elapsed: Duration.zero,
          );
    }
    await widget.translateService.cancelListening();

    if (!mounted || generation != _listenGeneration) {
      return;
    }

    setState(() {
      _listenInFlight = false;
      _stopInFlight = false;
      _listenResult = _listenResultForAvatar(result);
      _sessionPhase = TalkSessionPhase.stopped;
    });
    if (result.hasTranscript) {
      _cancelLiveGlossDebounce();
      final caption = _normalizeGlossCaption(result.fullTranscript);
      if (_needsGlossRefresh(caption)) {
        unawaited(_refreshLiveGloss());
      }
    }
  }

  void _scheduleLiveGlossUpdate() {
    final result = _listenResult;
    if (result == null || !result.hasTranscript) {
      return;
    }
    final caption = _normalizeGlossCaption(result.fullTranscript);
    if (!_needsGlossRefresh(caption)) {
      return;
    }

    final delay = _glossScheduleDelay(caption);
    _cancelLiveGlossDebounce();
    _liveGlossDebounceTimer = Timer(delay, () {
      _liveGlossDebounceTimer = null;
      unawaited(_refreshLiveGloss());
    });
  }

  /// Wait briefly for STT to settle before glossing.
  Duration _glossScheduleDelay(String caption) {
    if (_accumulatedGlossTokens.isEmpty && !_cloudGlossInFlight) {
      return const Duration(milliseconds: 300);
    }
    return const Duration(milliseconds: 500);
  }

  Future<void> _refreshLiveGloss() async {
    final result = _listenResult;
    if (result == null || !result.hasTranscript) {
      return;
    }

    final targetCaption = _normalizeGlossCaption(result.fullTranscript);
    final delta = _glossCaptionDelta(targetCaption);
    if (delta == null) {
      return;
    }
    if (_cloudGlossInFlight && targetCaption == _glossInFlightEndCaption) {
      return;
    }

    final generation = ++_glossRequestGeneration;
    _glossInFlightEndCaption = targetCaption;

    setState(() => _cloudGlossInFlight = true);
    try {
      final system = SignLanguageSystem.forSpokenLanguage(
        widget.selectedLanguageCode,
      );
      final jobId = DateTime.now().millisecondsSinceEpoch.toString();
      final signLanguage = system.label;

      final glossResult = await _requestGlossWithFallback(
        jobId: jobId,
        caption: delta,
        signLanguage: signLanguage,
        languageCode: widget.selectedLanguageCode,
        spokenLanguage: _selectedLanguage?.label,
      );
      if (!mounted || generation != _glossRequestGeneration) {
        return;
      }
      if (glossResult.tokens.isNotEmpty) {
        _insertGlossTokens(_accumulatedGlossTokens.length, glossResult.tokens);
        _publishGlossState(
          system: system,
          result: result,
          stitchedVideoUrl: glossResult.stitchedVideoUrl,
        );
        _lastFetchedGlossCaption = targetCaption;
      }
    } finally {
      if (mounted && generation == _glossRequestGeneration) {
        _glossInFlightEndCaption = null;
        setState(() => _cloudGlossInFlight = false);
        if (_sessionPhase == TalkSessionPhase.listening) {
          final latestCaption = _normalizeGlossCaption(
            _listenResult?.fullTranscript ?? '',
          );
          if (_needsGlossRefresh(latestCaption)) {
            _scheduleLiveGlossUpdate();
          }
        }
      }
    }
  }

  Future<({List<String> tokens, String? stitchedVideoUrl})>
      _requestGlossWithFallback({
    required String jobId,
    required String caption,
    required String signLanguage,
    required String languageCode,
    String? spokenLanguage,
  }) async {
    if (CloudflareGlossConfig.isConfigured &&
        widget.glossService is CloudflareGlossService) {
      try {
        final detail = await (widget.glossService as CloudflareGlossService)
            .requestGlossDetail(
          jobId: jobId,
          caption: caption,
          signLanguage: signLanguage,
          languageCode: languageCode,
          spokenLanguage: spokenLanguage,
          priorGlossSequence: List<String>.from(_accumulatedGlossTokens),
        );
        if (detail.glossSequence.isNotEmpty) {
          if (await _cloudGlossMapsToVideos(detail.glossSequence, signLanguage)) {
            return (
              tokens: detail.glossSequence,
              stitchedVideoUrl: detail.stitchedVideoUrl,
            );
          }
          debugPrint(
            '[SignBridge/Gloss] Cloud ISL gloss has no video mapping; using on-device rules',
          );
        } else {
          debugPrint(
            '[SignBridge/Gloss] Cloud returned empty gloss; using on-device rules',
          );
        }
      } on Object catch (error) {
        debugPrint('[SignBridge/Gloss] Cloud failed ($error); using on-device rules');
      }
    }

    debugPrint('[SignBridge/Gloss] On-device gloss (not Gemini)');
    final tokens = await widget.localGlossService.requestGloss(
      jobId: jobId,
      caption: caption,
      signLanguage: signLanguage,
      languageCode: languageCode,
      spokenLanguage: spokenLanguage,
    );
    return (tokens: tokens, stitchedVideoUrl: null);
  }

  Future<bool> _cloudGlossMapsToVideos(
    List<String> tokens,
    String signLanguage,
  ) async {
    if (!signLanguage.toUpperCase().contains('ISL')) {
      return true;
    }
    await SignAssetCatalog.ensureLoaded();
    final system = SignLanguageSystem.isl;
    final sequence = GlossSequenceMapper.tokensFor(
      glossSequence: tokens,
      system: system,
    );
    return SignAssetCatalog.playbackClipsForSequence(sequence, system).isNotEmpty;
  }

  void _insertGlossTokens(int index, List<String> glossTokens) {
    var insertAt = index.clamp(0, _accumulatedGlossTokens.length);
    for (final gloss in glossTokens) {
      final token = gloss.trim();
      if (token.isEmpty) {
        continue;
      }
      final previous = insertAt == 0
          ? null
          : _accumulatedGlossTokens[insertAt - 1];
      if (previous == token) {
        continue;
      }
      _accumulatedGlossTokens.insert(insertAt, token);
      insertAt++;
    }
  }

  void _publishGlossState({
    required SignLanguageSystem system,
    required TalkListenResult result,
    String? stitchedVideoUrl,
  }) {
    final sequence = GlossSequenceMapper.tokensFor(
      glossSequence: _accumulatedGlossTokens,
      system: system,
    );
    setState(() {
      _cloudGlossWord = _accumulatedGlossTokens.join(' ');
      if (stitchedVideoUrl != null && stitchedVideoUrl.trim().isNotEmpty) {
        _stitchedGlossVideoUrl = stitchedVideoUrl.trim();
      }
      _listenResult = _listenResultForAvatar(result).copyWith(
        signingWord: _cloudGlossWord,
        signSequence: sequence,
        signTokenId: sequence.isNotEmpty ? sequence.last.id : result.signTokenId,
        signSystem: system,
      );
      _signPulse++;
    });
  }

  Future<void> _clearHistory() async {
    _cancelSessionTimers();
    ++_listenGeneration;
    _listenSubscription?.cancel();
    _listenSubscription = null;
    _listenErrorSubscription?.cancel();
    _listenErrorSubscription = null;
    _stopAudioLevelSubscription();
    if (!mounted) {
      return;
    }
    setState(() {
      _listenInFlight = false;
      _sessionPhase = TalkSessionPhase.idle;
      _listenResult = null;
      _resetLiveGlossState();
      _signGeneration++;
      _signSpeakGeneration++;
      _signPhase = SignFlowPhase.idle;
      _signResult = null;
      _signRecordingActive = false;
      _resetSignCaptureState();
    });
    unawaited(widget.translateService.cancelListening());
  }

  bool get _isRecordingSession {
    return switch (_sessionPhase) {
      TalkSessionPhase.listening ||
      TalkSessionPhase.heard ||
      TalkSessionPhase.signing => true,
      TalkSessionPhase.idle || TalkSessionPhase.stopped => false,
    };
  }

  bool get _showListenWaveform => _isRecordingSession;

  _TalkControlsMode get _controlsMode {
    return switch (_signPhase) {
      SignFlowPhase.recording when _signRecordingActive =>
        _TalkControlsMode.signRecordingActive,
      SignFlowPhase.recording => _TalkControlsMode.signRecordingPreview,
      SignFlowPhase.analyzing => _TalkControlsMode.signAnalyzing,
      SignFlowPhase.spoken => _TalkControlsMode.signSpoken,
      SignFlowPhase.idle => switch (_sessionPhase) {
        TalkSessionPhase.idle => _TalkControlsMode.idle,
        TalkSessionPhase.stopped => _TalkControlsMode.stopped,
        TalkSessionPhase.listening ||
        TalkSessionPhase.heard ||
        TalkSessionPhase.signing => _TalkControlsMode.listenRecording,
      },
    };
  }

  Widget _buildSessionBody() {
    if (_signPhase == SignFlowPhase.recording) {
      return TalkSignRecordingContent(
        key: const Key('talk_sign_recording_content'),
        uiCopy: widget.uiCopy,
        heardResult: _heardForSignFlow,
        isRecording: _signRecordingActive,
        statusLabel: _signRecordingStatusLabel,
        canStartRecording: !_signRecordingActive,
        onStartRecording: _onSignRecordTap,
        onRecordingStopped: _onSignRecordingStopped,
        onCameraError: (message) {
          debugPrint('[SignBridge/SignCapture] camera error: $message');
          if (message.contains('Recording did not start')) {
            setState(() => _returnToSignPreview());
            _showSignMessage(widget.uiCopy.tapToRecordSign);
            return;
          }
          _showSignMessage(widget.uiCopy.signCaptureFailedLabel);
          setState(() {
            _signPhase = SignFlowPhase.idle;
            _returnToSignPreview();
          });
        },
      );
    }
    if (_signPhase == SignFlowPhase.analyzing) {
      return TalkSignAnalyzingContent(
        key: const Key('talk_sign_analyzing_content'),
        uiCopy: widget.uiCopy,
        heardResult: _heardForSignFlow,
      );
    }
    if (_signPhase == SignFlowPhase.spoken && _signResult != null) {
      return TalkSignSpokenContent(
        key: const Key('talk_sign_spoken_content'),
        uiCopy: widget.uiCopy,
        heardResult: _heardForSignFlow,
        signResult: _signResult!,
        onReplay: _replaySpoken,
      );
    }

    return switch (_sessionPhase) {
      TalkSessionPhase.idle => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            widget.uiCopy.emptyStateMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Klavika',
              fontWeight: FontWeight.w400,
              fontSize: AppTypography.talkEmptyText,
              height: AppTypography.talkEmptyLineHeight,
              color: AppColors.talkMutedText,
            ),
          ),
        ),
      ),
      TalkSessionPhase.listening => TalkListeningContent(
        uiCopy: widget.uiCopy,
        liveResult: _listenResult,
        signPulse: _signPulse,
        isRefreshingGloss: _cloudGlossInFlight,
        cloudGlossWord: _cloudGlossWord,
        stitchedGlossVideoUrl: _stitchedGlossVideoUrl,
      ),
      TalkSessionPhase.heard when _listenResult != null => TalkHeardContent(
        key: const Key('talk_heard_content'),
        uiCopy: widget.uiCopy,
        result: _listenResult!,
        signPulse: _signPulse,
      ),
      TalkSessionPhase.signing when _listenResult != null => TalkSigningContent(
        key: const Key('talk_signing_content'),
        uiCopy: widget.uiCopy,
        result: _listenResult!,
        signPulse: _signPulse,
      ),
      TalkSessionPhase.stopped when _listenResult != null => TalkStoppedContent(
        key: const Key('talk_stopped_content'),
        uiCopy: widget.uiCopy,
        result: _listenResult!,
        signPulse: _signPulse,
        isRefreshingGloss: _cloudGlossInFlight,
        cloudGlossWord: _cloudGlossWord,
        stitchedGlossVideoUrl: _stitchedGlossVideoUrl,
      ),
      TalkSessionPhase.heard => const SizedBox.shrink(),
      TalkSessionPhase.signing => const SizedBox.shrink(),
      TalkSessionPhase.stopped => const SizedBox.shrink(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final content = _content;
    if (content == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final isActiveSession =
        _sessionPhase != TalkSessionPhase.idle || _isSignFlowActive;

    return SafeArea(
      bottom: false,
      child: Stack(
        children: [
          if (_languageMenuOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _languageMenuOpen = false),
                child: Container(color: Colors.transparent),
              ),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenPaddingH,
                  AppSpacing.screenPaddingTop,
                  AppSpacing.screenPaddingH,
                  AppSpacing.headerPaddingBottom,
                ),
                child: _HomeHeader(
                  selectedLanguage: _selectedLanguage,
                  languageMenuOpen: _languageMenuOpen,
                  onLanguageTap: () =>
                      setState(() => _languageMenuOpen = !_languageMenuOpen),
                  onMenuTap: widget.onMenuTap,
                ),
              ),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: isActiveSession
                        ? AppColors.talkScreenBackground
                        : null,
                    gradient: isActiveSession
                        ? null
                        : const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppColors.white,
                              AppColors.talkBackgroundGradientEnd,
                            ],
                            stops: [0.55, 1],
                          ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.talkContentPaddingH,
                      AppSpacing.talkContentPaddingTop,
                      AppSpacing.talkContentPaddingH,
                      AppSpacing.talkContentPaddingBottom,
                    ),
                    child: Column(
                      children: [
                        Expanded(child: _buildSessionBody()),
                        if (_showListenWaveform) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.talkSessionWaveformPaddingV,
                            ),
                            child: TalkAudioWaveform(
                              key: const Key('talk_audio_waveform'),
                              level: _audioLevel,
                              live: _sessionPhase == TalkSessionPhase.listening,
                            ),
                          ),
                          const SizedBox(
                            height: AppSpacing.talkSessionWaveformToButtons,
                          ),
                        ],
                        if (_showClearHistory) ...[
                          TalkClearHistoryButton(
                            label: widget.uiCopy.clearHistoryLabel,
                            onTap: _clearHistory,
                          ),
                          const SizedBox(
                            height: AppSpacing.talkSessionStoppedControlsGap,
                          ),
                        ],
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: isActiveSession
                                ? AppSpacing.talkContentPaddingBottom
                                : AppSpacing.talkContentInnerPaddingBottom,
                          ),
                          child: _TalkActionButtons(
                            uiCopy: widget.uiCopy,
                            mode: _controlsMode,
                            onListenTap: _startListening,
                            onStopTap: _stopListening,
                            onSignTap: _startSignRecording,
                            onSignRecordTap: _onSignRecordTap,
                            onSignStopTap: _onSignStopTap,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_languageMenuOpen)
            Positioned(
              top: 72,
              right: AppSpacing.talkContentPaddingH,
              child: _LanguageMenu(
                languages: content.languages,
                selectedCode: widget.selectedLanguageCode,
                onSelected: (code) {
                  setState(() => _languageMenuOpen = false);
                  widget.onLanguageChanged(code);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.selectedLanguage,
    required this.languageMenuOpen,
    required this.onLanguageTap,
    required this.onMenuTap,
  });

  final HomeLanguage? selectedLanguage;
  final bool languageMenuOpen;
  final VoidCallback onLanguageTap;
  final VoidCallback onMenuTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image.asset(
          'assets/home/app_logo.png',
          width: AppTypography.headerLogo,
          height: AppTypography.headerLogo,
        ),
        const SizedBox(width: AppSpacing.headerLogoGap),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SignBridge',
                style: TextStyle(
                  fontFamily: 'Klavika',
                  fontWeight: FontWeight.w700,
                  fontSize: AppTypography.headerTitle,
                  height: 1.2,
                  color: AppColors.splashBlue,
                ),
              ),
              Text(
                'by adesso',
                style: TextStyle(
                  fontSize: AppTypography.headerSubtitle,
                  height: 1.2,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: onLanguageTap,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.langPillPaddingH,
              vertical: AppSpacing.langPillPaddingV,
            ),
            decoration: BoxDecoration(
              color: AppColors.langPillBackground,
              borderRadius: BorderRadius.circular(AppSpacing.langPillRadius),
              border: languageMenuOpen
                  ? Border.all(color: AppColors.splashBlue, width: 1)
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/home/icon_globe.png',
                  width: AppTypography.langGlobe,
                  height: AppTypography.langGlobe,
                ),
                const SizedBox(width: AppSpacing.langGlobeToText),
                Text(
                  selectedLanguage?.code ?? 'ENG',
                  style: const TextStyle(
                    fontSize: AppTypography.langText,
                    fontWeight: FontWeight.w600,
                    color: AppColors.splashBlue,
                  ),
                ),
                const SizedBox(width: AppSpacing.langTextToChevron),
                Icon(
                  languageMenuOpen
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: AppTypography.langGlobe,
                  color: AppColors.splashBlue,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.headerMenuGap),
        GestureDetector(
          key: const Key('home_menu_button'),
          onTap: onMenuTap,
          child: Image.asset(
            'assets/home/icon_menu.png',
            width: AppTypography.menuIconW,
            height: AppTypography.menuIconH,
            fit: BoxFit.contain,
          ),
        ),
      ],
    );
  }
}

class _LanguageMenu extends StatelessWidget {
  const _LanguageMenu({
    required this.languages,
    required this.selectedCode,
    required this.onSelected,
  });

  final List<HomeLanguage> languages;
  final String selectedCode;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(16),
      color: AppColors.white,
      child: Container(
        width: 180,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.phraseBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final language in languages)
              InkWell(
                onTap: () => onSelected(language.code),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  color: language.code == selectedCode
                      ? AppColors.lightBlue
                      : Colors.transparent,
                  child: Text(
                    language.label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: language.code == selectedCode
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: language.code == selectedCode
                          ? AppColors.splashBlue
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

enum _TalkControlsMode {
  idle,
  listenRecording,
  signRecordingPreview,
  signRecordingActive,
  signAnalyzing,
  stopped,
  signSpoken,
}

class _TalkActionButtons extends StatelessWidget {
  const _TalkActionButtons({
    required this.uiCopy,
    required this.mode,
    required this.onListenTap,
    required this.onStopTap,
    required this.onSignTap,
    required this.onSignRecordTap,
    required this.onSignStopTap,
  });

  final HomeUiCopy uiCopy;
  final _TalkControlsMode mode;
  final VoidCallback onListenTap;
  final VoidCallback onStopTap;
  final VoidCallback onSignTap;
  final VoidCallback onSignRecordTap;
  final VoidCallback onSignStopTap;

  @override
  Widget build(BuildContext context) {
    if (mode == _TalkControlsMode.listenRecording) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TalkActionButton(
            key: const Key('talk_stop_button'),
            backgroundColor: AppColors.talkStopRed,
            icon: Icons.mic_off_outlined,
            label: uiCopy.tapToStop,
            onTap: onStopTap,
          ),
          Opacity(
            opacity: AppSpacing.talkSessionSignMutedOpacity,
            child: _TalkActionButton(
              backgroundColor: AppColors.splashBlue,
              shadowColor: AppColors.talkButtonShadow,
              icon: Icons.videocam_outlined,
              label: uiCopy.tapToSign,
              onTap: () {},
            ),
          ),
        ],
      );
    }

    if (mode == _TalkControlsMode.signRecordingPreview) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Opacity(
            opacity: AppSpacing.talkSessionSignMutedOpacity,
            child: _TalkActionButton(
              backgroundColor: AppColors.splashBlue,
              shadowColor: AppColors.talkButtonShadow,
              icon: Icons.mic_none_outlined,
              label: uiCopy.tapToListen,
              onTap: () {},
            ),
          ),
          _TalkActionButton(
            key: const Key('talk_sign_record_button'),
            backgroundColor: AppColors.splashBlue,
            shadowColor: AppColors.talkButtonShadow,
            icon: Icons.videocam_outlined,
            label: uiCopy.tapToRecordSign,
            onTap: onSignRecordTap,
          ),
        ],
      );
    }

    if (mode == _TalkControlsMode.signRecordingActive) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Opacity(
            opacity: AppSpacing.talkSessionSignMutedOpacity,
            child: _TalkActionButton(
              backgroundColor: AppColors.splashBlue,
              shadowColor: AppColors.talkButtonShadow,
              icon: Icons.mic_none_outlined,
              label: uiCopy.tapToListen,
              onTap: () {},
            ),
          ),
          _TalkActionButton(
            key: const Key('talk_sign_stop_button'),
            backgroundColor: AppColors.talkStopRed,
            icon: Icons.stop_circle_outlined,
            label: uiCopy.tapToStop,
            onTap: onSignStopTap,
          ),
        ],
      );
    }

    if (mode == _TalkControlsMode.signAnalyzing) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Opacity(
            opacity: AppSpacing.talkSessionSignMutedOpacity,
            child: _TalkActionButton(
              backgroundColor: AppColors.splashBlue,
              shadowColor: AppColors.talkButtonShadow,
              icon: Icons.mic_none_outlined,
              label: uiCopy.tapToListen,
              onTap: () {},
            ),
          ),
          Opacity(
            opacity: AppSpacing.talkSessionSignMutedOpacity,
            child: _TalkActionButton(
              backgroundColor: AppColors.splashBlue,
              shadowColor: AppColors.talkButtonShadow,
              icon: Icons.videocam_outlined,
              label: uiCopy.tapToSign,
              onTap: () {},
            ),
          ),
        ],
      );
    }

    if (mode == _TalkControlsMode.stopped ||
        mode == _TalkControlsMode.signSpoken) {
      return Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TalkActionButton(
              key: const Key('talk_listen_button'),
              backgroundColor: AppColors.splashBlue,
              shadowColor: AppColors.talkButtonShadow,
              icon: Icons.mic_none_outlined,
              label: uiCopy.tapToListen,
              onTap: onListenTap,
            ),
            const SizedBox(width: AppSpacing.talkButtonGap),
            _TalkActionButton(
              key: const Key('talk_sign_button'),
              backgroundColor: AppColors.splashBlue,
              shadowColor: AppColors.talkButtonShadow,
              icon: Icons.videocam_outlined,
              label: uiCopy.tapToSign,
              onTap: onSignTap,
            ),
          ],
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _TalkActionButton(
            key: const Key('talk_listen_button'),
            backgroundColor: AppColors.splashBlue,
            shadowColor: AppColors.talkButtonShadow,
            icon: Icons.mic_none_outlined,
            label: uiCopy.tapToListen,
            onTap: onListenTap,
          ),
        ),
        const SizedBox(width: AppSpacing.talkButtonGapMin),
        Expanded(
          child: _TalkActionButton(
            key: const Key('talk_sign_button'),
            backgroundColor: AppColors.splashBlue,
            shadowColor: AppColors.talkButtonShadow,
            icon: Icons.videocam_outlined,
            label: uiCopy.tapToSign,
            onTap: onSignTap,
          ),
        ),
      ],
    );
  }
}

class _TalkActionButton extends StatelessWidget {
  const _TalkActionButton({
    super.key,
    required this.backgroundColor,
    this.shadowColor = AppColors.talkButtonShadow,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Color backgroundColor;
  final Color shadowColor;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            width: AppTypography.talkButtonSize,
            height: AppTypography.talkButtonSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: backgroundColor,
              boxShadow: [
                BoxShadow(
                  color: shadowColor,
                  blurRadius: 16,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              icon,
              size: AppTypography.talkButtonIcon,
              color: AppColors.white,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.talkButtonToLabel),
        SizedBox(
          width: AppTypography.talkButtonSize,
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            softWrap: true,
            style: const TextStyle(
              fontFamily: 'Klavika',
              fontWeight: FontWeight.w400,
              fontSize: AppTypography.talkButtonLabel,
              height: AppTypography.talkButtonLabelLineHeight,
              color: AppColors.talkMutedText,
            ),
          ),
        ),
      ],
    );
  }
}
