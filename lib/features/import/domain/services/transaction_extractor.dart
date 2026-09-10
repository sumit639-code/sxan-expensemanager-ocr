import '../entities/extraction_result.dart';

/// Abstract interface for extracting financial transactions from screenshot images.
///
/// Completely decoupled from any specific OCR / AI vendor (Gemini, Claude, ML Kit, etc.).
abstract class TransactionExtractor {
  /// Extracts transactions from the given list of validated image file paths.
  ///
  /// Callers may listen to an optional progress callback.
  Future<ExtractionResult> extractTransactions(
    List<String> imagePaths, {
    void Function(String step, double progress)? onProgress,
  });
}
