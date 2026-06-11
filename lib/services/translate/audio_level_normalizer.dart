import 'dart:math' as math;

/// Maps platform RMS / dB readings to a 0–1 visual level for the talk waveform.
abstract final class AudioLevelNormalizer {
  /// Android [SpeechRecognizer.onRmsChanged] is typically ~0–12 dB.
  /// iOS RMS log-power is typically ~-50 to -5 dB.
  static double toVisualLevel(double rawDb) {
    if (rawDb.isNaN || rawDb.isInfinite) {
      return 0;
    }
    // Samsung / Google recognizers often report 0–10 dB while listening.
    final double normalized = rawDb <= 0
        ? 0
        : rawDb <= 12
        ? rawDb / 12
        : rawDb / 10;
    return normalized.clamp(0.0, 1.0);
  }

  /// Smooths abrupt level jumps for a steadier waveform.
  static double smooth(double previous, double next, {double factor = 0.35}) {
    return previous + (next - previous) * factor;
  }

  /// Per-bar multiplier so the center of the waveform reads louder.
  static double barWeight(int index, int barCount) {
    final center = (barCount - 1) / 2;
    final distance = (index - center).abs() / center;
    return math.pow(1 - distance * 0.55, 1.2).toDouble().clamp(0.35, 1.0);
  }
}
