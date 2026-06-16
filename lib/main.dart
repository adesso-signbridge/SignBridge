import 'package:flutter/material.dart';

import 'app/sign_bridge_app.dart';
import 'core/di/service_locator.dart';
import 'core/firebase/firebase_bootstrap.dart';
import 'services/caption/firebase_caption_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeFirebase();
  ServiceLocator.bootstrap(caption: FirebaseCaptionService());
  runApp(const SignBridgeApp());
}
