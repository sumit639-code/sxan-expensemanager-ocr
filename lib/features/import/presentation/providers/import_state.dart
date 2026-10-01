import '../../../../core/utils/money_utils.dart';
import '../../domain/entities/extracted_transaction.dart';

/// Status of the screenshot import pipeline.
enum ImportStatus {
  /// User is on the landing screen to select screenshots.
  initial,

  /// Screenshots are selected and previewed with add/remove controls.
  preview,

  /// Extraction and duplicate detection pipeline is running.
  processing,

  /// Extraction complete, user reviews and edits transactions.
  review,

  /// Transactions confirmed and saved to SQLite.
  completed,

  /// Fatal error encountered.
  error,
}

/// Immutable state model for the Screenshot Import feature.
class ImportState {
  final ImportStatus status;
  final List<String> selectedImagePaths;
  final String currentProcessingStep;
  final double processingProgress;
  final List<ExtractedTransaction> extractedTransactions;
  final Set<String> selectedTransactionIds;
  final List<String> failedImagePaths;
  final List<String> errors;
  final int importedCount;
  final int importedTotalAmount;
  final String? fatalErrorMessage;
  final String? debugOcrText;
  final List<String> currentPendingImportIds;

  const ImportState({
    this.status = ImportStatus.initial,
    this.selectedImagePaths = const [],
    this.currentProcessingStep = '',
    this.processingProgress = 0.0,
    this.extractedTransactions = const [],
    this.selectedTransactionIds = const {},
    this.failedImagePaths = const [],
    this.errors = const [],
    this.importedCount = 0,
    this.importedTotalAmount = 0,
    this.fatalErrorMessage,
    this.debugOcrText,
    this.currentPendingImportIds = const [],
  });

  /// Backwards compatibility getter for single pending import ID.
  String? get currentPendingImportId =>
      currentPendingImportIds.isNotEmpty ? currentPendingImportIds.first : null;

  /// Total number of extracted transactions found.
  int get totalCount => extractedTransactions.length;

  /// Number of currently selected transactions.
  int get selectedCount => selectedTransactionIds.length;

  /// Whether all extracted transactions are selected.
  bool get isAllSelected => totalCount > 0 && selectedCount == totalCount;

  /// Sum of amounts for currently checked transactions (in minor units / paise).
  int get selectedTotalAmount {
    int total = 0;
    for (final tx in extractedTransactions) {
      if (selectedTransactionIds.contains(tx.id) && tx.amount != null) {
        total += tx.amount!;
      }
    }
    return total;
  }

  /// Formatted string for the current selected total (e.g. ₹8,493.00).
  String get formattedSelectedTotal =>
      MoneyUtils.formatMinorUnits(selectedTotalAmount);

  /// Formatted string for the total amount imported.
  String get formattedImportedTotal =>
      MoneyUtils.formatMinorUnits(importedTotalAmount);

  /// Extracted transactions that are currently selected.
  List<ExtractedTransaction> get selectedTransactions {
    return extractedTransactions
        .where((tx) => selectedTransactionIds.contains(tx.id))
        .toList();
  }

  /// Count of transactions marked as duplicate.
  int get duplicateCount {
    return extractedTransactions.where((tx) => tx.isDuplicate).length;
  }

  /// Count of transactions that require user review (low confidence, duplicate, or warnings).
  int get needsReviewCount {
    return extractedTransactions.where((tx) => tx.needsReview).length;
  }

  ImportState copyWith({
    ImportStatus? status,
    List<String>? selectedImagePaths,
    String? currentProcessingStep,
    double? processingProgress,
    List<ExtractedTransaction>? extractedTransactions,
    Set<String>? selectedTransactionIds,
    List<String>? failedImagePaths,
    List<String>? errors,
    int? importedCount,
    int? importedTotalAmount,
    String? fatalErrorMessage,
    String? debugOcrText,
    String? currentPendingImportId,
    List<String>? currentPendingImportIds,
    bool clearPendingImportId = false,
  }) {
    List<String> resolvedPendingIds;
    if (clearPendingImportId) {
      resolvedPendingIds = const [];
    } else if (currentPendingImportIds != null) {
      resolvedPendingIds = currentPendingImportIds;
    } else if (currentPendingImportId != null) {
      resolvedPendingIds = [currentPendingImportId];
    } else {
      resolvedPendingIds = this.currentPendingImportIds;
    }

    return ImportState(
      status: status ?? this.status,
      selectedImagePaths: selectedImagePaths ?? this.selectedImagePaths,
      currentProcessingStep:
          currentProcessingStep ?? this.currentProcessingStep,
      processingProgress: processingProgress ?? this.processingProgress,
      extractedTransactions:
          extractedTransactions ?? this.extractedTransactions,
      selectedTransactionIds:
          selectedTransactionIds ?? this.selectedTransactionIds,
      failedImagePaths: failedImagePaths ?? this.failedImagePaths,
      errors: errors ?? this.errors,
      importedCount: importedCount ?? this.importedCount,
      importedTotalAmount: importedTotalAmount ?? this.importedTotalAmount,
      fatalErrorMessage: fatalErrorMessage,
      debugOcrText: debugOcrText ?? this.debugOcrText,
      currentPendingImportIds: resolvedPendingIds,
    );
  }
}

