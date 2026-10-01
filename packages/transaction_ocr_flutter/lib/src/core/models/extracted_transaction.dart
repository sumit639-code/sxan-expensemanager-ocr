import 'bounding_box.dart';

/// Represents a grouped transaction candidate row extracted from an OCR screenshot.
/// Universally structured with field-level confidence, warnings, and OCR debugging evidence.
class ExtractedTransaction {
  final String amountTextRaw;
  final String amountTextNormalized;
  final num? amountValue;
  final int? amountMinorUnits;
  final double amountConfidence;
  final BoundingBox? amountBbox;

  final String? merchantText;
  final BoundingBox? merchantBbox;
  final double merchantConfidence;

  final String? dateText;
  final BoundingBox? dateBbox;
  final double dateConfidence;

  final String transactionType; // 'expense', 'income', 'uncertain'
  final double typeConfidence;

  final double groupingConfidence;
  final double? _transactionConfidence;
  final bool? _needsReview;

  final String? categorySuggestion;
  final List<String> warnings;
  final Map<String, dynamic>? ocrEvidence;

  const ExtractedTransaction({
    required this.amountTextRaw,
    required this.amountTextNormalized,
    this.amountValue,
    this.amountMinorUnits,
    required this.amountConfidence,
    this.amountBbox,
    this.merchantText,
    this.merchantBbox,
    this.merchantConfidence = 1.0,
    this.dateText,
    this.dateBbox,
    this.dateConfidence = 1.0,
    required this.groupingConfidence,
    this.transactionType = 'expense',
    this.typeConfidence = 1.0,
    double? transactionConfidence,
    bool? needsReview,
    this.categorySuggestion,
    this.warnings = const [],
    this.ocrEvidence,
  })  : _transactionConfidence = transactionConfidence,
        _needsReview = needsReview;

  double get transactionConfidence =>
      _transactionConfidence ??
      (groupingConfidence * 0.4 +
          amountConfidence * 0.3 +
          merchantConfidence * 0.15 +
          dateConfidence * 0.15);

  bool get needsReview =>
      _needsReview ??
      (amountConfidence < 0.70 ||
          merchantConfidence < 0.50 ||
          dateConfidence < 0.40 ||
          groupingConfidence < 0.60 ||
          warnings.isNotEmpty);

  factory ExtractedTransaction.fromJson(Map<String, dynamic> json) {
    final amtConf = (json['amount_confidence'] as num?)?.toDouble() ?? 0.0;
    final grpConf = (json['grouping_confidence'] as num?)?.toDouble() ?? 0.0;
    final merConf = (json['merchant_confidence'] as num?)?.toDouble() ?? 1.0;
    final dtConf = (json['date_confidence'] as num?)?.toDouble() ?? 1.0;
    final typConf = (json['type_confidence'] as num?)?.toDouble() ?? 1.0;
    final txConf = (json['transaction_confidence'] as num?)?.toDouble();

    return ExtractedTransaction(
      amountTextRaw: json['amount_text_raw'] as String? ?? '',
      amountTextNormalized: json['amount_text_normalized'] as String? ?? '',
      amountValue: json['amount_value'] as num?,
      amountMinorUnits: json['amount_minor_units'] as int?,
      amountConfidence: amtConf,
      amountBbox: json['amount_bbox'] != null
          ? BoundingBox.fromJson(json['amount_bbox'] as List<dynamic>)
          : null,
      merchantText: json['merchant_text'] as String?,
      merchantBbox: json['merchant_bbox'] != null
          ? BoundingBox.fromJson(json['merchant_bbox'] as List<dynamic>)
          : null,
      merchantConfidence: merConf,
      dateText: json['date_text'] as String?,
      dateBbox: json['date_bbox'] != null
          ? BoundingBox.fromJson(json['date_bbox'] as List<dynamic>)
          : null,
      dateConfidence: dtConf,
      groupingConfidence: grpConf,
      transactionType: json['transaction_type'] as String? ?? 'expense',
      typeConfidence: typConf,
      transactionConfidence: txConf,
      needsReview: json['needs_review'] as bool?,
      categorySuggestion: json['category_suggestion'] as String?,
      warnings: (json['warnings'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      ocrEvidence: json['ocr_evidence'] as Map<String, dynamic>?,
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
      'merchant_confidence': merchantConfidence,
      'date_text': dateText,
      'date_bbox': dateBbox?.toJson(),
      'date_confidence': dateConfidence,
      'grouping_confidence': groupingConfidence,
      'transaction_type': transactionType,
      'type_confidence': typeConfidence,
      'transaction_confidence': transactionConfidence,
      'needs_review': needsReview,
      if (categorySuggestion != null) 'category_suggestion': categorySuggestion,
      if (warnings.isNotEmpty) 'warnings': warnings,
      if (ocrEvidence != null) 'ocr_evidence': ocrEvidence,
    };
  }

  @override
  String toString() =>
      'ExtractedTransaction(merchant: $merchantText (conf: $merchantConfidence), amount: $amountValue ($amountTextNormalized, minor: $amountMinorUnits, conf: $amountConfidence), type: $transactionType, date: $dateText, txConf: $transactionConfidence, needsReview: $needsReview)';
}
