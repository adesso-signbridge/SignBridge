import '../../core/services/microservice.dart';

abstract class SplashService implements Microservice {
  Duration get displayDuration;
  Future<void> completeSplash();
}
