import 'dart:typed_data';
import '../core/models/ocr_result.dart';

/// Callback for reporting OCR processing progress.
typedef OcrProgressCallback = void Function(
  int currentImage,
  int totalImages,
  String stage,
  double progress,
);

/// Abstract interface for OCR engines.
/// Can be implemented by LocalOcrEngine (on-device ONNX) or RemoteOcrEngine (FastAPI bridge).
abstract class OcrEngine {
  /// Name of the OCR engine (e.g., 'RapidOCR-ONNX-Mobile', 'RapidOCR-Remote-API').
  String get engineName;

  /// Whether the engine has been initialized.
  bool get isInitialized;

  /// Initializes models, sessions, and dictionaries.
  Future<void> initialize();

  /// Runs OCR and transaction extraction on raw image bytes.
  Future<OcrResult> extractImage(
    Uint8List imageBytes, {
    String filename = 'screenshot.png',
    OcrProgressCallback? onProgress,
    int currentImage = 1,
    int totalImages = 1,
  });

  /// Releases resources, memory, and native ONNX sessions.
  Future<void> dispose();
}
