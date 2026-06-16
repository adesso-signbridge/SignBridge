// Firebase client configuration for SignBridge (project: signbridge-af728).
// Generated from google-services.json and GoogleService-Info.plist.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions are not configured for web.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for macOS.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for windows.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for linux.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB8c-VxR-wvuGOL3-lWAlFNkmhL5lka6qw',
    appId: '1:201386548601:android:1e27d737071f6c8996a3a8',
    messagingSenderId: '201386548601',
    projectId: 'signbridge-af728',
    storageBucket: 'signbridge-af728.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBL3GEpqrjbXAfPdEtY2MVdFx-1WAZqL2s',
    appId: '1:201386548601:ios:9fb8122e5331ff2196a3a8',
    messagingSenderId: '201386548601',
    projectId: 'signbridge-af728',
    storageBucket: 'signbridge-af728.firebasestorage.app',
    iosBundleId: 'com.adesso.signbridge',
  );
}
