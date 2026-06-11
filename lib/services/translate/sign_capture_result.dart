/// Outcome of analyzing a recorded sign-language video.
class SignCaptureResult {
  const SignCaptureResult({
    required this.text,
    required this.duration,
    this.videoPath,
  });

  final String text;
  final Duration duration;
  final String? videoPath;

  String formattedDuration() {
    final totalSeconds = duration.inSeconds;
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  bool get hasText => text.trim().isNotEmpty;

  SignCaptureResult copyWith({String? videoPath}) {
    return SignCaptureResult(
      text: text,
      duration: duration,
      videoPath: videoPath ?? this.videoPath,
    );
  }
}
