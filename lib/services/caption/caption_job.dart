import 'caption_job_status.dart';

/// One caption utterance flowing through Firebase → AI → gloss playback.
class CaptionJob {
  const CaptionJob({
    required this.id,
    required this.caption,
    required this.signLanguage,
    required this.status,
    required this.spokenLanguageCode,
    required this.sessionId,
    required this.createdAt,
    required this.updatedAt,
    this.glossSequence = const [],
    this.avatarHints,
    this.errorMessage,
  });

  final String id;
  final String caption;
  final String signLanguage;
  final CaptionJobStatus status;
  final String spokenLanguageCode;
  final String sessionId;
  final int createdAt;
  final int updatedAt;
  final List<String> glossSequence;
  final String? avatarHints;
  final String? errorMessage;

  bool get isGlossReady => status == CaptionJobStatus.glossReady;

  factory CaptionJob.fromMap(Map<dynamic, dynamic> raw, {required String id}) {
    final map = raw.map((key, value) => MapEntry('$key', value));
    final glossRaw = map['glossSequence'];
    final glossSequence = switch (glossRaw) {
      List<dynamic> values => values.map((value) => '$value').toList(),
      _ => const <String>[],
    };

    return CaptionJob(
      id: id,
      caption: '${map['caption'] ?? ''}'.trim(),
      signLanguage: '${map['signLanguage'] ?? ''}'.trim(),
      status:
          CaptionJobStatus.parse('${map['status']}') ??
          CaptionJobStatus.captionReady,
      spokenLanguageCode: '${map['spokenLanguageCode'] ?? 'ENG'}',
      sessionId: '${map['sessionId'] ?? ''}',
      createdAt: _asInt(map['createdAt']),
      updatedAt: _asInt(map['updatedAt']),
      glossSequence: glossSequence,
      avatarHints: map['avatarHints']?.toString(),
      errorMessage: map['errorMessage']?.toString(),
    );
  }

  Map<String, dynamic> toCreatePayload({
    required String caption,
    required String signLanguage,
    required String spokenLanguageCode,
    required String sessionId,
    required int timestamp,
  }) {
    return {
      'caption': caption,
      'signLanguage': signLanguage,
      'status': CaptionJobStatus.captionReady.value,
      'spokenLanguageCode': spokenLanguageCode,
      'sessionId': sessionId,
      'createdAt': timestamp,
      'updatedAt': timestamp,
    };
  }

  static int _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse('$value') ?? 0;
  }
}
