import 'bounding_box.dart';
import 'amount_classification.dart';
import 'semantic_role.dart';

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
  final Map<SemanticRole, double> roleScores;

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
    this.roleScores = const {},
  });

  // 2D Spatial Geometry Helpers
  double get centerX => bbox.center.x;
  double get centerY => bbox.center.y;
  double get minX => bbox.minX;
  double get maxX => bbox.maxX;
  double get minY => bbox.minY;
  double get maxY => bbox.maxY;
  double get width => bbox.width;
  double get height => bbox.height;

  double normalizedX(double docWidth) => docWidth > 0 ? bbox.minX / docWidth : bbox.minX;
  double normalizedY(double docHeight) => docHeight > 0 ? bbox.minY / docHeight : bbox.minY;
  double normalizedWidth(double docWidth) => docWidth > 0 ? bbox.width / docWidth : bbox.width;
  double normalizedHeight(double docHeight) => docHeight > 0 ? bbox.height / docHeight : bbox.height;
  double normalizedCenterX(double docWidth) => docWidth > 0 ? centerX / docWidth : centerX;
  double normalizedCenterY(double docHeight) => docHeight > 0 ? centerY / docHeight : centerY;

  /// Top assigned semantic role, or [SemanticRole.unknown] if empty.
  SemanticRole get primaryRole {
    if (roleScores.isEmpty) return SemanticRole.unknown;
    var bestRole = SemanticRole.unknown;
    var bestScore = -1.0;
    for (final entry in roleScores.entries) {
      if (entry.value > bestScore) {
        bestScore = entry.value;
        bestRole = entry.key;
      }
    }
    return bestRole;
  }

  double scoreForRole(SemanticRole role) => roleScores[role] ?? 0.0;

  OcrItem copyWith({
    int? readingIndex,
    String? text,
    String? textNormalized,
    double? compositeScore,
    double? confidence,
    BoundingBox? bbox,
    String? tokenType,
    AmountClassification? amountClassification,
    bool? isNumericAmount,
    num? parsedIntegerAmount,
    String? currency,
    List<OcrCandidate>? candidates,
    Map<SemanticRole, double>? roleScores,
  }) {
    return OcrItem(
      readingIndex: readingIndex ?? this.readingIndex,
      text: text ?? this.text,
      textNormalized: textNormalized ?? this.textNormalized,
      compositeScore: compositeScore ?? this.compositeScore,
      confidence: confidence ?? this.confidence,
      bbox: bbox ?? this.bbox,
      tokenType: tokenType ?? this.tokenType,
      amountClassification: amountClassification ?? this.amountClassification,
      isNumericAmount: isNumericAmount ?? this.isNumericAmount,
      parsedIntegerAmount: parsedIntegerAmount ?? this.parsedIntegerAmount,
      currency: currency ?? this.currency,
      candidates: candidates ?? this.candidates,
      roleScores: roleScores ?? this.roleScores,
    );
  }

  factory OcrItem.fromJson(Map<String, dynamic> json) {
    final candidatesJson = json['candidates'] as List<dynamic>?;
    final rolesMapRaw = json['role_scores'] as Map<String, dynamic>?;
    final Map<SemanticRole, double> parsedRoles = {};
    if (rolesMapRaw != null) {
      for (final entry in rolesMapRaw.entries) {
        final role = SemanticRole.fromLabel(entry.key);
        final score = (entry.value as num?)?.toDouble() ?? 0.0;
        parsedRoles[role] = score;
      }
    }

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
      roleScores: parsedRoles,
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
      if (roleScores.isNotEmpty)
        'role_scores': {
          for (final entry in roleScores.entries) entry.key.label: entry.value,
        },
    };
  }

  @override
  String toString() => 'OcrItem(#$readingIndex: "$textNormalized" [$tokenType | ${primaryRole.label}] score: $compositeScore)';
}
