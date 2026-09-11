import 'bounding_box.dart';

/// Represents a grouped transaction candidate row extracted from an OCR screenshot.
/// Matches Python V2 TransactionGrouper candidate output structure.
class ExtractedTransaction {
  final String amountTextRaw;
  final String amountTextNormalized;
  final num? amountValue;
  final int? amountMinorUnits;
  final double amountConfidence;
  final BoundingBox? amountBbox;
  final String? merchantText;
  final BoundingBox? merchantBbox;
  final String? dateText;
  final BoundingBox? dateBbox;
  final double groupingConfidence;
  final String transactionType; // 'expense', 'income', 'uncertain'
  final List<String> warnings;

  const ExtractedTransaction({
    required this.amountTextRaw,
    required this.amountTextNormalized,
    this.amountValue,
    this.amountMinorUnits,
    required this.amountConfidence,
    this.amountBbox,
    this.merchantText,
    this.merchantBbox,
    this.dateText,
    this.dateBbox,
    required this.groupingConfidence,
    this.transactionType = 'expense',
    this.warnings = const [],
  });

  factory ExtractedTransaction.fromJson(Map<String, dynamic> json) {
    return ExtractedTransaction(
      amountTextRaw: json['amount_text_raw'] as String? ?? '',
      amountTextNormalized: json['amount_text_normalized'] as String? ?? '',
      amountValue: json['amount_value'] as num?,
      amountMinorUnits: json['amount_minor_units'] as int?,
      amountConfidence: (json['amount_confidence'] as num?)?.toDouble() ?? 0.0,
      amountBbox: json['amount_bbox'] != null ? BoundingBox.fromJson(json['amount_bbox'] as List<dynamic>) : null,
      merchantText: json['merchant_text'] as String?,
      merchantBbox: json['merchant_bbox'] != null ? BoundingBox.fromJson(json['merchant_bbox'] as List<dynamic>) : null,
      dateText: json['date_text'] as String?,
      dateBbox: json['date_bbox'] != null ? BoundingBox.fromJson(json['date_bbox'] as List<dynamic>) : null,
      groupingConfidence: (json['grouping_confidence'] as num?)?.toDouble() ?? 0.0,
      transactionType: json['transaction_type'] as String? ?? 'expense',
      warnings: (json['warnings'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'amount_text_raw': amountTextRaw,
      'amount_text_normalized': amountTextNormalized,
      'amount_value': amountValue,
      'amount_minor_units': amountMinorUnits,
      'amount_confidence': amountConfidence,
      'amount_bbox': amountBbox?.toJson(),
      'merchant_text': merchantText,
      'merchant_bbox': merchantBbox?.toJson(),
      'date_text': dateText,
      'date_bbox': dateBbox?.toJson(),
      'grouping_confidence': groupingConfidence,
      'transaction_type': transactionType,
      if (warnings.isNotEmpty) 'warnings': warnings,
    };
  }

  @override
  String toString() =>
      'ExtractedTransaction(merchant: $merchantText, amount: $amountValue ($amountTextNormalized, minor: $amountMinorUnits), type: $transactionType, date: $dateText, conf: $groupingConfidence)';
}

