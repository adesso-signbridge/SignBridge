import '../translate/sign_token.dart';

/// One gloss token paired with a bundled signer video asset.
final class SignPlaybackClip {
  const SignPlaybackClip({
    required this.token,
    required this.assetPath,
  });

  final SignToken token;
  final String assetPath;
}
