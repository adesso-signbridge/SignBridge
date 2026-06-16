import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';

/// Initializes Firebase on mobile targets. Skips unsupported platforms (e.g. CI
/// widget tests on Linux) so local and CI test runs keep working.
Future<void> initializeFirebase() async {
  if (kIsWeb || Firebase.apps.isNotEmpty) {
    return;
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on UnsupportedError {
    // Desktop / test VM — no Firebase config for this target.
  }
}
