import 'extracted_transaction.dart';

/// Container for extraction output from one or more screenshot images.
class ExtractionResult {
  final List<ExtractedTransaction> transactions;
  final List<String> successfulImages;
  final List<String> failedImages;
  final List<String> errors;
  final String? debugOcrText;

  const ExtractionResult({
    required this.transactions,
    required this.successfulImages,
    this.failedImages = const [],
    this.errors = const [],
    this.debugOcrText,
  });

  /// Total number of transactions found across all screenshots.
  int get totalFound => transactions.length;

  /// Whether all images were processed successfully without partial failures.
  bool get isFullSuccess => failedImages.isEmpty;

  /// Whether any images succeeded while others failed.
  bool get isPartialSuccess =>
      successfulImages.isNotEmpty && failedImages.isNotEmpty;

  /// Whether all images failed.
  bool get isFullFailure => successfulImages.isEmpty && failedImages.isNotEmpty;
}
