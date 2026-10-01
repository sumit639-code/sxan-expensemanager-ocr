/// Result of classifying a text token as a financial amount.
/// Matches Python AmountClassifier output structure.
class AmountClassification {
  final bool isAmount;
  final num? parsedValue;
  final int? parsedMinorUnits;
  final String normalizedText;
  final String? rejectionReason;
  final bool hasCurrencySymbol;
  final bool? spatialRightAligned;

  const AmountClassification({
    required this.isAmount,
    this.parsedValue,
    this.parsedMinorUnits,
    required this.normalizedText,
    this.rejectionReason,
    this.hasCurrencySymbol = false,
    this.spatialRightAligned,
  });

  factory AmountClassification.fromJson(Map<String, dynamic> json) {
    return AmountClassification(
      isAmount: json['is_amount'] as bool? ?? false,
      parsedValue: json['parsed_value'] as num?,
      parsedMinorUnits: json['parsed_minor_units'] as int?,
      normalizedText: json['normalized_text'] as String? ?? '',
      rejectionReason: json['rejection_reason'] as String?,
      hasCurrencySymbol: json['has_currency_symbol'] as bool? ?? false,
      spatialRightAligned: json['spatial_right_aligned'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'is_amount': isAmount,
      'parsed_value': parsedValue,
      'parsed_minor_units': parsedMinorUnits,
      'normalized_text': normalizedText,
      'rejection_reason': rejectionReason,
      'has_currency_symbol': hasCurrencySymbol,
      if (spatialRightAligned != null) 'spatial_right_aligned': spatialRightAligned,
    };
  }

  @override
  String toString() =>
      'AmountClassification(isAmount: $isAmount, parsedValue: $parsedValue, minorUnits: $parsedMinorUnits, normalizedText: $normalizedText, reason: $rejectionReason)';
}

