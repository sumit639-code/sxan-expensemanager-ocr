import 'bounding_box.dart';

/// Represents a grouped transaction candidate row extracted from an OCR screenshot.
/// Matches Python V2 TransactionGrouper candidate output structure.
class ExtractedTransaction {
  final String amountTextRaw;
  final String amountTextNormalized;
  final num? amountValue;
  final double amountConfidence;
  final BoundingBox? amountBbox;
  final String? merchantText;
  final BoundingBox? merchantBbox;
  final String? dateText;
  final BoundingBox? dateBbox;
  final double groupingConfidence;

  const ExtractedTransaction({
    required this.amountTextRaw,
    required this.amountTextNormalized,
    this.amountValue,
    required this.amountConfidence,
    this.amountBbox,
    this.merchantText,
    this.merchantBbox,
    this.dateText,
    this.dateBbox,
    required this.groupingConfidence,
  });

  factory ExtractedTransaction.fromJson(Map<String, dynamic> json) {
    return ExtractedTransaction(
      amountTextRaw: json['amount_text_raw'] as String? ?? '',
      amountTextNormalized: json['amount_text_normalized'] as String? ?? '',
      amountValue: json['amount_value'] as num?,
      amountConfidence: (json['amount_confidence'] as num?)?.toDouble() ?? 0.0,
      amountBbox: json['amount_bbox'] != null ? BoundingBox.fromJson(json['amount_bbox'] as List<dynamic>) : null,
      merchantText: json['merchant_text'] as String?,
      merchantBbox: json['merchant_bbox'] != null ? BoundingBox.fromJson(json['merchant_bbox'] as List<dynamic>) : null,
      dateText: json['date_text'] as String?,
      dateBbox: json['date_bbox'] != null ? BoundingBox.fromJson(json['date_bbox'] as List<dynamic>) : null,
      groupingConfidence: (json['grouping_confidence'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'amount_text_raw': amountTextRaw,
      'amount_text_normalized': amountTextNormalized,
      'amount_value': amountValue,
      'amount_confidence': amountConfidence,
      'amount_bbox': amountBbox?.toJson(),
      'merchant_text': merchantText,
      'merchant_bbox': merchantBbox?.toJson(),
      'date_text': dateText,
      'date_bbox': dateBbox?.toJson(),
      'grouping_confidence': groupingConfidence,
    };
  }

  @override
  String toString() =>
      'ExtractedTransaction(merchant: $merchantText, amount: $amountValue ($amountTextNormalized), date: $dateText, conf: $groupingConfidence)';
}
