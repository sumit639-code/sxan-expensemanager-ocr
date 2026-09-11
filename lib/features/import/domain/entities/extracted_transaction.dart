import 'package:intl/intl.dart';

import '../../../../core/utils/money_utils.dart';
import '../../../../shared/enums/transaction_enums.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';

/// Origin of a detected duplicate for an [ExtractedTransaction].
enum DuplicateSource {
  /// Matches a transaction already persisted in SQLite.
  existingDb,

  /// Matches another extracted transaction within the same import batch.
  intraBatch,
}

/// Domain model representing OCR/Vision extraction output before user confirmation.
///
/// Designed to support incomplete information gracefully (e.g. null merchant, date, or category).
class ExtractedTransaction {
  final String id;
  final DateTime? date;
  final int?
  amount; // Stored in minor units (paise/cents), null if extraction failed
  final String currency;
  final String? title;
  final String? merchant;
  final String? categoryId;
  final TransactionType type;
  final double confidence; // Range 0.0 to 1.0
  final String? sourceReference; // e.g. Image filename or identifier
  final String? rawText;
  final bool isDuplicate;
  final DuplicateSource? duplicateSource;
  final String? note;

  const ExtractedTransaction({
    required this.id,
    this.date,
    this.amount,
    this.currency = 'INR',
    this.title,
    this.merchant,
    this.categoryId,
    this.type = TransactionType.expense,
    this.confidence = 1.0,
    this.sourceReference,
    this.rawText,
    this.isDuplicate = false,
    this.duplicateSource,
    this.note,
  });

  /// User-friendly label for confidence level.
  ///
  /// - > 0.85: 'High confidence'
  /// - > 0.60: 'Medium confidence'
  /// - <= 0.60: 'Needs review'
  String get confidenceLabel {
    if (confidence > 0.85) return 'High confidence';
    if (confidence > 0.60) return 'Medium confidence';
    return 'Needs review';
  }

  /// Formatted monetary representation (e.g. "₹5,000.00").
  String get formattedAmount => MoneyUtils.formatMinorUnits(amount ?? 0);

  /// Whether confidence is low enough to warrant visual attention.
  bool get needsReview => confidence <= 0.60;

  /// Whether this extracted item has all required fields to be saved as a real Transaction.
  bool get isValidForImport {
    final hasAmount = amount != null && amount! > 0;
    final hasTitle =
        (title != null && title!.trim().isNotEmpty) ||
        (merchant != null && merchant!.trim().isNotEmpty);
    final hasDate = date != null;
    return hasAmount && hasTitle && hasDate;
  }

  /// Canonical fingerprint string used to detect duplicates.
  ///
  /// Normalized to lowercase and trimmed to compare "SWIGGY" and "swiggy" as identical.
  String get normalizedFingerprint {
    final rawTitle =
        (merchant?.trim().isNotEmpty == true
                ? merchant!
                : (title?.trim() ?? ''))
            .toLowerCase()
            .trim();
    final effectiveTitle = rawTitle.replaceAll(RegExp(r'\s+'), ' ');
    final dateKey = date != null
        ? DateFormat('yyyy-MM-dd').format(date!)
        : 'no-date';
    final amtKey = amount ?? 0;
    return '$dateKey|$amtKey|${type.name}|$effectiveTitle';
  }


  /// Converts this extracted transaction to a persistent [Transaction] entity with source=screenshot.
  ///
  /// Throws [StateError] if [isValidForImport] is false.
  Transaction toTransactionEntity({DateTime? now}) {
    if (!isValidForImport) {
      throw StateError(
        'Cannot convert incomplete ExtractedTransaction to Transaction entity: $id',
      );
    }

    final timestamp = now ?? DateTime.now();
    final effectiveTitle = (title != null && title!.trim().isNotEmpty)
        ? title!.trim()
        : (merchant ?? 'Screenshot Transaction');

    return Transaction(
      id: id,
      type: type,
      amount: amount!,
      currency: currency,
      title: effectiveTitle,
      merchant: merchant?.trim().isNotEmpty == true ? merchant!.trim() : null,
      categoryId: categoryId,
      date: date!,
      note: note,
      source: TransactionSource.screenshot,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }

  ExtractedTransaction copyWith({
    String? id,
    DateTime? date,
    int? amount,
    String? currency,
    String? title,
    String? merchant,
    String? categoryId,
    TransactionType? type,
    double? confidence,
    String? sourceReference,
    String? rawText,
    bool? isDuplicate,
    DuplicateSource? duplicateSource,
    String? note,
  }) {
    return ExtractedTransaction(
      id: id ?? this.id,
      date: date ?? this.date,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      title: title ?? this.title,
      merchant: merchant ?? this.merchant,
      categoryId: categoryId ?? this.categoryId,
      type: type ?? this.type,
      confidence: confidence ?? this.confidence,
      sourceReference: sourceReference ?? this.sourceReference,
      rawText: rawText ?? this.rawText,
      isDuplicate: isDuplicate ?? this.isDuplicate,
      duplicateSource: duplicateSource ?? this.duplicateSource,
      note: note ?? this.note,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ExtractedTransaction &&
        other.id == id &&
        other.date == date &&
        other.amount == amount &&
        other.currency == currency &&
        other.title == title &&
        other.merchant == merchant &&
        other.categoryId == categoryId &&
        other.type == type &&
        other.confidence == confidence &&
        other.sourceReference == sourceReference &&
        other.rawText == rawText &&
        other.isDuplicate == isDuplicate &&
        other.duplicateSource == duplicateSource &&
        other.note == note;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      date,
      amount,
      currency,
      title,
      merchant,
      categoryId,
      type,
      confidence,
      sourceReference,
      rawText,
      isDuplicate,
      duplicateSource,
      note,
    );
  }
}
