import 'dart:math';
import '../core/models/bounding_box.dart';
import '../core/models/ocr_item.dart';
import '../core/models/semantic_role.dart';

/// Result of merchant entity extraction and scoring.
class MerchantScoringResult {
  final String? name;
  final BoundingBox? bbox;
  final double confidence;
  final List<OcrItem> sourceTokens;

  const MerchantScoringResult({
    this.name,
    this.bbox,
    required this.confidence,
    this.sourceTokens = const [],
  });
}

/// App-agnostic merchant and entity name scorer.
///
/// Discovers and evaluates merchant / person entities both with direction prefixes
/// (e.g. "Paid to Rahul Sharma", "Beneficiary: Cafe 47") and prefix-free layouts
/// (e.g. "Rahul Sharma      ₹500"), with full support for entities containing digits
/// (e.g. "7-Eleven", "3M Car Care", "Cafe 47", "Sector 18 Petrol Pump").
class MerchantEntityScorer {
  static final RegExp _reDirectionPrefix = RegExp(
    r'^(?:paid\s+to|payment\s+to|sent\s+to|transferred\s+to|received\s+from|from|to|merchant\s*:?|beneficiary\s*:?|payee\s*:?)\s+',
    caseSensitive: false,
  );

  static final RegExp _reAccountOrBanking = RegExp(
    r'\b(?:debited\s+from|credited\s+to|savings\s+account|bank|a\/c|account|xx\d{2,4}|\*{2,}\d{2,4}|upi\s*id|vpa|google\s*transaction\s*id|utr|rrn)\b',
    caseSensitive: false,
  );

  static final RegExp _reSystemOrNoise = RegExp(
    r'\b(?:payment\s+successful|paid\s+successfully|transaction\s+successful|completed|failed|view\s+history|history|home|search|filter|share|pay\s+again|open\s+maps|check\s+balance)\b',
    caseSensitive: false,
  );

  /// Cleans known direction/beneficiary prefixes from a text line.
  static String cleanPrefix(String text) {
    var cleaned = text.trim();
    final m = _reDirectionPrefix.firstMatch(cleaned);
    if (m != null) {
      cleaned = cleaned.substring(m.end).trim();
    }
    return cleaned;
  }

