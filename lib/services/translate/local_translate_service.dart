import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'audio_level_normalizer.dart';
import 'sign_gloss_mapper.dart';
import 'speech_error_mapper.dart';
import 'speech_locale_resolver.dart';
import 'speech_transcript_accumulator.dart';
import 'translate_service.dart';

final class LocalTranslateService implements TranslateService {
  LocalTranslateService({
    SpeechToText? speechToText,
    @visibleForTesting this.forceMockListening = false,
  }) : _speech = speechToText ?? SpeechToText();

  final SpeechToText _speech;

  @visibleForTesting
  final bool forceMockListening;

  StreamController<TalkListenUpdate>? _controller;
  StreamController<String>? _errorController;
  StreamController<double>? _levelController;
  TalkListenUpdate? _latestUpdate;
  DateTime? _startedAt;
  String _languageCode = 'ENG';
  String _latestWords = '';
  final SpeechTranscriptAccumulator _transcript = SpeechTranscriptAccumulator();
  String? _activeLocaleId;
  bool _isListening = false;
  bool _sessionActive = false;
  bool _autoResumeEnabled = false;
  bool _shuttingDown = false;
  bool _resumeInFlight = false;
  bool _speechEngineReady = false;
  bool _useMockFallback = false;
  Timer? _mockTimer;
  Timer? _levelMockTimer;
  int _mockWordIndex = 0;
  int _mockLevelTick = 0;
  int _listenRetryCount = 0;
  double _smoothedLevel = 0;

  static TalkListenResult _mockResult({
    required String transcript,
    required String fullTranscript,
    required String languageCode,
  }) {
    final active = SignGlossMapper.activeSign(fullTranscript, languageCode);
    final sequence = SignGlossMapper.signSequence(fullTranscript, languageCode);
    return TalkListenResult(
      transcript: transcript,
      fullTranscript: fullTranscript,
      signingWord: active.gloss,
      signTokenId: active.id,
      signSystem: active.system,
      signSequence: sequence,
      heardDuration: '00:06',
    );
  }

  static final _mockByLanguage = <String, TalkListenResult>{
    'ENG': _mockResult(
      languageCode: 'ENG',
      transcript: 'Hello, how are',
      fullTranscript: 'Hello, how are you today?',
    ),
    'ML': _mockResult(
      languageCode: 'ML',
      transcript: 'ഹലോ, സുഖമാണോ',
      fullTranscript: 'ഹലോ, സുഖമാണോ? ഇന്ന് എങ്ങനെയുണ്ട്?',
    ),
    'HI': _mockResult(
      languageCode: 'HI',
      transcript: 'नमस्ते, कैसे हैं',
      fullTranscript: 'नमस्ते, आज आप कैसे हैं?',
    ),
    'TA': _mockResult(
      languageCode: 'TA',
      transcript: 'வணக்கம், எப்படி இருக்கிறீர்கள்',
      fullTranscript: 'வணக்கம், இன்று எப்படி இருக்கிறீர்கள்?',
    ),
  };

  @override
  String get serviceName => 'translate-service';

  @override
  Future<String> getStatusMessage() async => 'Translate';

  @override
  Future<void> prepareListening(String languageCode) async {
    if (forceMockListening) {
      await _resetMockSession();
      _beginSession(languageCode);
      return;
    }

    await cancelListening();
    _beginSession(languageCode);
  }

  @override
  Future<bool> activateListening() async {
    if (forceMockListening) {
      _useMockFallback = true;
      _startMockListening();
      return true;
    }

    if (!await _speech.hasPermission) {
      return false;
    }

    final engineReady = await _ensureSpeechEngineReady();
    if (!engineReady) {
      return false;
    }

    // Use device default locale first — explicit tags can fail on some Samsung
    // recognizers. Resolved locale is used only on retry after language errors.
    return _startSpeechCapture(localeId: null);
  }

  Future<bool> _startSpeechCapture({required String? localeId}) async {
    if (_isListening) {
      await _stopCapture();
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }

    _activeLocaleId = localeId;

    try {
      // speech_to_text 7.x listen() returns Future<void>, not bool.
      await _speech.listen(
        onResult: _onSpeechResult,
        onSoundLevelChange: _onSoundLevelChange,
        listenOptions: SpeechListenOptions(
          partialResults: true,
          listenMode: ListenMode.dictation,
          localeId: localeId,
          cancelOnError: false,
          pauseFor: const Duration(seconds: 10),
          listenFor: const Duration(minutes: 30),
        ),
      );
    } on ListenFailedException {
      return false;
    }

    _isListening = true;
    _useMockFallback = false;
    if (_sessionActive) {
      _autoResumeEnabled = true;
    }
    return true;
  }

