import 'caption_service.dart';

/// No-op caption pipeline for tests and platforms without Firebase.
final class LocalCaptionService implements CaptionService {
  @override
  String get serviceName => 'caption-service';

  @override
  Future<String?> submitCaption({
    required String caption,
    required String signLanguage,
    required String spokenLanguageCode,
    required String sessionId,
  }) async {
    return null;
  }

  @override
  Stream<CaptionJob> watchJob(String jobId) => const Stream.empty();

  @override
  void dispose() {}
}