  /// Evaluates and extracts the best merchant candidate from a set of [candidateTokens]
  /// associated with a specific transaction.
  static MerchantScoringResult scoreCandidate({
    required List<OcrItem> candidateTokens,
    required BoundingBox amountBbox,
    BoundingBox? dateBbox,
    BoundingBox? directionAnchorBbox,
    int imgWidth = 0,
    int imgHeight = 0,
  }) {
    if (candidateTokens.isEmpty) {
      return const MerchantScoringResult(confidence: 0.0);
    }

    // Filter out obvious non-merchants (amounts, dates, pure noise)
    final filtered = candidateTokens.where((item) {
      final role = item.primaryRole;
      if (role == SemanticRole.amountPrimary ||
          role == SemanticRole.amountSecondary ||
          role == SemanticRole.date ||
          role == SemanticRole.time ||
          role == SemanticRole.dateTime ||
          role == SemanticRole.systemChrome ||
          role == SemanticRole.navigation ||
          role == SemanticRole.status ||
          role == SemanticRole.header ||
          role == SemanticRole.transactionReference ||
          role == SemanticRole.accountNumber) {
        return false;
      }
      final text = item.textNormalized.trim();
      if (text.isEmpty || text.length < 2) return false;
      if (text.contains('@')) return false; // VPA handle
      if (_reAccountOrBanking.hasMatch(text)) return false;
      if (_reSystemOrNoise.hasMatch(text)) return false;
      return true;
    }).toList();

    if (filtered.isEmpty) {
      return const MerchantScoringResult(confidence: 0.0);
    }

    // Score individual tokens
    final scoredItems = <OcrItem, double>{};
    for (final item in filtered) {
      final text = item.textNormalized.trim();
      final cleaned = cleanPrefix(text);
      if (cleaned.isEmpty) continue;

      var score = 0.50;

      // 1. Text morphology: letters vs digits
      final letters = RegExp(r'[a-zA-Z]').allMatches(cleaned).length;
      final digits = RegExp(r'\d').allMatches(cleaned).length;

      if (letters >= 2) {
        score += 0.20;
      }
      // Capitalization bonus: First letter capitalized or Title Case
      if (RegExp(r'^[A-Z]').hasMatch(cleaned)) {
        score += 0.15;
      }
      if (RegExp(r'^[A-Z][a-z]+(?:\s+[A-Z][a-z]+)*$').hasMatch(cleaned)) {
        score += 0.10;
      }

      // Digit-tolerant entity handling (e.g. "7-Eleven", "3M Car Care", "Cafe 47")
      if (digits > 0) {
        if (letters >= digits) {
          score += 0.05; // Valid mixed entity
        } else {
          score -= 0.30; // Mostly numbers
        }
      }

      // Length heuristic: reasonable entity names are between 3 and 40 chars
      if (cleaned.length >= 3 && cleaned.length <= 35) {
        score += 0.10;
      } else if (cleaned.length > 50) {
        score -= 0.20;
      }

      // 2. Spatial proximity to amount
      final dy = (item.centerY - amountBbox.center.y).abs();
      if (dy < 60) {
        score += 0.15;
      } else if (dy < 120) {
        score += 0.05;
      } else {
        score -= 0.10;
      }

      // Proximity to direction anchor ("Paid to", "Sent to") if present
      if (directionAnchorBbox != null) {
        final distToAnchorY = item.centerY - directionAnchorBbox.center.y;
        if (distToAnchorY >= 0 && distToAnchorY < 120) {
          score += 0.25; // Directly below or beside anchor
        }
      }

      // OCR engine confidence
      score += (item.confidence * 0.10);

      scoredItems[item] = score.clamp(0.0, 1.0);
    }

    if (scoredItems.isEmpty) {
      return const MerchantScoringResult(confidence: 0.0);
    }

    // Select the best scoring token
    var bestItem = scoredItems.keys.first;
    var bestScore = scoredItems[bestItem]!;
    for (final entry in scoredItems.entries) {
      if (entry.value > bestScore) {
        bestScore = entry.value;
        bestItem = entry.key;
      }
    }

    // Group adjacent tokens on the same horizontal line (within 25px vertically)
    final sameLineTokens = filtered.where((item) {
      final dy = (item.centerY - bestItem.centerY).abs();
      return dy <= 25;
    }).toList();

    sameLineTokens.sort((a, b) => a.minX.compareTo(b.minX));

    final nameParts = <String>[];
    double minX = sameLineTokens.first.minX;
    double minY = sameLineTokens.first.minY;
    double maxX = sameLineTokens.first.maxX;
    double maxY = sameLineTokens.first.maxY;

    // Deduplicate words (e.g. repeated logo/title tokens)
    final seenWords = <String>{};
    for (final item in sameLineTokens) {
      final cleaned = cleanPrefix(item.textNormalized.isNotEmpty ? item.textNormalized : item.text);
      if (cleaned.isEmpty) continue;

      final lower = cleaned.toLowerCase();
      if (!seenWords.contains(lower)) {
        seenWords.add(lower);
        nameParts.add(cleaned);
      }

      minX = min(minX, item.minX);
      minY = min(minY, item.minY);
      maxX = max(maxX, item.maxX);
      maxY = max(maxY, item.maxY);
    }

    final finalName = nameParts.join(' ').trim();
    if (finalName.isEmpty) {
      return const MerchantScoringResult(confidence: 0.0);
    }

    return MerchantScoringResult(
      name: finalName,
      bbox: BoundingBox.fromRect(minX, minY, maxX, maxY),
      confidence: bestScore,
      sourceTokens: sameLineTokens,
    );
  }
}
