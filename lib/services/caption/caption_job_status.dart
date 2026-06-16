enum CaptionJobStatus {
  captionReady('CAPTION_READY'),
  glossReady('GLOSS_READY'),
  failed('FAILED');

  const CaptionJobStatus(this.value);

  final String value;

  static CaptionJobStatus? parse(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    for (final status in CaptionJobStatus.values) {
      if (status.value == raw) {
        return status;
      }
    }
    return null;
  }
}
