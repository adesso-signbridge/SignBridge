/// Cloud gloss worker response used by the Listen flow.
class GlossCloudResult {
  const GlossCloudResult({
    required this.glossSequence,
    this.stitchedVideoUrl,
  });

  final List<String> glossSequence;
  final String? stitchedVideoUrl;

  bool get hasStitchedVideo =>
      stitchedVideoUrl != null && stitchedVideoUrl!.trim().isNotEmpty;
}
