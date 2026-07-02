import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../../../core/platform/sign_camera_test_mode.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

typedef SignRecordingStoppedHandler = void Function(
  String videoPath,
  Duration recordingDuration,
);

/// Controls [SignCameraRecorder] from an overlay (e.g. flip camera).
class SignCameraRecorderController extends ChangeNotifier {
  _SignCameraRecorderState? _state;
  bool _canFlipCamera = false;
  bool _isFlipping = false;

  bool get canFlipCamera => _canFlipCamera;
  bool get isFlipping => _isFlipping;

  Future<void> flipCamera() async {
    await _state?.flipCamera();
  }

  void _attach(_SignCameraRecorderState state) {
    _state = state;
    _syncFromState();
  }

  void _detach(_SignCameraRecorderState state) {
    if (_state == state) {
      _state = null;
      _setCanFlipCamera(false);
      _setFlipping(false);
    }
  }

  void _syncFromState() {
    final state = _state;
    if (state == null) {
      return;
    }
    _setCanFlipCamera(state._canFlipCamera);
    _setFlipping(state._isFlipping);
  }

  void _setCanFlipCamera(bool value) {
    if (_canFlipCamera == value) {
      return;
    }
    _canFlipCamera = value;
    notifyListeners();
  }

  void _setFlipping(bool value) {
    if (_isFlipping == value) {
      return;
    }
    _isFlipping = value;
    notifyListeners();
  }
}

/// Front-camera preview that records sign-language video to a temp file.
class SignCameraRecorder extends StatefulWidget {
  const SignCameraRecorder({
    super.key,
    this.controller,
    required this.isRecording,
    required this.onRecordingStopped,
    required this.onError,
  });

  final SignCameraRecorderController? controller;
  final bool isRecording;
  final SignRecordingStoppedHandler onRecordingStopped;
  final ValueChanged<String> onError;

  @override
  State<SignCameraRecorder> createState() => _SignCameraRecorderState();
}

class _SignCameraRecorderState extends State<SignCameraRecorder> {
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  bool _isRecordingVideo = false;
  bool _stopPending = false;
  bool _startInFlight = false;
  bool _isFlipping = false;
  DateTime? _videoRecordingStartedAt;
  bool _lastPublishedCanFlip = false;

