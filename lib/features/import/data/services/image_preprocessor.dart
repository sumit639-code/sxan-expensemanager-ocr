/// Preprocessed representation of a selected screenshot.
class ProcessedImage {
  final String path;
  final String name;
  final bool isValid;
  final String? error;

  const ProcessedImage({
    required this.path,
    required this.name,
    this.isValid = true,
    this.error,
  });
}

/// Preprocessor responsible for lightweight validation of selected images
/// without loading full-resolution bitmaps into memory unnecessarily.
class ImagePreprocessor {
  const ImagePreprocessor();

  /// Validates a list of image paths and returns processed representations.
  List<ProcessedImage> validateImages(List<String> paths) {
    final results = <ProcessedImage>[];

    for (final path in paths) {
      final name = _extractFileName(path);

      if (path.trim().isEmpty) {
        results.add(
          ProcessedImage(
            path: path,
            name: name,
            isValid: false,
            error: 'Empty image path',
          ),
        );
        continue;
      }

      final lower = path.toLowerCase();
      final hasSupportedExt =
          lower.endsWith('.png') ||
          lower.endsWith('.jpg') ||
          lower.endsWith('.jpeg') ||
          lower.endsWith('.webp') ||
          lower.startsWith('blob:') ||
          lower.startsWith('data:');

      if (!hasSupportedExt) {
        results.add(
          ProcessedImage(
            path: path,
            name: name,
            isValid: false,
            error: 'Unsupported image format. Please select PNG, JPG, or WEBP.',
          ),
        );
        continue;
      }

      results.add(ProcessedImage(path: path, name: name, isValid: true));
    }

    return results;
  }

  static String _extractFileName(String path) {
    if (path.isEmpty) return 'Screenshot';
    final normalized = path.replaceAll(r'\', '/');
    final segments = normalized.split('/');
    return segments.isNotEmpty ? segments.last : 'Screenshot';
  }
}
