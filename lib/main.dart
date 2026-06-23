import 'package:flutter/material.dart';

import 'app/sign_bridge_app.dart';
import 'core/di/service_locator.dart';
import 'services/avatar/sign_asset_catalog.dart';
import 'services/translate/asl_sign_lexicon.dart';
import 'services/translate/english_lexicon.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait([
    EnglishLexicon.load(),
    AslSignLexicon.load(),
    SignAssetCatalog.ensureLoaded(),
  ]);
  ServiceLocator.bootstrap();
  runApp(const SignBridgeApp());
}
