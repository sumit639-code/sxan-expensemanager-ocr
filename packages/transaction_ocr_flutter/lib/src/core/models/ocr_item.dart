import 'bounding_box.dart';
import 'amount_classification.dart';

/// Candidate OCR detection for alternative hypotheses in overlapping clusters.
class OcrCandidate {
  final String text;
  final String textNormalized;
  final double confidence;
  final double compositeScore;
  final BoundingBox bbox;

  const OcrCandidate({
    required this.text,
    required this.textNormalized,
    required this.confidence,
    required this.compositeScore,
    required this.bbox,
  });

  factory OcrCandidate.fromJson(Map<String, dynamic> json) {
    return OcrCandidate(
      text: json['text'] as String? ?? '',
      textNormalized: json['text_normalized'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      compositeScore: (json['composite_score'] as num?)?.toDouble() ?? 0.0,
      bbox: BoundingBox.fromJson(json['bbox'] as List<dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'text_normalized': textNormalized,
      'confidence': confidence,
      'composite_score': compositeScore,
      'bbox': bbox.toJson(),
    };
  }
}

/// Represents an individual OCR detection item with V2 token tagging and classification.
class OcrItem {
  final int readingIndex;
  final String text;
  final String textNormalized;
  final double compositeScore;
  final double confidence;
  final BoundingBox bbox;
  final String tokenType; // 'amount', 'date', 'merchant', 'noise', 'unknown'
  final AmountClassification? amountClassification;
  final bool isNumericAmount;
  final num? parsedIntegerAmount;
  final String? currency;
  final List<OcrCandidate>? candidates;

  const OcrItem({
    required this.readingIndex,
    required this.text,
    required this.textNormalized,
    required this.compositeScore,
    required this.confidence,
    required this.bbox,
    this.tokenType = 'unknown',
    this.amountClassification,
    this.isNumericAmount = false,
    this.parsedIntegerAmount,
    this.currency,
    this.candidates,
  });

  factory OcrItem.fromJson(Map<String, dynamic> json) {
    final candidatesJson = json['candidates'] as List<dynamic>?;
    return OcrItem(
      readingIndex: json['reading_index'] as int? ?? 0,
      text: json['text'] as String? ?? '',
      textNormalized: json['text_normalized'] as String? ?? '',
      compositeScore: (json['composite_score'] as num?)?.toDouble() ?? 0.0,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      bbox: BoundingBox.fromJson(json['bbox'] as List<dynamic>),
      tokenType: json['token_type'] as String? ?? 'unknown',
      amountClassification: json['amount_classification'] != null
          ? AmountClassification.fromJson(json['amount_classification'] as Map<String, dynamic>)
          : null,
      isNumericAmount: json['is_numeric_amount'] as bool? ?? false,
      parsedIntegerAmount: json['parsed_integer_amount'] as num?,
      currency: json['currency'] as String?,
      candidates: candidatesJson?.map((c) => OcrCandidate.fromJson(c as Map<String, dynamic>)).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'reading_index': readingIndex,
      'text': text,
      'text_normalized': textNormalized,
      'composite_score': compositeScore,
      'confidence': confidence,
      'bbox': bbox.toJson(),
      'token_type': tokenType,
      if (amountClassification != null) 'amount_classification': amountClassification!.toJson(),
      'is_numeric_amount': isNumericAmount,
      if (parsedIntegerAmount != null) 'parsed_integer_amount': parsedIntegerAmount,
      if (currency != null) 'currency': currency,
      if (candidates != null) 'candidates': candidates!.map((c) => c.toJson()).toList(),
    };
  }

  @override
  String toString() => 'OcrItem(#$readingIndex: "$textNormalized" [$tokenType] score: $compositeScore)';
}