  @override
  Future<bool> startListening(String languageCode) async {
    await prepareListening(languageCode);
    return activateListening();
  }

  @override
  Stream<TalkListenUpdate> listenUpdates() {
    final controller = _controller;
    if (controller == null) {
      return const Stream.empty();
    }

    // Synchronous multi-stream so subscribers are wired before activateListening().
    return Stream<TalkListenUpdate>.multi((emitter) {
      final latest = _latestUpdate;
      if (latest != null) {
        emitter.add(latest);
      }
      final subscription = controller.stream.listen(
        emitter.add,
        onError: emitter.addError,
        onDone: emitter.close,
      );
      emitter.onCancel = subscription.cancel;
    });
  }

  @override
  Stream<String> listenErrors() {
    return _errorController?.stream ?? const Stream.empty();
  }

  @override
  Stream<double> audioLevelUpdates() {
    return _levelController?.stream ?? const Stream.empty();
  }

  @override
  Future<TalkListenResult> stopListening(String languageCode) async {
    _languageCode = languageCode;
    _autoResumeEnabled = false;
    _sessionActive = false;
    _shuttingDown = true;
    await _stopCapture(flushFinal: true);
    _shuttingDown = false;

    final elapsed = DateTime.now().difference(_startedAt ?? DateTime.now());
    if (_latestWords.trim().isEmpty) {
      return TalkListenResult.empty(
        languageCode: languageCode,
        elapsed: elapsed,
      );
    }

    return _buildResult(elapsed: elapsed);
  }

  @override
  Future<void> cancelListening() async {
    _autoResumeEnabled = false;
    _sessionActive = false;
    _shuttingDown = true;
    await _stopCapture();
    _shuttingDown = false;
    final controller = _controller;
    _controller = null;
    if (controller != null && !controller.isClosed) {
      await controller.close();
    }
    await _closeLevelStream();
    await _closeErrorStream();
    _latestWords = '';
    _transcript.reset();
    _latestUpdate = null;
    _startedAt = null;
    _autoResumeEnabled = false;
    _resumeInFlight = false;
    _useMockFallback = false;
  }

  @override
  TalkListenResult peekListenResult(String languageCode) {
    return _mockByLanguage[languageCode] ?? _mockByLanguage['ENG']!;
  }

  void _beginSession(String languageCode) {
    _languageCode = languageCode;
    _startedAt = DateTime.now();
    _latestWords = '';
    _transcript.reset();
    _sessionActive = true;
    _autoResumeEnabled = true;
    _shuttingDown = false;
    _resumeInFlight = false;
    _activeLocaleId = null;
    _mockWordIndex = 0;
    _listenRetryCount = 0;
    _latestUpdate = null;
    _controller = StreamController<TalkListenUpdate>.broadcast();
    _errorController = StreamController<String>.broadcast();
    _openLevelStream();
  }

  Future<void> _resetMockSession() async {
    _mockTimer?.cancel();
    _mockTimer = null;
    _isListening = false;
    final controller = _controller;
    _controller = null;
    if (controller != null && !controller.isClosed) {
      await controller.close();
    }
    await _closeLevelStream();
    await _closeErrorStream();
    _useMockFallback = false;
    _latestUpdate = null;
  }

  Future<bool> _ensureSpeechEngineReady() async {
    if (_speechEngineReady) {
      return true;
    }

    final initialized = await _speech.initialize(
      // Do not use androidIntentLookup: on Samsung it binds to AiAi first and
      // returns ERROR_LANGUAGE_UNAVAILABLE (13) for common English locales.
      options: [SpeechToText.androidNoBluetooth],
      debugLogging: kDebugMode,
      onStatus: _onSpeechStatus,
      onError: _onSpeechError,
    );
    _speechEngineReady = initialized;
    return initialized;
  }

  void _onSpeechStatus(String status) {
    if (!_sessionActive || _useMockFallback) {
      return;
    }

    if (status == SpeechToText.doneStatus || status == 'doneNoResult') {
      // Continuous dictation: commit this chunk, then start a fresh listen session
      // (speech_to_text issue #63 / plugin stress-test pattern).
      _transcript.finalizeOpenDraft();
      _latestWords = _transcript.live;
      if (_latestWords.trim().isNotEmpty) {
        _emitUpdate(isFinal: false);
      }
      if (status == SpeechToText.doneStatus &&
          _autoResumeEnabled &&
          _controller != null) {
        unawaited(_resumeListeningAfterPause());
        return;
      }
      if (status == 'doneNoResult' && _latestWords.trim().isEmpty) {
        _emitListenError(SpeechErrorMapper.userMessage('error_no_match'));
      }
    }
  }

