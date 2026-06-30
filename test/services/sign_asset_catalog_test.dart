import 'package:flutter_test/flutter_test.dart';
import 'package:sign_bridge/services/avatar/sign_asset_catalog.dart';
import 'package:sign_bridge/services/avatar/sign_asset_remote_config.dart';
import 'package:sign_bridge/services/avatar/sign_gloss_normalizer.dart';
import 'package:sign_bridge/services/translate/sign_language_system.dart';
import 'package:sign_bridge/services/translate/sign_token.dart';

void main() {
  tearDown(() {
    SignAssetCatalog.resetForTest();
    SignAssetRemoteConfig.setBaseUrlForTest(null);
  });

  group('SignGlossNormalizer', () {
    test('canonicalKey maps common variants', () {
      expect(SignGlossNormalizer.canonicalKey('THANKS'), 'thank_you');
      expect(SignGlossNormalizer.canonicalKey('HI'), 'hello');
    });
  });

  group('SignAssetCatalog', () {
    test('assetPathForToken resolves id gloss and aliases', () {
      SignAssetCatalog.loadForTest(
        entries: {
          'asl': {
            'hello': 'assets/signs/asl/hello.mp4',
            'thank_you': 'assets/signs/asl/thank_you.mp4',
          },
          'isl': {},
        },
        aliases: {
          'asl': {'thanks': 'thank_you'},
          'isl': {},
        },
      );

      expect(
        SignAssetCatalog.assetPathForToken(
          const SignToken(id: 'hello', gloss: 'HELLO', system: SignLanguageSystem.asl),
          SignLanguageSystem.asl,
        ),
        'assets/signs/asl/hello.mp4',
      );
      expect(
        SignAssetCatalog.assetPathForToken(
          const SignToken(id: 'greeting', gloss: 'HI', system: SignLanguageSystem.asl),
          SignLanguageSystem.asl,
        ),
        'assets/signs/asl/hello.mp4',
      );
      expect(
        SignAssetCatalog.assetPathForToken(
          const SignToken(id: 'thanks', gloss: 'THANKS', system: SignLanguageSystem.asl),
          SignLanguageSystem.asl,
        ),
        'assets/signs/asl/thank_you.mp4',
      );
    });

    test('playbackClipsForSequence skips thinking and missing assets', () {
      SignAssetRemoteConfig.setBaseUrlForTest('');
      SignAssetCatalog.loadForTest(
        entries: {
          'asl': {'hello': 'assets/signs/asl/hello.mp4'},
          'isl': {},
        },
      );

      final clips = SignAssetCatalog.playbackClipsForSequence(
        [
          SignToken.thinking,
          const SignToken(id: 'hello', gloss: 'HELLO', system: SignLanguageSystem.asl),
          const SignToken(id: 'missing', gloss: 'MISSING', system: SignLanguageSystem.asl),
        ],
        SignLanguageSystem.asl,
      );

      expect(clips.length, 1);
      expect(clips.first.assetPath, 'assets/signs/asl/hello.mp4');
      expect(clips.first.playbackUri, 'assets/signs/asl/hello.mp4');
      expect(clips.first.token.gloss, 'HELLO');
    });

    test('playbackUriForAssetPath maps bundled paths to remote worker URLs', () {
      SignAssetRemoteConfig.setBaseUrlForTest(
        'https://signbridge-sign-assets.example.workers.dev',
      );

      expect(
        SignAssetCatalog.playbackUriForAssetPath(
          'assets/signs/isl/hello.mp4',
        ),
        'https://signbridge-sign-assets.example.workers.dev/isl/hello.mp4',
      );
    });

    test('playbackClipsForSequence uses remote URIs when configured', () {
      SignAssetRemoteConfig.setBaseUrlForTest(
        'https://signbridge-sign-assets.example.workers.dev',
      );
      SignAssetCatalog.loadForTest(
        entries: {
          'asl': {'hello': 'assets/signs/asl/hello.mp4'},
          'isl': {},
        },
      );

      final clips = SignAssetCatalog.playbackClipsForSequence(
        [
          const SignToken(id: 'hello', gloss: 'HELLO', system: SignLanguageSystem.asl),
        ],
        SignLanguageSystem.asl,
      );

      expect(clips.single.isRemote, isTrue);
      expect(
        clips.single.playbackUri,
        'https://signbridge-sign-assets.example.workers.dev/asl/hello.mp4',
      );
    });

    test('ensureLoaded is safe to call concurrently', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SignAssetCatalog.resetForTest();
      await Future.wait([
        SignAssetCatalog.ensureLoaded(),
        SignAssetCatalog.ensureLoaded(),
      ]);
      expect(SignAssetCatalog.hasCoverage(SignLanguageSystem.asl), isTrue);
      expect(SignAssetCatalog.hasCoverage(SignLanguageSystem.isl), isTrue);
    });
  });
}
