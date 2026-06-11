import 'package:flutter/material.dart';

import 'app/sign_bridge_app.dart';
import 'core/di/service_locator.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  ServiceLocator.bootstrap();
  runApp(const SignBridgeApp());
}
