/// Firebase Realtime Database paths for the caption → gloss pipeline.
abstract final class CaptionPipelineConfig {
  static const jobsPath = String.fromEnvironment(
    'CAPTION_JOBS_PATH',
    defaultValue: 'caption_jobs',
  );

  static const databaseUrl = String.fromEnvironment(
    'FIREBASE_DATABASE_URL',
    defaultValue:
        'https://signbridge-af728-default-rtdb.asia-southeast1.firebasedatabase.app',
  );
}
