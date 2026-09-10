import '../entities/extraction_result.dart';
import '../services/duplicate_detector.dart';
import '../services/transaction_extractor.dart';

/// UseCase that coordinates screenshot extraction and duplicate detection.
class ProcessScreenshotsUseCase {
  final TransactionExtractor _extractor;
  final DuplicateDetector _duplicateDetector;

  const ProcessScreenshotsUseCase(this._extractor, this._duplicateDetector);

  /// Processes screenshot images and enriches results with duplicate detection.
  Future<ExtractionResult> execute(
    List<String> imagePaths, {
    void Function(String step, double progress)? onProgress,
  }) async {
    if (imagePaths.isEmpty) {
      return const ExtractionResult(
        transactions: [],
        successfulImages: [],
        errors: ['No images provided for processing'],
      );
    }

    // 1. Run extraction
    final rawResult = await _extractor.extractTransactions(
      imagePaths,
      onProgress: onProgress,
    );

    // 2. Report duplicate checking step
    onProgress?.call('Checking duplicates...', 0.90);

    // 3. Enrich with duplicate detection
    final transactionsWithDuplicates = await _duplicateDetector
        .detectDuplicates(rawResult.transactions);

    onProgress?.call('Preparing review...', 1.0);

    return ExtractionResult(
      transactions: transactionsWithDuplicates,
      successfulImages: rawResult.successfulImages,
      failedImages: rawResult.failedImages,
      errors: rawResult.errors,
    );
  }
}
