import '../translate/sign_token.dart';

/// One gloss token paired with a signer video location.
final class SignPlaybackClip {
  const SignPlaybackClip({
    required this.token,
    required this.assetPath,
    String? playbackUri,
  }) : playbackUri = playbackUri ?? assetPath;

  final SignToken token;

  /// Stable manifest path used for clip identity and local fallback.
  final String assetPath;

  /// URI passed to [VideoPlayerController] (asset path or HTTPS URL).
  final String playbackUri;

  bool get isRemote =>
      playbackUri.startsWith('http://') || playbackUri.startsWith('https://');
}