  Future<void> _resumeListeningAfterPause() async {
    if (!_sessionActive ||
        !_autoResumeEnabled ||
        _useMockFallback ||
        _controller == null ||
        _resumeInFlight) {
      return;
    }
    _resumeInFlight = true;
    _isListening = false;
    _latestWords = _transcript.live;
    try {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (!_sessionActive ||
          !_autoResumeEnabled ||
          _controller == null ||
          _controller!.isClosed) {
        return;
      }

      for (var attempt = 0; attempt < 3; attempt++) {
        if (!_sessionActive ||
            !_autoResumeEnabled ||
            _controller == null ||
            _controller!.isClosed) {
          return;
        }
        final restarted = await _startSpeechCapture(localeId: _activeLocaleId);
        if (restarted) {
          if (_latestWords.trim().isNotEmpty) {
            _emitUpdate(isFinal: false);
          }
          return;
        }
        await Future<void>.delayed(const Duration(milliseconds: 180));
      }
    } finally {
      _resumeInFlight = false;
    }
  }

  void _onSpeechError(SpeechRecognitionError error) {
    if (!_sessionActive || _useMockFallback) {
      return;
    }

    if (_latestWords.trim().isNotEmpty) {
      _emitUpdate(isFinal: true);
      if (_autoResumeEnabled) {
        unawaited(_resumeListeningAfterPause());
      }
      return;
    }

    if (_shouldRetryListen(error.errorMsg)) {
      unawaited(_retrySpeechCapture(error.errorMsg));
      return;
    }

    unawaited(_stopCapture());
    _emitListenError(SpeechErrorMapper.userMessage(error.errorMsg));
  }

  bool _shouldRetryListen(String errorMsg) {
    if (_listenRetryCount >= 2) {
      return false;
    }
    return errorMsg == 'error_language_unavailable' ||
        errorMsg == 'error_language_not_supported' ||
        errorMsg == 'error_server_disconnected' ||
        errorMsg == 'error_busy';
  }

  Future<void> _retrySpeechCapture(String errorMsg) async {
    _listenRetryCount++;
    await _stopCapture();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (_controller == null || _controller!.isClosed) {
      return;
    }

    final useResolvedLocale =
        errorMsg == 'error_language_unavailable' ||
        errorMsg == 'error_language_not_supported';
    final localeId = useResolvedLocale
        ? await SpeechLocaleResolver.resolve(_speech, _languageCode)
        : null;

    final restarted = await _startSpeechCapture(localeId: localeId);
    if (!restarted) {
      _emitListenError(SpeechErrorMapper.userMessage(errorMsg));
    }
  }

  void _emitListenError(String message) {
    final controller = _errorController;
    if (controller == null || controller.isClosed) {
      return;
    }
    try {
      controller.add(message);
    } on StateError {
      // Stream closed while emitting.
    }
  }

  Future<void> _closeErrorStream() async {
    final controller = _errorController;
    _errorController = null;
    if (controller != null && !controller.isClosed) {
      await controller.close();
    }
  }

  void _onSoundLevelChange(double levelDb) {
    _emitLevel(AudioLevelNormalizer.toVisualLevel(levelDb));
  }

  void _openLevelStream() {
    _smoothedLevel = 0;
    _mockLevelTick = 0;
    final existing = _levelController;
    if (existing != null && !existing.isClosed) {
      unawaited(existing.close());
    }
    _levelController = StreamController<double>.broadcast();
    _emitLevel(0);
  }

  Future<void> _closeLevelStream() async {
    _levelMockTimer?.cancel();
    _levelMockTimer = null;
    final controller = _levelController;
    _levelController = null;
    _smoothedLevel = 0;
    if (controller != null && !controller.isClosed) {
      try {
        controller.add(0);
      } on StateError {
        // Already closed.
      }
      await controller.close();
    }
  }

  void _emitLevel(double target) {
    final controller = _levelController;
    if (controller == null || controller.isClosed) {
      return;
    }
    _smoothedLevel = AudioLevelNormalizer.smooth(
      _smoothedLevel,
      target,
      factor: 0.55,
    );
    try {
      controller.add(_smoothedLevel);
    } on StateError {
      // Stream closed while emitting.
    }
  }

