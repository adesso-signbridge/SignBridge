import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../../../core/platform/sign_camera_test_mode.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

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
  final ValueChanged<String> onRecordingStopped;
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

  bool get _canFlipCamera {
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
    if (widget.isRecording && !_isRecordingVideo && !_stopPending) {
      unawaited(_startRecording());
    } else if (!widget.isRecording) {
      unawaited(_handleStopRequest());
    }
  }

  Future<void> flipCamera() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        !_canFlipCamera ||
        _isFlipping) {
      return;
    }

    final current = controller.value.description.lensDirection;
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
    try {
      await controller.setDescription(nextCamera);
    } on Object catch (error) {
      widget.onError(error.toString());
    } finally {
      _isFlipping = false;
      widget.controller?._setFlipping(false);
      widget.controller?._setCanFlipCamera(_canFlipCamera);
      if (mounted) {
        setState(() {});
      }
    }
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
        ResolutionPreset.high,
        enableAudio: false,
        // JPEG stream format breaks video reconfigure on some Samsung devices.
        imageFormatGroup:
            Platform.isAndroid ? null : ImageFormatGroup.bgra8888,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
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

  Future<void> _handleStopRequest() async {
    if (_isRecordingVideo) {
      await _stopRecording();
      return;
    }

    if (_startInFlight) {
      _stopPending = true;
      return;
    }

    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      _stopPending = true;
      return;
    }

    _stopPending = false;
    await _startRecording();
    if (_isRecordingVideo) {
      await _stopRecording();
    } else {
      widget.onError('Recording did not start');
    }
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
      if (_stopPending || !widget.isRecording) {
        _stopPending = false;
        await _stopRecording();
      }
    } on Object catch (error) {
      _stopPending = false;
      widget.onError(error.toString());
    } finally {
      _startInFlight = false;
    }
  }

  Future<void> _stopRecording() async {
    final controller = _controller;
    if (controller == null || !_isRecordingVideo) {
      return;
    }
    try {
      final file = await controller.stopVideoRecording();
      _isRecordingVideo = false;
      _stopPending = false;
      // Let the encoder/camera HAL release before the widget is disposed for
      // the analyzing phase (avoids stream reconfigure errors on Samsung).
      if (Platform.isAndroid) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
      widget.onRecordingStopped(file.path);
    } on Object catch (error) {
      _stopPending = false;
      widget.onError(error.toString());
    }
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    final controller = _controller;
    _controller = null;
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

    return ColoredBox(
      color: AppColors.talkSignCameraBackground,
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: controller.value.previewSize?.height ?? 1,
          height: controller.value.previewSize?.width ?? 1,
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

/// Flip + send controls overlaid on the sign camera preview.
class TalkSignCameraActionBar extends StatelessWidget {
  const TalkSignCameraActionBar({
    super.key,
    required this.flipSemanticsLabel,
    required this.sendSemanticsLabel,
    required this.canFlip,
    required this.flipBusy,
    required this.sendEnabled,
    required this.onFlip,
    required this.onSend,
  });

  final String flipSemanticsLabel;
  final String sendSemanticsLabel;
  final bool canFlip;
  final bool flipBusy;
  final bool sendEnabled;
  final VoidCallback onFlip;
  final VoidCallback onSend;

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
            if (sendEnabled) ...[
              Container(
                width: 1,
                height: 28,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                color: AppColors.white.withValues(alpha: 0.35),
              ),
              _TalkSignCameraAction(
                buttonKey: const Key('talk_sign_send_button'),
                icon: Icons.send_rounded,
                semanticsLabel: sendSemanticsLabel,
                enabled: true,
                onTap: onSend,
              ),
            ],
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
