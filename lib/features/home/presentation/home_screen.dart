import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../../core/platform/camera_permission.dart';
import '../../../core/platform/sign_camera_test_mode.dart';
import '../../../core/platform/microphone_permission.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../services/home/home_service.dart';
import '../../../services/phrases/phrase_speech_service.dart';
import '../../../services/translate/sign_capture_service.dart';
import '../../../services/translate/translate_service.dart';
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
    required this.selectedLanguageCode,
    required this.uiCopy,
    required this.onMenuTap,
    required this.onLanguageChanged,
  });

  final HomeService homeService;
  final TranslateService translateService;
  final SignCaptureService signCaptureService;
  final PhraseSpeechService phraseSpeechService;
  final String selectedLanguageCode;
  final HomeUiCopy uiCopy;
  final VoidCallback onMenuTap;
  final ValueChanged<String> onLanguageChanged;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  HomeContent? _content;
  bool _languageMenuOpen = false;
  TalkSessionPhase _sessionPhase = TalkSessionPhase.idle;
  TalkListenResult? _listenResult;
  bool _listenInFlight = false;
  int _listenGeneration = 0;
  int _signPulse = 0;
  double _audioLevel = 0;
  StreamSubscription<TalkListenUpdate>? _listenSubscription;
  StreamSubscription<String>? _listenErrorSubscription;
  StreamSubscription<double>? _audioLevelSubscription;
  SignFlowPhase _signPhase = SignFlowPhase.idle;
  SignCaptureResult? _signResult;
  bool _signRecordingActive = false;
  int _signGeneration = 0;
  CameraController? _signCameraController;

  @override
  void dispose() {
    _cancelSessionTimers();
    _listenSubscription?.cancel();
    _stopAudioLevelSubscription();
    _disposeSignCamera();
    unawaited(widget.translateService.cancelListening());
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedLanguageCode != widget.selectedLanguageCode &&
        _isActiveListenPhase) {
      unawaited(_abortSessionForLanguageChange());
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

  void _cancelSessionTimers() {}

  void _stopAudioLevelSubscription() {
    _audioLevelSubscription?.cancel();
    _audioLevelSubscription = null;
    _audioLevel = 0;
  }

  @override
  void initState() {
    super.initState();
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

  Future<void> _startSignRecording() async {
    if (_signPhase != SignFlowPhase.idle || _isActiveListenPhase) {
      return;
    }

    final generation = ++_signGeneration;

    if (signCameraTestModeEnabled) {
      if (!mounted || generation != _signGeneration) {
        return;
      }
      setState(() {
        _signPhase = SignFlowPhase.recording;
        _signRecordingActive = true;
      });
      return;
    }

    final cameraGranted = await cameraPermissionRequester();
    if (!cameraGranted) {
      if (mounted) {
        _showListenError(widget.uiCopy.cameraPermissionRequiredLabel);
      }
      return;
    }
    if (!mounted || generation != _signGeneration) {
      return;
    }
    setState(() {
      _signPhase = SignFlowPhase.recording;
      _signRecordingActive = true;
    });
  }

  Future<void> _stopSignAndAnalyze() async {
    if (_signPhase != SignFlowPhase.recording) {
      return;
    }

    if (signCameraTestModeEnabled) {
      await _analyzeSignVideo('mock-sign-capture.mp4');
      return;
    }

    setState(() => _signRecordingActive = false);
  }

  Future<void> _analyzeSignVideo(String videoPath) async {
    final generation = _signGeneration;
    setState(() => _signPhase = SignFlowPhase.analyzing);
    try {
      final result = await widget.signCaptureService.analyzeRecording(
        videoPath: videoPath,
        languageCode: widget.selectedLanguageCode,
      );
      if (!mounted || generation != _signGeneration) {
        return;
      }
      setState(() {
        _signResult = result;
        _signPhase = SignFlowPhase.spoken;
        _sessionPhase = TalkSessionPhase.stopped;
      });
      await _speakSignResult(result);
    } on Object {
      if (!mounted || generation != _signGeneration) {
        return;
      }
      _showListenError(widget.uiCopy.signCaptureFailedLabel);
      setState(() => _signPhase = SignFlowPhase.idle);
    }
  }

  Future<void> _speakSignResult(SignCaptureResult result) async {
    if (!result.hasText) {
      return;
    }
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

  void _disposeSignCamera() {
    _signCameraController?.dispose();
    _signCameraController = null;
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
    final nextResult = update.toResult();
    setState(() {
      _listenInFlight = false;
      _listenResult = nextResult;
      if (previousTokenId != nextResult.signTokenId) {
        _signPulse++;
      }
    });

    if (_sessionPhase != TalkSessionPhase.listening) {
      return;
    }

    if (update.isFinal && update.fullTranscript.trim().isEmpty) {
      unawaited(_handleNoSpeechDetected(generation));
    }
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

  Future<void> _abortSessionForLanguageChange() async {
    _cancelSessionTimers();
    ++_listenGeneration;
    _listenSubscription?.cancel();
    _listenSubscription = null;
    _listenErrorSubscription?.cancel();
    _listenErrorSubscription = null;
    _stopAudioLevelSubscription();
    await widget.translateService.cancelListening();
    if (!mounted) {
      return;
    }
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
      _listenResult = result;
      _sessionPhase = TalkSessionPhase.stopped;
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
    _disposeSignCamera();
    if (!mounted) {
      return;
    }
    setState(() {
      _listenInFlight = false;
      _sessionPhase = TalkSessionPhase.idle;
      _listenResult = null;
      _signGeneration++;
      _signPhase = SignFlowPhase.idle;
      _signResult = null;
      _signRecordingActive = false;
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

  _TalkControlsMode get _controlsMode {
    return switch (_signPhase) {
      SignFlowPhase.recording => _TalkControlsMode.signRecording,
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
        onRecordingReady: (controller) => _signCameraController = controller,
        onRecordingStopped: _analyzeSignVideo,
        onCameraError: (message) {
          _showListenError(widget.uiCopy.signCaptureFailedLabel);
          setState(() => _signPhase = SignFlowPhase.idle);
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
                        if (_isRecordingSession) ...[
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
                        if (_sessionPhase == TalkSessionPhase.stopped ||
                            _signPhase == SignFlowPhase.spoken) ...[
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
                            onTranslateTap: _stopSignAndAnalyze,
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
  signRecording,
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
    required this.onTranslateTap,
  });

  final HomeUiCopy uiCopy;
  final _TalkControlsMode mode;
  final VoidCallback onListenTap;
  final VoidCallback onStopTap;
  final VoidCallback onSignTap;
  final VoidCallback onTranslateTap;

  @override
  Widget build(BuildContext context) {
    if (mode == _TalkControlsMode.listenRecording) {
      return Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TalkActionButton(
              key: const Key('talk_stop_button'),
              backgroundColor: AppColors.talkStopRed,
              ringShadow: true,
              icon: Icons.mic_off_outlined,
              label: uiCopy.tapToStop,
              onTap: onStopTap,
            ),
            const SizedBox(width: AppSpacing.talkButtonGap),
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
        ),
      );
    }

    if (mode == _TalkControlsMode.signRecording) {
      return Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
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
            const SizedBox(width: AppSpacing.talkButtonGap),
            _TalkActionButton(
              key: const Key('talk_translate_button'),
              backgroundColor: AppColors.talkStopRed,
              ringShadow: true,
              icon: Icons.translate_rounded,
              label: uiCopy.tapToTranslate,
              onTap: onTranslateTap,
            ),
          ],
        ),
      );
    }

    if (mode == _TalkControlsMode.signAnalyzing) {
      return Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
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
            const SizedBox(width: AppSpacing.talkButtonGap),
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
        ),
      );
    }

    if (mode == _TalkControlsMode.stopped || mode == _TalkControlsMode.signSpoken) {
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
    this.ringShadow = false,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Color backgroundColor;
  final Color shadowColor;
  final bool ringShadow;
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
          onTap: onTap,
          child: Container(
            width: AppTypography.talkButtonSize,
            height: AppTypography.talkButtonSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: backgroundColor,
              boxShadow: ringShadow
                  ? const [
                      BoxShadow(
                        color: AppColors.talkStopRing,
                        spreadRadius: AppSpacing.talkSessionStopRing,
                        blurRadius: 0,
                      ),
                    ]
                  : [
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
        Text(
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
      ],
    );
  }
}
