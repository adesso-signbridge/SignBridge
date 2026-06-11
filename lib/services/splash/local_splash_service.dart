import 'splash_service.dart';

final class LocalSplashService implements SplashService {
  @override
  String get serviceName => 'splash-service';

  @override
  Duration get displayDuration => const Duration(seconds: 2);

  @override
  Future<void> completeSplash() => Future<void>.delayed(displayDuration);
}
