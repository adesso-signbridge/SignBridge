import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../translate/sign_language_system.dart';
import '../translate/sign_token.dart';
import 'isl_video_gloss_aliases.dart';
import 'sign_gloss_normalizer.dart';
import 'sign_playback_clip.dart';

/// Maps [SignToken] ids to bundled signer video assets from Hugging Face datasets.
abstract final class SignAssetCatalog {
  static const manifestAsset = 'assets/signs/manifest.json';

  static Map<String, Map<String, String>> _entries = const {
    'asl': {},
    'isl': {},
  };
  static Map<String, Map<String, String>> _aliases = const {
    'asl': {},
    'isl': {},
  };
  static var _loaded = false;
  static Completer<void>? _loadCompleter;

  static Future<void> ensureLoaded() async {
    if (_loaded) {
      return;
    }
    final inFlight = _loadCompleter;
    if (inFlight != null) {
      return inFlight.future;
    }

    final completer = Completer<void>();
    _loadCompleter = completer;
    try {
      await _loadManifest();
      _loaded = true;
      completer.complete();
    } on Object catch (error, stackTrace) {
      debugPrint('[SignBridge/SignAsset] manifest load failed: $error');
      _entries = const {'asl': {}, 'isl': {}};
      _aliases = const {'asl': {}, 'isl': {}};
      _loaded = true;
      completer.complete();
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'SignAssetCatalog',
        ),
      );
    } finally {
      _loadCompleter = null;
    }
  }

  @visibleForTesting
  static void loadForTest({
    Map<String, Map<String, String>>? entries,
    Map<String, Map<String, String>>? aliases,
  }) {
    _entries = entries ?? const {'asl': {}, 'isl': {}};
    _aliases = aliases ?? const {'asl': {}, 'isl': {}};
    _loaded = true;
    _loadCompleter = null;
  }

  @visibleForTesting
  static void resetForTest() {
    _entries = const {'asl': {}, 'isl': {}};
    _aliases = const {'asl': {}, 'isl': {}};
    _loaded = false;
    _loadCompleter = null;
  }

  static bool hasCoverage(SignLanguageSystem system) {
    return assetCount(system) > 0;
  }

  static int assetCount(SignLanguageSystem system) {
    return _entries[_languageKey(system)]?.length ?? 0;
  }

  static String? assetPathForToken(SignToken token, SignLanguageSystem system) {
    final language = _languageKey(system);
    final entries = _entries[language];
    if (entries == null || entries.isEmpty) {
      return null;
    }

    for (final key in SignGlossNormalizer.lookupKeys(
      signId: token.id,
      gloss: token.gloss,
    )) {
      final resolved = _resolveKey(language, key, entries);
      if (resolved != null) {
        return resolved;
      }
    }
    return null;
  }

  static List<SignPlaybackClip> playbackClipsForSequence(
    List<SignToken> sequence,
    SignLanguageSystem system,
  ) {
    final clips = <SignPlaybackClip>[];
    for (final token in sequence) {
      if (token.id == SignToken.thinking.id) {
        continue;
      }
      final path = assetPathForToken(token, system);
      if (path == null) {
        continue;
      }
      clips.add(SignPlaybackClip(token: token, assetPath: path));
    }
    return clips;
  }

  static List<String> assetPathsForSequence(
    List<SignToken> sequence,
    SignLanguageSystem system,
  ) {
    return playbackClipsForSequence(sequence, system)
        .map((clip) => clip.assetPath)
        .toList(growable: false);
  }

  static Future<void> _loadManifest() async {
    final raw = await rootBundle.loadString(manifestAsset);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final version = decoded['version'];
    if (version is! int || version < 1) {
      throw FormatException('Unsupported sign manifest version: $version');
    }

    _entries = {
      'asl': _readLanguageMap(decoded['asl']),
      'isl': _readLanguageMap(decoded['isl']),
    };
    _aliases = {
      'asl': _readLanguageMap(decoded['aliases']?['asl']),
      'isl': _readLanguageMap(decoded['aliases']?['isl']),
    };

    if (kDebugMode) {
      debugPrint(
        '[SignBridge/SignAsset] loaded asl=${assetCount(SignLanguageSystem.asl)} '
        'isl=${assetCount(SignLanguageSystem.isl)}',
      );
    }
  }

  static String? _resolveKey(
    String language,
    String key,
    Map<String, String> entries,
  ) {
    final direct = entries[key];
    if (direct != null && direct.isNotEmpty) {
      return direct;
    }

    final aliasTarget = _aliases[language]?[key];
    if (aliasTarget != null) {
      final aliased = entries[aliasTarget];
      if (aliased != null && aliased.isNotEmpty) {
        return aliased;
      }
    }

    if (language == 'isl') {
      final islVideoKey = IslVideoGlossAliases.manifestKeyFor(key);
      if (islVideoKey != null) {
        final islPath = entries[islVideoKey];
        if (islPath != null && islPath.isNotEmpty) {
          return islPath;
        }
      }
    }

    final canonical = SignGlossNormalizer.canonicalKey(key);
    if (canonical != key) {
      final canonicalPath = entries[canonical];
      if (canonicalPath != null && canonicalPath.isNotEmpty) {
        return canonicalPath;
      }
    }
    return null;
  }

  static String _languageKey(SignLanguageSystem system) {
    return switch (system) {
      SignLanguageSystem.asl => 'asl',
      SignLanguageSystem.isl => 'isl',
    };
  }

  static Map<String, String> _readLanguageMap(Object? value) {
    if (value is! Map) {
      return {};
    }
    final entries = <String, String>{};
    for (final entry in value.entries) {
      final path = _readAssetPath(entry.value);
      if (path != null) {
        entries['${entry.key}'] = path;
      }
    }
    return entries;
  }

  static String? _readAssetPath(Object? value) {
    if (value is String && value.isNotEmpty) {
      return value;
    }
    if (value is Map) {
      final path = value['path'];
      if (path is String && path.isNotEmpty) {
        return path;
      }
    }
    return null;
  }
}