  bool get _canFlipCamera {
    if (_isRecordingVideo || _stopPending || _isFlipping) {
      return false;
    }
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return false;
    }
    final current = controller.value.description.lensDirection;
    return _cameras.any((camera) => camera.lensDirection != current);
  }

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this);
    if (signCameraTestModeEnabled) {
      return;
    }
    _initCamera();
  }

  @override
  void didUpdateWidget(covariant SignCameraRecorder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
    if (widget.isRecording && !oldWidget.isRecording) {
      unawaited(_startRecording());
    } else if (!widget.isRecording && oldWidget.isRecording) {
      unawaited(_handleStopRequest());
    }
    if (widget.isRecording != oldWidget.isRecording) {
      _publishCameraControls();
    }
  }

  Future<void> flipCamera() async {
    if (_isFlipping || _isRecordingVideo) {
      return;
    }

    final deadline = DateTime.now().add(const Duration(milliseconds: 1500));
    while (mounted && DateTime.now().isBefore(deadline)) {
      final controller = _controller;
      if (controller != null &&
          controller.value.isInitialized &&
          !_isRecordingVideo &&
          !_stopPending &&
          !_isFlipping) {
        final current = controller.value.description.lensDirection;
        if (_cameras.any((camera) => camera.lensDirection != current)) {
          break;
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 40));
    }

    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        _isRecordingVideo ||
        _isFlipping) {
      return;
    }

    final current = controller.value.description.lensDirection;
    if (!_cameras.any((camera) => camera.lensDirection != current)) {
      return;
    }

    final opposite = current == CameraLensDirection.front
        ? CameraLensDirection.back
        : CameraLensDirection.front;
    final nextCamera = _cameras.firstWhere(
      (camera) => camera.lensDirection == opposite,
      orElse: () => _cameras.firstWhere(
        (camera) => camera.lensDirection != current,
      ),
    );

    _isFlipping = true;
    widget.controller?._setFlipping(true);
    if (mounted) {
      setState(() {});
    }
    try {
      if (_startInFlight) {
        final startDeadline = DateTime.now().add(const Duration(seconds: 1));
        while (_startInFlight &&
            mounted &&
            DateTime.now().isBefore(startDeadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 40));
        }
      }
      await controller.setDescription(nextCamera);
    } on Object catch (error) {
      widget.onError(error.toString());
    } finally {
      _isFlipping = false;
      widget.controller?._setFlipping(false);
      _publishCameraControls();
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _onCameraValueChanged() {
    final canFlip = _canFlipCamera;
    if (canFlip == _lastPublishedCanFlip) {
      return;
    }
    _lastPublishedCanFlip = canFlip;
    _publishCameraControls();
  }

  void _publishCameraControls() {
    widget.controller?._setCanFlipCamera(_canFlipCamera);
    widget.controller?._setFlipping(_isFlipping);
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      _cameras = cameras;
      final camera = cameras.firstWhere(
        (description) => description.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.low,
        enableAudio: false,
        // Keep sign clips small for worker upload and Gemini file processing.
        videoBitrate: 2_000_000,
        // JPEG stream format breaks video reconfigure on some Samsung devices.
        imageFormatGroup:
            Platform.isAndroid ? null : ImageFormatGroup.bgra8888,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      controller.addListener(_onCameraValueChanged);
      setState(() => _controller = controller);
      _lastPublishedCanFlip = _canFlipCamera;
      _publishCameraControls();
      if (widget.isRecording) {
        await _startRecording();
      } else if (_stopPending) {
        await _handleStopRequest();
      }
    } on Object catch (error) {
      _stopPending = false;
      widget.onError(error.toString());
    }
  }

  static const _minRecordBeforeStop = Duration(milliseconds: 400);

  Future<void> _handleStopRequest() async {
    if (_isRecordingVideo) {
      await _stopRecording();
      return;
    }

    if (_startInFlight) {
      _stopPending = true;
      return;
    }

    // Preview phase — nothing to stop until the user taps Record.
    _stopPending = false;
  }

  Future<void> _startRecording() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        _isRecordingVideo ||
        _startInFlight) {
      return;
    }
    _startInFlight = true;
    try {
      await controller.startVideoRecording();
      _isRecordingVideo = true;
      _videoRecordingStartedAt = DateTime.now();
      if (!widget.isRecording) {
        _stopPending = false;
        await _stopRecording();
      } else if (_stopPending) {
        _stopPending = false;
        await _stopRecording();
      }
    } on Object catch (error) {
      _stopPending = false;
      widget.onError(error.toString());
    } finally {
      _startInFlight = false;
      _publishCameraControls();
    }
  }

  Future<void> _stopRecording() async {
    final controller = _controller;
    if (controller == null || !_isRecordingVideo) {
      return;
    }
    final startedAt = _videoRecordingStartedAt;
    if (startedAt != null) {
      final elapsed = DateTime.now().difference(startedAt);
      if (elapsed < _minRecordBeforeStop) {
        await Future<void>.delayed(_minRecordBeforeStop - elapsed);
      }
    }
    if (!_isRecordingVideo || controller != _controller) {
      return;
    }
    try {
      final file = await controller.stopVideoRecording();
      _isRecordingVideo = false;
      _stopPending = false;
      final recordingDuration = _videoRecordingStartedAt == null
          ? Duration.zero
          : DateTime.now().difference(_videoRecordingStartedAt!);
      _videoRecordingStartedAt = null;
      // Let the encoder/camera HAL release before the widget is disposed for
      // the analyzing phase (avoids stream reconfigure errors on Samsung).
      if (Platform.isAndroid) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
      widget.onRecordingStopped(file.path, recordingDuration);
    } on Object catch (error) {
      _stopPending = false;
      widget.onError(error.toString());
    } finally {
      _publishCameraControls();
    }
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    final controller = _controller;
    _controller = null;
    controller?.removeListener(_onCameraValueChanged);
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (signCameraTestModeEnabled) {
      return const ColoredBox(
        color: AppColors.talkSignCameraBackground,
        child: Center(
          child: Icon(
            Icons.videocam_outlined,
            size: 48,
            color: AppColors.talkMutedText,
          ),
        ),
      );
    }

    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const ColoredBox(
        color: AppColors.talkSignCameraBackground,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_isFlipping) {
      return const ColoredBox(
        color: AppColors.talkSignCameraBackground,
        child: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final previewSize = controller.value.previewSize;
    final width = previewSize?.height ?? 1;
    final height = previewSize?.width ?? 1;

    return ColoredBox(
      color: AppColors.talkSignCameraBackground,
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          key: ValueKey(controller.description.name),
          width: width,
          height: height,
          child: CameraPreview(controller),
        ),
      ),
    );
  }
}

/// Figma camera card: dark stage, blue border, corner brackets.
class SignCameraStageFrame extends StatelessWidget {
  const SignCameraStageFrame({
    super.key,
    required this.child,
    this.overlay,
  });

  final Widget child;
  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.talkSignCameraBackground,
        border: Border.all(
          color: AppColors.splashBlue,
          width: AppSpacing.talkSignCameraBorderWidth,
        ),
        borderRadius: BorderRadius.circular(
          AppSpacing.talkSessionAvatarCardRadius,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          AppSpacing.talkSessionAvatarCardRadius,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            child,
            const IgnorePointer(child: SignCameraCornerBrackets()),
            if (overlay != null) overlay!,
          ],
        ),
      ),
    );
  }
}

