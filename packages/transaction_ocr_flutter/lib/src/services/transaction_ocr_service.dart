import 'dart:io';
import 'dart:typed_data';

import '../core/configuration/ocr_config.dart';
import '../core/models/ocr_result.dart';
import '../engine/ocr_engine.dart';
import '../engine/local_ocr_engine.dart';
import '../engine/remote_ocr_engine.dart';

/// Top-level service facade for offline & online transaction OCR extraction.
///
/// Example Usage:
/// ```dart
/// // 1. Instantiate local on-device OCR engine
/// final ocr = TransactionOcr.local();
/// await ocr.initialize();
///
/// // 2. Extract transactions from screenshot file
/// final result = await ocr.extractImage(File('screenshot.png'));
///
/// for (final tx in result.transactions) {
///   print('${tx.merchantText}: ₹${tx.amountValue} on ${tx.dateText}');
/// }
///
/// // 3. Clean up when done
/// await ocr.dispose();
/// ```
class TransactionOcr {
  final OcrEngine engine;

  /// Creates a TransactionOcr instance with a specific [engine].
  TransactionOcr({required this.engine});

  /// Factory constructor for local on-device OCR inference (default offline mode).
  factory TransactionOcr.local({OcrConfig? config}) {
    return TransactionOcr(engine: LocalOcrEngine(config: config));
  }

  /// Factory constructor for remote FastAPI development server bridge.
  factory TransactionOcr.remote({String baseUrl = 'http://localhost:8000'}) {
    return TransactionOcr(engine: RemoteOcrEngine(baseUrl: baseUrl));
  }

  /// Initializes the underlying engine and model weights.
  Future<void> initialize() => engine.initialize();

  /// Whether the OCR engine is ready for inference.
  bool get isInitialized => engine.isInitialized;

  /// Extracts text and transaction candidates from a single image [File].
  Future<OcrResult> extractImage(
    File imageFile, {
    OcrProgressCallback? onProgress,
  }) async {
    final bytes = await imageFile.readAsBytes();
    final filename = imageFile.uri.pathSegments.isNotEmpty
        ? imageFile.uri.pathSegments.last
        : 'screenshot.png';

    return engine.extractImage(
      bytes,
      filename: filename,
      onProgress: onProgress,
      currentImage: 1,
      totalImages: 1,
    );
  }

  /// Extracts text and transaction candidates from raw [imageBytes].
  Future<OcrResult> extractImageBytes(
    Uint8List imageBytes, {
    String filename = 'screenshot.png',
    OcrProgressCallback? onProgress,
  }) {
    return engine.extractImage(
      imageBytes,
      filename: filename,
      onProgress: onProgress,
      currentImage: 1,
      totalImages: 1,
    );
  }

  /// Extracts text and transaction candidates from a batch of image [files].
  /// Provides progress updates across images.
  Future<List<OcrResult>> extractImages(
    List<File> files, {
    OcrProgressCallback? onProgress,
  }) async {
    final List<OcrResult> results = [];
    final int total = files.length;

    for (int i = 0; i < total; i++) {
      final file = files[i];
      final bytes = await file.readAsBytes();
      final filename = file.uri.pathSegments.isNotEmpty
          ? file.uri.pathSegments.last
          : 'screenshot_${i + 1}.png';

      final res = await engine.extractImage(
        bytes,
        filename: filename,
        onProgress: onProgress,
        currentImage: i + 1,
        totalImages: total,
      );
      results.add(res);
    }

    return results;
  }

  /// Disposes and frees resources held by the OCR engine.
  Future<void> dispose() => engine.dispose();
}