  void _startMockLevelPump() {
    _levelMockTimer?.cancel();
    _mockLevelTick = 0;
    _levelMockTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (_levelController == null || _levelController!.isClosed) {
        _levelMockTimer?.cancel();
        return;
      }
      _mockLevelTick++;
      final mock = peekListenResult(_languageCode);
      final wordCount = mock.fullTranscript.split(RegExp(r'\s+')).length;
      final speaking = _mockWordIndex > 0 && _mockWordIndex < wordCount;
      final wave = math.sin(_mockLevelTick * 0.28).abs();
      final target = speaking ? 0.35 + wave * 0.55 : 0.03 + wave * 0.04;
      _emitLevel(target);
    });
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (_useMockFallback) {
      return;
    }
    if (!_sessionActive) {
      if (!(_shuttingDown && result.finalResult)) {
        return;
      }
    } else if (_shuttingDown && !result.finalResult) {
      return;
    }

    final words = result.recognizedWords.trim();
    if (words.isEmpty) {
      return;
    }

    final previousLive = _transcript.live;
    if (result.finalResult) {
      _transcript.applyFinal(words);
    } else {
      _transcript.applyPartial(words);
    }
    final nextLive = _transcript.live;
    if (nextLive.isEmpty) {
      return;
    }
    _latestWords = nextLive;
    if (nextLive != previousLive || result.finalResult) {
      _emitUpdate(isFinal: result.finalResult);
    }
  }

  void _startMockListening() {
    _isListening = true;
    final mock = peekListenResult(_languageCode);
    final words = mock.fullTranscript.split(RegExp(r'\s+'));
    _startMockLevelPump();

    _mockTimer = Timer.periodic(const Duration(milliseconds: 450), (timer) {
      if (_controller == null || _controller!.isClosed) {
        timer.cancel();
        return;
      }

      if (_mockWordIndex >= words.length) {
        timer.cancel();
        _emitUpdate(isFinal: true, overrideText: mock.fullTranscript);
        return;
      }

      _mockWordIndex++;
      final partial = words.take(_mockWordIndex).join(' ');
      _latestWords = partial;
      _emitUpdate(isFinal: false, overrideText: partial);
    });
  }

  Future<void> _stopCapture({bool flushFinal = false}) async {
    _mockTimer?.cancel();
    _mockTimer = null;
    _levelMockTimer?.cancel();
    _levelMockTimer = null;
    if (_speechEngineReady && !_useMockFallback) {
      try {
        if (_speech.isListening) {
          await _speech.stop().timeout(const Duration(seconds: 3));
        }
        if (flushFinal) {
          await Future<void>.delayed(const Duration(milliseconds: 700));
        }
        await _speech.cancel().timeout(const Duration(seconds: 3));
      } catch (_) {}
    }
    _isListening = false;
    _emitLevel(0);
  }

  void _emitUpdate({required bool isFinal, String? overrideText}) {
    final controller = _controller;
    if (controller == null || controller.isClosed) {
      return;
    }

    final text = overrideText ?? _latestWords;
    if (text.trim().isEmpty) {
      return;
    }

    final elapsed = DateTime.now().difference(_startedAt ?? DateTime.now());
    final active = SignGlossMapper.activeSign(text, _languageCode);
    final sequence = isFinal
        ? SignGlossMapper.signSequence(text, _languageCode)
        : (_latestUpdate?.signSequence ?? const []);
    final update = TalkListenUpdate(
      transcript: SignGlossMapper.liveCaption(text),
      fullTranscript: text.trim(),
      signingWord: active.gloss,
      signTokenId: active.id,
      signSystem: active.system,
      signSequence: sequence,
      isFinal: isFinal,
      elapsed: elapsed,
    );

    _latestUpdate = update;
    try {
      controller.add(update);
    } on StateError {
      // Stream closed while emitting — safe to ignore during teardown.
    }
  }

  TalkListenResult _buildResult({required Duration elapsed}) {
    final caption = SignGlossMapper.liveCaption(_latestWords);
    final active = SignGlossMapper.activeSign(_latestWords, _languageCode);
    final sequence = SignGlossMapper.signSequence(_latestWords, _languageCode);
    return TalkListenResult(
      transcript: caption,
      fullTranscript: _latestWords.trim(),
      signingWord: active.gloss,
      signTokenId: active.id,
      signSystem: active.system,
      signSequence: sequence,
      heardDuration: TalkListenResult.formatDuration(elapsed),
    );
  }
}
