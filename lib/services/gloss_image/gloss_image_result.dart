/// Response from the gloss worker Banana image endpoint.
class GlossImageResult {
  const GlossImageResult({
    required this.status,
    this.imageUrls = const [],
    this.images = const [],
    this.model,
    this.cached,
  });

  final String status;
  final List<String> imageUrls;
  final List<GlossImageItem> images;
  final String? model;
  final bool? cached;

  bool get isReady => status == 'ready' && imageUrls.isNotEmpty;
}

class GlossImageItem {
  const GlossImageItem({
    required this.gloss,
    required this.imageUrl,
    this.cached = false,
  });

  final String gloss;
  final String imageUrl;
  final bool cached;
}