class SignCameraCornerBrackets extends StatelessWidget {
  const SignCameraCornerBrackets({super.key});

  @override
  Widget build(BuildContext context) {
    const inset = AppSpacing.talkSignCameraCornerInset;
    const size = AppSpacing.talkSignCameraCornerSize;
    const radius = AppSpacing.talkSignCameraCornerRadius;

    return Stack(
      children: [
        Positioned(
          top: inset,
          left: inset,
          child: _SignCameraCorner(
            top: true,
            left: true,
            size: size,
            radius: radius,
          ),
        ),
        Positioned(
          top: inset,
          right: inset,
          child: _SignCameraCorner(
            top: true,
            left: false,
            size: size,
            radius: radius,
          ),
        ),
        Positioned(
          bottom: inset,
          left: inset,
          child: _SignCameraCorner(
            top: false,
            left: true,
            size: size,
            radius: radius,
          ),
        ),
        Positioned(
          bottom: inset,
          right: inset,
          child: _SignCameraCorner(
            top: false,
            left: false,
            size: size,
            radius: radius,
          ),
        ),
      ],
    );
  }
}

class _SignCameraCorner extends StatelessWidget {
  const _SignCameraCorner({
    required this.top,
    required this.left,
    required this.size,
    required this.radius,
  });

  final bool top;
  final bool left;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: top
                ? const BorderSide(
                    color: AppColors.splashBlue,
                    width: AppSpacing.talkSignCameraBorderWidth,
                  )
                : BorderSide.none,
            left: left
                ? const BorderSide(
                    color: AppColors.splashBlue,
                    width: AppSpacing.talkSignCameraBorderWidth,
                  )
                : BorderSide.none,
            right: !left
                ? const BorderSide(
                    color: AppColors.splashBlue,
                    width: AppSpacing.talkSignCameraBorderWidth,
                  )
                : BorderSide.none,
            bottom: !top
                ? const BorderSide(
                    color: AppColors.splashBlue,
                    width: AppSpacing.talkSignCameraBorderWidth,
                  )
                : BorderSide.none,
          ),
          borderRadius: BorderRadius.only(
            topLeft: top && left ? Radius.circular(radius) : Radius.zero,
            topRight: top && !left ? Radius.circular(radius) : Radius.zero,
            bottomLeft: !top && left ? Radius.circular(radius) : Radius.zero,
            bottomRight: !top && !left ? Radius.circular(radius) : Radius.zero,
          ),
        ),
      ),
    );
  }
}

/// Red REC pill centered above the camera preview.
class SignRecordingBadge extends StatelessWidget {
  const SignRecordingBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.talkSignRecBadgeBackground,
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _RecDot(),
            SizedBox(width: 6),
            Text(
              'REC',
              style: TextStyle(
                fontFamily: 'Klavika',
                fontWeight: FontWeight.w400,
                fontSize: 11,
                height: 16 / 11,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecDot extends StatelessWidget {
  const _RecDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Flip control overlaid on the sign camera preview.
class TalkSignCameraActionBar extends StatelessWidget {
  const TalkSignCameraActionBar({
    super.key,
    required this.flipSemanticsLabel,
    required this.canFlip,
    required this.flipBusy,
    required this.onFlip,
  });

  final String flipSemanticsLabel;
  final bool canFlip;
  final bool flipBusy;
  final VoidCallback onFlip;

  static const double _tapSize = 48;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.splashBlue.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TalkSignCameraAction(
              buttonKey: const Key('talk_sign_flip_camera_button'),
              icon: Icons.cameraswitch_rounded,
              semanticsLabel: flipSemanticsLabel,
              enabled: canFlip && !flipBusy,
              busy: flipBusy,
              onTap: onFlip,
            ),
          ],
        ),
      ),
    );
  }
}

class _TalkSignCameraAction extends StatelessWidget {
  const _TalkSignCameraAction({
    required this.buttonKey,
    required this.icon,
    required this.semanticsLabel,
    required this.enabled,
    required this.onTap,
    this.busy = false,
  });

  final Key buttonKey;
  final IconData icon;
  final String semanticsLabel;
  final bool enabled;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final iconColor = enabled
        ? AppColors.white
        : AppColors.white.withValues(alpha: 0.72);

    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticsLabel,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: buttonKey,
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: TalkSignCameraActionBar._tapSize,
            height: TalkSignCameraActionBar._tapSize,
            child: Center(
              child: busy
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: iconColor,
                      ),
                    )
                  : Icon(icon, size: 24, color: iconColor),
            ),
          ),
        ),
      ),
    );
  }
}
