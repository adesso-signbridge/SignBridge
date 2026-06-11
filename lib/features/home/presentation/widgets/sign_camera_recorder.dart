import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../../../core/platform/sign_camera_test_mode.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// Front-camera preview that records sign-language video to a temp file.
class SignCameraRecorder extends StatefulWidget {
  const SignCameraRecorder({
    super.key,
    required this.isRecording,
    required this.onRecordingReady,
    required this.onRecordingStopped,
    required this.onError,
  });

  final bool isRecording;
  final ValueChanged<CameraController> onRecordingReady;
  final ValueChanged<String> onRecordingStopped;
  final ValueChanged<String> onError;

  @override
  State<SignCameraRecorder> createState() => _SignCameraRecorderState();
}

class _SignCameraRecorderState extends State<SignCameraRecorder> {
  CameraController? _controller;
  bool _isRecordingVideo = false;

  @override
  void initState() {
    super.initState();
    if (signCameraTestModeEnabled) {
      return;
    }
    _initCamera();
  }

  @override
  void didUpdateWidget(covariant SignCameraRecorder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecording && !_isRecordingVideo) {
      _startRecording();
    } else if (!widget.isRecording && _isRecordingVideo) {
      _stopRecording();
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      final camera = cameras.firstWhere(
        (description) => description.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
      widget.onRecordingReady(controller);
      if (widget.isRecording) {
        await _startRecording();
      }
    } on Object catch (error) {
      widget.onError(error.toString());
    }
  }

  Future<void> _startRecording() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        _isRecordingVideo) {
      return;
    }
    try {
      await controller.startVideoRecording();
      _isRecordingVideo = true;
    } on Object catch (error) {
      widget.onError(error.toString());
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
      widget.onRecordingStopped(file.path);
    } on Object catch (error) {
      widget.onError(error.toString());
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
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
  const SignCameraStageFrame({super.key, required this.child});

  final Widget child;

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
            const SignCameraCornerBrackets(),
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
          child: _SignCameraCorner(top: true, left: true, size: size, radius: radius),
        ),
        Positioned(
          top: inset,
          right: inset,
          child: _SignCameraCorner(top: true, left: false, size: size, radius: radius),
        ),
        Positioned(
          bottom: inset,
          left: inset,
          child: _SignCameraCorner(top: false, left: true, size: size, radius: radius),
        ),
        Positioned(
          bottom: inset,
          right: inset,
          child: _SignCameraCorner(top: false, left: false, size: size, radius: radius),
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
