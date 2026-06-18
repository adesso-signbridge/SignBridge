import 'dart:math' as math;

/// Maps platform RMS / dB readings to a 0–1 visual level for the talk waveform.
abstract final class AudioLevelNormalizer {
  /// Android [SpeechRecognizer.onRmsChanged] is typically ~0–12 dB.
  /// iOS reports `20 * log10(rms)`, typically ~-50 (quiet) to -15 (loud).
  static double toVisualLevel(double rawDb) {
    if (rawDb.isNaN || rawDb.isInfinite) {
      return 0;
    }

    if (rawDb < 0) {
      const floorDb = -50.0;
      const ceilingDb = -15.0;
      final linear =
          ((rawDb - floorDb) / (ceilingDb - floorDb)).clamp(0.0, 1.0);
      // Slight curve so normal speech reads clearly on the waveform.
      return math.pow(linear, 0.85).toDouble().clamp(0.0, 1.0);
    }

    // Samsung / Google recognizers often report 0–10 dB while listening.
    final double normalized = rawDb <= 12 ? rawDb / 12 : rawDb / 10;
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
