import '../../core/services/microservice.dart';

import 'caption_job.dart';

export 'caption_job.dart';
export 'caption_job_status.dart';

/// Sends spoken captions to Firebase and receives AI gloss results.
abstract class CaptionService implements Microservice {
  /// Writes `{ caption, signLanguage, status: CAPTION_READY, ... }` to RTDB.
  /// Returns the generated job id, or null when Firebase is unavailable.
  Future<String?> submitCaption({
    required String caption,
    required String signLanguage,
    required String spokenLanguageCode,
    required String sessionId,
  });

  /// Emits job updates until [CaptionJobStatus.glossReady] or [CaptionJobStatus.failed].
  Stream<CaptionJob> watchJob(String jobId);

  void dispose();
}
