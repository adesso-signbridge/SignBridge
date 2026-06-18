/// Controls which cloud gloss models the worker uses.
enum GlossTier {
  /// Fast preview gloss while the user is still speaking.
  live,

  /// High-quality gloss for the full caption when listening stops.
  finalPass,
}

extension GlossTierWire on GlossTier {
  String get wireValue => switch (this) {
        GlossTier.live => 'live',
        GlossTier.finalPass => 'final',
      };
}
