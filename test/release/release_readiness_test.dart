import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

/// Release-readiness checks for TestFlight, App Store, and Google Play.
///
/// Required tests fail CI when Apple/Android design or packaging basics break.
/// Tests tagged [store-blocker] warn about production submission blockers.
void main() {
  group('Apple TestFlight and App Store', () {
    test('Info.plist includes required bundle metadata keys', () {
      final plist = File('ios/Runner/Info.plist').readAsStringSync();

      for (final key in [
        'CFBundleDisplayName',
        'CFBundleShortVersionString',
        'CFBundleVersion',
        'CFBundleIdentifier',
        'UILaunchStoryboardName',
        'LSRequiresIPhoneOS',
        'UIApplicationSceneManifest',
      ]) {
        expect(
          plist.contains('<key>$key</key>'),
          isTrue,
          reason: 'Info.plist must define $key for App Store submission',
        );
      }
    });

    test('Info.plist declares export compliance for TestFlight', () {
      final plist = File('ios/Runner/Info.plist').readAsStringSync();

      expect(
        plist.contains('<key>ITSAppUsesNonExemptEncryption</key>'),
        isTrue,
        reason:
            'Add ITSAppUsesNonExemptEncryption to avoid TestFlight export prompts',
      );
    });

    test('App Store marketing icon (1024x1024) exists', () {
      const iconPath =
          'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png';

      expect(File(iconPath).existsSync(), isTrue, reason: 'Missing $iconPath');
    });

    test('All AppIcon asset catalog entries exist', () {
      final catalog =
          json.decode(
                File(
                  'ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;

      final images = catalog['images'] as List<dynamic>;
      for (final image in images) {
        final filename = (image as Map<String, dynamic>)['filename'] as String?;
        if (filename == null) {
          continue;
        }

        final path = 'ios/Runner/Assets.xcassets/AppIcon.appiconset/$filename';
        expect(
          File(path).existsSync(),
          isTrue,
          reason: 'Missing icon asset: $path',
        );
      }
    });

    test('Launch screen uses storyboard with Auto Layout', () {
      final storyboard = File(
        'ios/Runner/Base.lproj/LaunchScreen.storyboard',
      ).readAsStringSync();

      expect(storyboard.contains('launchScreen="YES"'), isTrue);
      expect(storyboard.contains('useAutolayout="YES"'), isTrue);
      expect(storyboard.contains('LaunchLogo'), isTrue);
    });

    test('Xcode project file is tracked for CI and TestFlight builds', () {
      expect(
        File('ios/Runner.xcodeproj/project.pbxproj').existsSync(),
        isTrue,
        reason: 'project.pbxproj must be committed for reproducible iOS builds',
      );
    });

    test('iOS deployment target is at least 13.0', () {
      final project = File(
        'ios/Runner.xcodeproj/project.pbxproj',
      ).readAsStringSync();
      final targetPattern = RegExp(r'IPHONEOS_DEPLOYMENT_TARGET = (\d+\.\d+);');
      final matches = targetPattern
          .allMatches(project)
          .map((match) => double.parse(match.group(1)!))
          .toList();

      expect(matches, isNotEmpty);
      for (final target in matches) {
        expect(
          target,
          greaterThanOrEqualTo(13.0),
          reason: 'Apple requires a supported minimum iOS deployment target',
        );
      }
    });

    test('App display name is human readable', () {
      final plist = File('ios/Runner/Info.plist').readAsStringSync();
      final displayNamePattern = RegExp(
        r'<key>CFBundleDisplayName</key>\s*<string>([^<]+)</string>',
      );
      final match = displayNamePattern.firstMatch(plist);

      expect(match, isNotNull);
      final displayName = match!.group(1)!;
      expect(displayName.toLowerCase(), isNot(contains('example')));
      expect(displayName.trim(), isNotEmpty);
    });
  });

  group('Apple Human Interface Guidelines (automated)', () {
    test('MaterialApp hides debug banner for production UX', () {
      final appSource = File('lib/app/sign_bridge_app.dart').readAsStringSync();

      expect(
        appSource.contains('debugShowCheckedModeBanner: false'),
        isTrue,
        reason: 'Debug banner must be hidden before App Store release',
      );
    });

    test('Primary screens respect safe areas', () {
      final requiredSafeAreaFiles = [
        'lib/features/home/presentation/home_screen.dart',
        'lib/shell/main_shell.dart',
      ];

      for (final path in requiredSafeAreaFiles) {
        final source = File(path).readAsStringSync();
        expect(
          source.contains('SafeArea'),
          isTrue,
          reason: '$path should use SafeArea to follow Apple layout guidance',
        );
      }
    });

    test('Brand font is bundled for consistent typography', () {
      expect(
        File('assets/fonts/Klavika-Bold.otf').existsSync(),
        isTrue,
        reason: 'Custom brand font should be bundled for consistent UI',
      );

      final pubspec =
          loadYaml(File('pubspec.yaml').readAsStringSync()) as YamlMap;
      final fonts = (pubspec['flutter'] as YamlMap?)?['fonts'] as YamlList?;
      expect(fonts, isNotNull);
      expect(fonts, isNotEmpty);
    });

    test('Tab labels remain readable and concise', () {
      final shellSource = File('lib/shell/main_shell.dart').readAsStringSync();
      for (final label in ['Home', 'Translate', 'Phrases', 'SOS', 'Settings']) {
        expect(shellSource.contains("'$label'"), isTrue);
      }
    });
  });

  group('Google Play and Android release', () {
    test('Android launcher icons exist for required densities', () {
      const densities = ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi'];

      for (final density in densities) {
        final path = 'android/app/src/main/res/mipmap-$density/ic_launcher.png';
        expect(File(path).existsSync(), isTrue, reason: 'Missing $path');
      }
    });

    test('Android manifest defines launcher activity and app label', () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();

      expect(manifest.contains('android.intent.action.MAIN'), isTrue);
      expect(manifest.contains('android.intent.category.LAUNCHER'), isTrue);
      expect(manifest.contains('android:exported="true"'), isTrue);
      expect(manifest.contains('android:label='), isTrue);
      expect(
        manifest.contains('sign_bridge'),
        isFalse,
        reason: 'Use a human-readable Android app label such as SignBridge',
      );
    });

    test('Android version comes from pubspec', () {
      final pubspec =
          loadYaml(File('pubspec.yaml').readAsStringSync()) as YamlMap;
      final version = pubspec['version']?.toString();

      expect(version, isNotNull);
      expect(version!, matches(RegExp(r'^\d+\.\d+\.\d+\+\d+$')));

      final gradle = File('android/app/build.gradle.kts').readAsStringSync();
      expect(gradle.contains('flutter.versionCode'), isTrue);
      expect(gradle.contains('flutter.versionName'), isTrue);
    });

    test('Adaptive icon configuration exists for modern Android launchers', () {
      expect(
        File(
          'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml',
        ).existsSync(),
        isTrue,
      );
      expect(
        File(
          'android/app/src/main/res/drawable/ic_launcher_foreground.xml',
        ).existsSync(),
        isTrue,
      );
    });
  });

  group('store blockers', () {
    test('uses production bundle identifier', () {
      final gradle = File('android/app/build.gradle.kts').readAsStringSync();
      expect(
        gradle.contains('com.example'),
        isFalse,
        reason:
            'Replace com.example.* with your production applicationId before TestFlight/Play Store upload',
      );

      if (File('ios/Runner.xcodeproj/project.pbxproj').existsSync()) {
        final project = File(
          'ios/Runner.xcodeproj/project.pbxproj',
        ).readAsStringSync();
        expect(
          project.contains('com.example'),
          isFalse,
          reason:
              'Replace com.example.* with your production bundle identifier before TestFlight upload',
        );
      }
    }, tags: ['store-blocker']);

    test(
      'Android release build does not rely on debug signing',
      () {
        final gradle = File('android/app/build.gradle.kts').readAsStringSync();
        expect(
          gradle.contains('signingConfigs.getByName("debug")'),
          isFalse,
          reason:
              'Configure a release signingConfig before uploading to Google Play production',
        );
      },
      tags: ['store-blocker'],
    );
  });
}
