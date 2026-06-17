import 'package:flutter/material.dart';

import 'app/sign_bridge_app.dart';
import 'core/di/service_locator.dart';
import 'services/translate/asl_sign_lexicon.dart';
import 'services/translate/english_lexicon.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EnglishLexicon.load();
  await AslSignLexicon.load();
  ServiceLocator.bootstrap();
  runApp(const SignBridgeApp());
}
