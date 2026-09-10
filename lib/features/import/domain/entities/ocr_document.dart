import 'dart:ui';

/// Normalized domain representation of the smallest OCR text unit (word/token).
class OcrElement {
  final String text;
  final Rect? boundingBox;
  final double? confidence;

  const OcrElement({required this.text, this.boundingBox, this.confidence});
}

/// Normalized domain representation of a line of OCR text.
class OcrLine {
  final String text;
  final Rect? boundingBox;
  final List<OcrElement> elements;
  final double? confidence;

  const OcrLine({
    required this.text,
    this.boundingBox,
    this.elements = const [],
    this.confidence,
  });
}

/// Normalized domain representation of an OCR text block (paragraph/cluster).
class OcrBlock {
  final String text;
  final Rect? boundingBox;
  final List<OcrLine> lines;

  const OcrBlock({required this.text, this.boundingBox, this.lines = const []});
}

/// Normalized domain representation of a recognized document image.
///
/// Completely independent of vendor-specific OCR classes (such as Google ML Kit).
class OcrDocument {
  final String fullText;
  final List<OcrBlock> blocks;
  final List<OcrLine> lines;
  final String? imagePath;
  final int? imageWidth;
  final int? imageHeight;

  const OcrDocument({
    required this.fullText,
    required this.blocks,
    required this.lines,
    this.imagePath,
    this.imageWidth,
    this.imageHeight,
  });

  /// Factory to construct an empty/unreadable document.
  factory OcrDocument.empty({String? imagePath}) {
    return OcrDocument(
      fullText: '',
      blocks: const [],
      lines: const [],
      imagePath: imagePath,
    );
  }

  /// Convenience helper to create an [OcrDocument] directly from a multiline string (useful for tests and fixtures).
  factory OcrDocument.fromText(String text, {String? imagePath}) {
    final rawLines = text.split('\n');
    final ocrLines = <OcrLine>[];
    double currentTop = 0;

    for (final raw in rawLines) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) {
        currentTop += 25;
        continue;
      }
      final elements = trimmed
          .split(RegExp(r'\s+'))
          .where((s) => s.isNotEmpty)
          .map((word) => OcrElement(text: word))
          .toList();

      ocrLines.add(
        OcrLine(
          text: trimmed,
          boundingBox: Rect.fromLTWH(0, currentTop, 400, 20),
          elements: elements,
          confidence: 1.0,
        ),
      );
      currentTop += 25;
    }

    final block = OcrBlock(
      text: text,
      boundingBox: Rect.fromLTWH(0, 0, 400, currentTop),
      lines: ocrLines,
    );

    return OcrDocument(
      fullText: text,
      blocks: [block],
      lines: ocrLines,
      imagePath: imagePath,
    );
  }

  bool get isEmpty => fullText.trim().isEmpty;
  bool get isNotEmpty => !isEmpty;

  /// Estimated document width based on imageWidth or the rightmost bounding box.
  double get estimatedWidth {
    if (imageWidth != null && imageWidth! > 0) return imageWidth!.toDouble();
    double maxR = 0;
    for (final l in lines) {
      if (l.boundingBox != null && l.boundingBox!.right > maxR) {
        maxR = l.boundingBox!.right;
      }
    }
    return maxR > 0 ? maxR : 400.0;
  }

  /// Estimated document height based on imageHeight or the bottom-most bounding box.
  double get estimatedHeight {
    if (imageHeight != null && imageHeight! > 0) return imageHeight!.toDouble();
    double maxB = 0;
    for (final l in lines) {
      if (l.boundingBox != null && l.boundingBox!.bottom > maxB) {
        maxB = l.boundingBox!.bottom;
      }
    }
    return maxB > 0 ? maxB : 800.0;
  }
}
