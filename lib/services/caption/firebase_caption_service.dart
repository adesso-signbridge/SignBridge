import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import 'caption_pipeline_config.dart';
import 'caption_service.dart';

/// Writes caption jobs to Firebase RTDB and listens for gloss responses.
final class FirebaseCaptionService implements CaptionService {
  FirebaseCaptionService({this.database});

  final FirebaseDatabase? database;
  final Map<String, Stream<CaptionJob>> _watchCache = {};

  @override
  String get serviceName => 'caption-service';

  FirebaseDatabase? get _db {
    if (database != null) {
      return database;
    }
    if (Firebase.apps.isEmpty) {
      return null;
    }
    return FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: CaptionPipelineConfig.databaseUrl,
    );
  }

  @override
  Future<String?> submitCaption({
    required String caption,
    required String signLanguage,
    required String spokenLanguageCode,
    required String sessionId,
  }) async {
    final trimmed = caption.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final db = _db;
    if (db == null) {
      return null;
    }

    final ref = db.ref(CaptionPipelineConfig.jobsPath).push();
    final jobId = ref.key;
    if (jobId == null) {
      return null;
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final payload =
        CaptionJob(
          id: jobId,
          caption: trimmed,
          signLanguage: signLanguage,
          status: CaptionJobStatus.captionReady,
          spokenLanguageCode: spokenLanguageCode,
          sessionId: sessionId,
          createdAt: timestamp,
          updatedAt: timestamp,
        ).toCreatePayload(
          caption: trimmed,
          signLanguage: signLanguage,
          spokenLanguageCode: spokenLanguageCode,
          sessionId: sessionId,
          timestamp: timestamp,
        );

    await ref.set(payload);
    return jobId;
  }

  @override
  Stream<CaptionJob> watchJob(String jobId) {
    return _watchCache.putIfAbsent(jobId, () {
      final db = _db;
      if (db == null) {
        return const Stream.empty();
      }

      return db
          .ref('${CaptionPipelineConfig.jobsPath}/$jobId')
          .onValue
          .map((event) {
            final value = event.snapshot.value;
            if (value is! Map) {
              return null;
            }
            return CaptionJob.fromMap(value, id: jobId);
          })
          .where((job) => job != null)
          .map((job) => job!);
    });
  }

  @override
  void dispose() {
    _watchCache.clear();
  }
}
