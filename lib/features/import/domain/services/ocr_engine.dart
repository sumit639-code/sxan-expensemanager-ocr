import '../entities/ocr_document.dart';

/// Abstract domain contract for an On-Device OCR engine.
///
/// Completely independent of vendor implementations (Google ML Kit, Tesseract, Apple Vision).
abstract class OcrEngine {
  /// Runs text recognition on the local image file at [imagePath] and returns
  /// a normalized [OcrDocument].
  Future<OcrDocument> recognizeText(String imagePath);

  /// Disposes any underlying native handles or caches.
  Future<void> dispose();
}
