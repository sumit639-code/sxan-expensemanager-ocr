import 'extracted_transaction.dart';

/// Current state of an imported/shared batch of screenshots.
enum PendingImportStatus {
  /// Extraction/OCR is in progress.
  processing,

  /// Extraction finished and transactions are awaiting user review.
  readyForReview,

  /// Extraction failed or no transactions could be parsed.
  failed,

  /// User completed review and accepted/imported the transactions into SQLite.
  completed,

  /// User explicitly dismissed/discarded the import.
  discarded,
}

/// Represents an external or shared-intent image import job.
///
/// Keeps extracted financial data in a staged, pending area until
/// the user explicitly reviews and accepts it into SQLite.
class PendingImport {
  final String id;
  final List<String> imagePaths;
  final DateTime createdAt;
  final PendingImportStatus status;
  final List<ExtractedTransaction> extractedTransactions;
  final String? errorMessage;
  final String source;

  const PendingImport({
    required this.id,
    required this.imagePaths,
    required this.createdAt,
    this.status = PendingImportStatus.processing,
    this.extractedTransactions = const [],
    this.errorMessage,
    this.source = 'Shared from another app',
  });

  bool get isProcessing => status == PendingImportStatus.processing;
  bool get isReadyForReview => status == PendingImportStatus.readyForReview;
  bool get isFailed => status == PendingImportStatus.failed;
  bool get isCompleted => status == PendingImportStatus.completed;
  bool get isDiscarded => status == PendingImportStatus.discarded;

  int get transactionCount => extractedTransactions.length;

  PendingImport copyWith({
    String? id,
    List<String>? imagePaths,
    DateTime? createdAt,
    PendingImportStatus? status,
    List<ExtractedTransaction>? extractedTransactions,
    String? errorMessage,
    String? source,
  }) {
    return PendingImport(
      id: id ?? this.id,
      imagePaths: imagePaths ?? this.imagePaths,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      extractedTransactions:
          extractedTransactions ?? this.extractedTransactions,
      errorMessage: errorMessage ?? this.errorMessage,
      source: source ?? this.source,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'imagePaths': imagePaths,
      'createdAt': createdAt.toIso8601String(),
      'status': status.name,
      'extractedTransactions':
          extractedTransactions.map((tx) => tx.toJson()).toList(),
      'errorMessage': errorMessage,
      'source': source,
    };
  }

  factory PendingImport.fromJson(Map<String, dynamic> json) {
    return PendingImport(
      id: json['id'] as String,
      imagePaths: (json['imagePaths'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      createdAt: DateTime.parse(json['createdAt'] as String),
      status: PendingImportStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => PendingImportStatus.processing,
      ),
      extractedTransactions: (json['extractedTransactions'] as List<dynamic>?)
              ?.map((e) =>
                  ExtractedTransaction.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      errorMessage: json['errorMessage'] as String?,
      source: json['source'] as String? ?? 'Shared from another app',
    );
  }
}
