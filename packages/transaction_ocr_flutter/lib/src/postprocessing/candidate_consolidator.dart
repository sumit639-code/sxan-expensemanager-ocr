import '../core/models/bounding_box.dart';
import '../parsing/amount_classifier.dart';

/// Consolidated OCR candidate detection for internal ranking.
class CandidateDetection {
  final String text;
  final String textNormalized;
  final double confidence;
  final double compositeScore;
  final BoundingBox bbox;

  CandidateDetection({
    required this.text,
    required this.textNormalized,
    required this.confidence,
    required this.compositeScore,
    required this.bbox,
  });

  Map<String, dynamic> toJson() => {
        'text': text,
        'text_normalized': textNormalized,
        'confidence': confidence,
        'composite_score': compositeScore,
        'bbox': bbox.toJson(),
      };
}

/// Consolidated detection group representing one visual text region.
class ConsolidatedGroup {
  final String text;
  final String textNormalized;
  final double confidence;
  final double compositeScore;
  final BoundingBox bbox;
  final int candidatesCount;
  final List<CandidateDetection> candidates;

  ConsolidatedGroup({
    required this.text,
    required this.textNormalized,
    required this.confidence,
    required this.compositeScore,
    required this.bbox,
    required this.candidatesCount,
    required this.candidates,
  });

  Map<String, dynamic> toJson() => {
        'text': text,
        'text_normalized': textNormalized,
        'confidence': confidence,
        'composite_score': compositeScore,
        'bbox': bbox.toJson(),
        'candidates_count': candidatesCount,
        'candidates': candidates.map((c) => c.toJson()).toList(),
      };
}

/// Consolidates and ranks overlapping OCR detection candidates.
/// Direct port of Python `src/ocr/candidate_consolidator.py`.
class OcrCandidateConsolidator {
  /// Normalizes common symbol misreads.
  static String normalizeSymbolCandidate(String text) {
    return AmountClassifier.normalizeSymbol(text);
  }

  /// Calculates a ranking score for a candidate detection based on:
  /// - Base confidence
  /// - Currency symbol presence (₹, Rs, INR)
  /// - Financial amount formatting and Indian comma placement
  /// - Noise / CJK character penalty
  static double scoreCandidate(
    String text,
    double confidence, {
    bool groupHasRupeeSymbol = false,
  }) {
    final normText = normalizeSymbolCandidate(text);
    var score = confidence;

    // 1. Currency symbol presence
    if (text.contains('₹') || text.contains('Rs') || text.contains('INR')) {
      score += 0.40;
    } else if (normText.contains('₹')) {
      score += 0.25; // Normalized symbol bonus (e.g., R20 -> ₹20)
    }

    // 2. Financial Amount Pattern Match (+0.30)
    final cleanNoCurr = normText
        .replaceAll(RegExp(r'[₹\$]|inr|rs\.?', caseSensitive: false), '')
        .trim();
    if (RegExp(r'^\d{1,3}(,\d{2,3})*(\.\d{2})?$').hasMatch(cleanNoCurr)) {
      score += 0.30;
    }

    // 3. Indian comma placement (+0.15)
    if (RegExp(r'\d{1,2},\d{3}').hasMatch(cleanNoCurr)) {
      score += 0.15;
    }

    // 4. Noise Penalty for Chinese / non-ASCII unexpected characters (-0.50)
    if (RegExp(r'[\u4e00-\u9fff]').hasMatch(text)) {
      score -= 0.50;
    }

    // 5. Length penalty for extreme single-character OCR garbage
    if (text.length == 1 && !'1234567890₹'.contains(text)) {
      score -= 0.20;
    }

    return double.parse(score.toStringAsFixed(4));
  }

  /// Groups overlapping raw OCR detections into candidate clusters.
  static List<List<Map<String, dynamic>>> groupDetections(
    List<Map<String, dynamic>> detections,
  ) {
    final List<List<Map<String, dynamic>>> groups = [];

    for (final det in detections) {
      final bbox = det['bbox'] is BoundingBox
          ? det['bbox'] as BoundingBox
          : BoundingBox.fromJson(det['bbox'] as List<dynamic>);

      List<Map<String, dynamic>>? matchedGroup;

      for (final grp in groups) {
        final hasOverlap = grp.any((member) {
          final memberBbox = member['bbox'] is BoundingBox
              ? member['bbox'] as BoundingBox
              : BoundingBox.fromJson(member['bbox'] as List<dynamic>);
          return bbox.isSpatiallyOverlapping(memberBbox);
        });

        if (hasOverlap) {
          matchedGroup = grp;
          break;
        }
      }

      if (matchedGroup != null) {
        matchedGroup.add(det);
      } else {
        groups.add([det]);
      }
    }

    return groups;
  }

  /// Consolidates raw detections into ranked groups.
  static List<ConsolidatedGroup> consolidate(
    List<Map<String, dynamic>> rawDetections,
  ) {
    final groups = groupDetections(rawDetections);
    final List<ConsolidatedGroup> consolidated = [];

    for (final grp in groups) {
      final hasRupee = grp.any((c) => (c['text'] as String? ?? '').contains('₹'));

      final List<CandidateDetection> scoredCandidates = [];
      for (final cand in grp) {
        final text = cand['text'] as String? ?? '';
        final conf = (cand['confidence'] as num?)?.toDouble() ?? 0.0;
        final score = scoreCandidate(text, conf, groupHasRupeeSymbol: hasRupee);
        final normText = normalizeSymbolCandidate(text);
        final bbox = cand['bbox'] is BoundingBox
            ? cand['bbox'] as BoundingBox
            : BoundingBox.fromJson(cand['bbox'] as List<dynamic>);

        scoredCandidates.add(CandidateDetection(
          text: text,
          textNormalized: normText,
          confidence: conf,
          compositeScore: score,
          bbox: bbox,
        ));
      }

      // Sort descending by composite score, then confidence
      scoredCandidates.sort((a, b) {
        final cmp = b.compositeScore.compareTo(a.compositeScore);
        if (cmp != 0) return cmp;
        return b.confidence.compareTo(a.confidence);
      });

      final best = scoredCandidates.first;

      consolidated.add(ConsolidatedGroup(
        text: best.text,
        textNormalized: best.textNormalized,
        confidence: best.confidence,
        compositeScore: best.compositeScore,
        bbox: best.bbox,
        candidatesCount: scoredCandidates.length,
        candidates: scoredCandidates,
      ));
    }

    return consolidated;
  }
}
