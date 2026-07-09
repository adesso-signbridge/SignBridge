/// Response from the gloss worker Veo sign-video endpoints.
class VeoSignVideoResult {
  const VeoSignVideoResult({
    required this.status,
    this.videoUrl,
    this.operationName,
    this.prompt,
    this.model,
    this.pollAfterMs = 8000,
    this.cached,
  });

  final String status;
  final String? videoUrl;
  final String? operationName;
  final String? prompt;
  final String? model;
  final int pollAfterMs;
  final bool? cached;

  bool get isReady =>
      status == 'ready' && videoUrl != null && videoUrl!.isNotEmpty;
  bool get isProcessing => status == 'processing';
}
