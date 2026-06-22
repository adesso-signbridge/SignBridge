/// Outcome of analyzing a recorded sign-language video.
class SignCaptureResult {
  const SignCaptureResult({
    required this.text,
    required this.duration,
    this.glossSequence = const [],
    this.videoPath,
    this.modelUsed,
  });

  final String text;
  final Duration duration;

  /// One gloss token per identified sign, in chronological order.
  final List<String> glossSequence;
  final String? videoPath;
  final String? modelUsed;

  String formattedDuration() {
    final totalSeconds = duration.inSeconds;
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  bool get hasText => text.trim().isNotEmpty;

  bool get hasGloss => glossSequence.isNotEmpty;

  String get glossPhrase => glossSequence.join(' ');

  SignCaptureResult copyWith({
    String? videoPath,
    String? modelUsed,
    List<String>? glossSequence,
  }) {
    return SignCaptureResult(
      text: text,
      duration: duration,
      glossSequence: glossSequence ?? this.glossSequence,
      videoPath: videoPath ?? this.videoPath,
      modelUsed: modelUsed ?? this.modelUsed,
    );
  }
}
