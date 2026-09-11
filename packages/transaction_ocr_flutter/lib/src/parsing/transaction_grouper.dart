import 'dart:math';
import '../core/models/bounding_box.dart';
import '../core/models/extracted_transaction.dart';
import 'amount_classifier.dart';

/// Classified token during spatial grouping.
class ClassifiedToken {
  final String text;
  final String textNormalized;
  final double confidence;
  final double compositeScore;
  final BoundingBox bbox;
  final String tokenType; // 'amount', 'date', 'merchant', 'noise', 'unknown'
  final Map<String, dynamic>? amountClassification;

  ClassifiedToken({
    required this.text,
    required this.textNormalized,
    required this.confidence,
    required this.compositeScore,
    required this.bbox,
    required this.tokenType,
    this.amountClassification,
  });

  Map<String, dynamic> toJson() => {
        'text': text,
        'text_normalized': textNormalized,
        'confidence': confidence,
        'composite_score': compositeScore,
        'bbox': bbox.toJson(),
        'token_type': tokenType,
        if (amountClassification != null) 'amount_classification': amountClassification,
      };
}

/// Result of TransactionGrouper grouping.
class GrouperResult {
  final List<ClassifiedToken> tokenClassifications;
  final List<ExtractedTransaction> transactionCandidates;
  final List<ClassifiedToken> noiseTokens;

  GrouperResult({
    required this.tokenClassifications,
    required this.transactionCandidates,
    required this.noiseTokens,
  });
}

/// V2 Spatial Transaction Row Grouper.
/// Direct port of Python `src/ocr/transaction_grouper.py`.
///
/// Layout model for PhonePe/GPay UPI transaction history screenshots:
///     [avatar]  MERCHANT NAME                      ₹AMOUNT
///               date label (e.g. "3 September")
class TransactionGrouper {
  static final RegExp _reDateLabel = RegExp(
    r'^\s*(?:'
    r'\d{1,2}\s*(?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*(?:\s*\d{2,4})?(?:at.*)?'
    r'|'
    r'(?:january|february|march|april|may|june|july|august|september|october|november|december)\s+\d{4}'
    r'|'
    r'\d+\s+(?:hour|hours|day|days|min|mins|minute|minutes)\s+ago'
    r'|'
    r'(?:yesterday|today)'
    r')\s*$',
    caseSensitive: false,
  );

  static const Set<String> _uiNoise = {
    'searchtransactions',
    'search transactions',
    'status',
    'payment method',
    'date',
    'amount',
    'amo',
    'search',
    'paymentmethod',
    'filter',
    'all',
  };

  static const double amountLeftThreshold = 0.50;
  static const double merchantRightThreshold = 0.70;
  static const double avatarRightThreshold = 0.12;
  static const double merchantYBand = 1.2; // +/- 1.2 row heights
  static const double dateYBandBelow = 2.0; // up to 2.0 row heights below merchant

  /// Main grouping entry point.
  static GrouperResult group({
    required List<Map<String, dynamic>> detections,
    required int imgWidth,
    required int imgHeight,
  }) {
    if (detections.isEmpty) {
      return GrouperResult(
        tokenClassifications: [],
        transactionCandidates: [],
        noiseTokens: [],
      );
    }

    final rowH = _estimateRowHeight(detections);

    // ── Step 1: Classify each detection ──────────────────────────────
    final classified = _classifyTokens(detections, imgWidth, imgHeight);

    final amounts = classified.where((t) => t.tokenType == 'amount').toList();
    final dates = classified.where((t) => t.tokenType == 'date').toList();
    final merchants = classified.where((t) => t.tokenType == 'merchant').toList();

    // ── Step 2: For each amount, find matching merchant lines + date ──
    final List<ExtractedTransaction> candidates = [];
    final Set<int> usedMerchantIndices = {};
    final Set<int> usedDateIndices = {};

    // Sort amounts top-to-bottom
    amounts.sort((a, b) => a.bbox.center.y.compareTo(b.bbox.center.y));

    for (final amtTok in amounts) {
      final amtCy = amtTok.bbox.center.y;

      // 1. Multi-line merchant grouping: find all merchant tokens for this row
      final merchantIndices = _findMerchantsInRow(
        merchants: merchants,
        amtCy: amtCy,
        amtBbox: amtTok.bbox,
        rowH: rowH,
        usedIndices: usedMerchantIndices,
        imgWidth: imgWidth,
        allAmounts: amounts,
      );

      String? merchantText;
      BoundingBox? merchantBbox;
      double merchantBottomY = amtTok.bbox.maxY;

      if (merchantIndices.isNotEmpty) {
        final merchTokens = merchantIndices.map((idx) => merchants[idx]).toList();
        final textParts = merchTokens.map((t) {
          final tText = t.textNormalized.isNotEmpty ? t.textNormalized : t.text;
          return _cleanMerchantPrefix(tText.trim());
        }).where((t) => t.isNotEmpty).toList();

        merchantText = textParts.join(' ');

        double minX = merchTokens.first.bbox.minX;
        double minY = merchTokens.first.bbox.minY;
        double maxX = merchTokens.first.bbox.maxX;
        double maxY = merchTokens.first.bbox.maxY;
        for (final mt in merchTokens) {
          if (mt.bbox.minX < minX) minX = mt.bbox.minX;
          if (mt.bbox.minY < minY) minY = mt.bbox.minY;
          if (mt.bbox.maxX > maxX) maxX = mt.bbox.maxX;
          if (mt.bbox.maxY > maxY) maxY = mt.bbox.maxY;
        }
        merchantBbox = BoundingBox.fromRect(minX, minY, maxX, maxY);
        merchantBottomY = maxY;
        usedMerchantIndices.addAll(merchantIndices);
      }

      // 2. Find nearest date below merchant or near amount
      final dateMatchIdx = _findDateForRow(
        dateTokens: dates,
        refBottomY: merchantBottomY,
        refCy: amtCy,
        rowH: rowH,
        usedIndices: usedDateIndices,
        allAmounts: amounts,
      );

      ClassifiedToken? dateMatch;
      if (dateMatchIdx != null) {
        dateMatch = dates[dateMatchIdx];
        usedDateIndices.add(dateMatchIdx);
      }

      final amtCls = amtTok.amountClassification ?? {};
      final num? parsedVal = amtCls['parsed_value'] as num?;
      final int? minorUnits = amtCls['parsed_minor_units'] as int? ??
          (parsedVal != null ? (parsedVal * 100).round() : null);

      // 3. Direction / Transaction Type detection
      final txType = _detectTransactionType(
        amountRaw: amtTok.text,
        amountNorm: amtTok.textNormalized,
        merchantText: merchantText,
      );

      final warnings = <String>[];
      if (merchantText == null || merchantText.isEmpty) {
        warnings.add('Merchant name not detected');
      }
      if (dateMatch == null) {
        warnings.add('Date not detected');
      }
      if (parsedVal == null || parsedVal <= 0) {
        warnings.add('Amount not detected');
      }

      candidates.add(ExtractedTransaction(
        amountTextRaw: amtTok.text,
        amountTextNormalized: amtTok.textNormalized,
        amountValue: parsedVal,
        amountMinorUnits: minorUnits,
        amountConfidence: amtTok.compositeScore > 0 ? amtTok.compositeScore : amtTok.confidence,
        amountBbox: amtTok.bbox,
        merchantText: merchantText,
        merchantBbox: merchantBbox,
        dateText: dateMatch?.textNormalized.isNotEmpty == true
            ? dateMatch!.textNormalized
            : dateMatch?.text,
        dateBbox: dateMatch?.bbox,
        transactionType: txType,
        warnings: warnings,
        groupingConfidence: _candidateConfidence(
          hasMerchant: merchantText != null && merchantText.length >= 2,
          hasDate: dateMatch != null,
          amountConf: amtTok.compositeScore > 0 ? amtTok.compositeScore : amtTok.confidence,
        ),
      ));
    }

    final noise = classified.where((t) => t.tokenType == 'noise').toList();

    return GrouperResult(
      tokenClassifications: classified,
      transactionCandidates: candidates,
      noiseTokens: noise,
    );
  }


  static double _estimateRowHeight(List<Map<String, dynamic>> detections) {
    final heights = detections
        .map((d) {
          final bbox = d['bbox'] is BoundingBox
              ? d['bbox'] as BoundingBox
              : BoundingBox.fromJson(d['bbox'] as List<dynamic>);
          return bbox.height;
        })
        .where((h) => h > 0)
        .toList();

    if (heights.isEmpty) return 20.0;
    heights.sort();
    return heights[heights.length ~/ 2];
  }

  static List<ClassifiedToken> _classifyTokens(
    List<Map<String, dynamic>> detections,
    int imgWidth,
    int imgHeight,
  ) {
    final List<ClassifiedToken> classified = [];

    for (final det in detections) {
      final rawText = det['text'] as String? ?? '';
      final normText = det['text_normalized'] as String? ?? rawText;
      final conf = (det['confidence'] as num?)?.toDouble() ?? 0.0;
      final compScore = (det['composite_score'] as num?)?.toDouble() ?? conf;
      final bbox = det['bbox'] is BoundingBox
          ? det['bbox'] as BoundingBox
          : BoundingBox.fromJson(det['bbox'] as List<dynamic>);

      final cx = bbox.center.x;
      final cy = bbox.center.y;
      final cleanLower = normText.toLowerCase().replaceAll(RegExp(r'\s+'), '');

      // ── Noise: UI status bar (top 8% of screen) ───────
      if (imgHeight > 0 && cy < imgHeight * 0.08) {
        classified.add(ClassifiedToken(
          text: rawText,
          textNormalized: normText,
          confidence: conf,
          compositeScore: compScore,
          bbox: bbox,
          tokenType: 'noise',
        ));
        continue;
      }

      // ── Noise: avatar zone (leftmost 12% with <= 2 chars) ──
      if (imgWidth > 0 && (cx / imgWidth) < avatarRightThreshold && normText.trim().length <= 2) {
        classified.add(ClassifiedToken(
          text: rawText,
          textNormalized: normText,
          confidence: conf,
          compositeScore: compScore,
          bbox: bbox,
          tokenType: 'noise',
        ));
        continue;
      }

      // ── Date: matches date label pattern (e.g. "3 August", "1August", "Today", "Yesterday") ──
      if (_reDateLabel.hasMatch(normText) || _reDateLabel.hasMatch(rawText)) {
        classified.add(ClassifiedToken(
          text: rawText,
          textNormalized: normText,
          confidence: conf,
          compositeScore: compScore,
          bbox: bbox,
          tokenType: 'date',
          amountClassification: {'is_amount': false, 'parsed_value': null},
        ));
        continue;
      }

      // ── Noise: known UI labels ──
      if (_uiNoise.contains(cleanLower)) {
        classified.add(ClassifiedToken(
          text: rawText,
          textNormalized: normText,
          confidence: conf,
          compositeScore: compScore,
          bbox: bbox,
          tokenType: 'noise',
        ));
        continue;
      }

      // ── Amount: run AmountClassifier ──
      var amtCls = AmountClassifier.classify(
        normText.isNotEmpty ? normText : rawText,
        bbox: bbox,
        imgWidth: imgWidth,
        imgHeight: imgHeight,
      );
      if (!amtCls.isAmount) {
        amtCls = AmountClassifier.classify(rawText, bbox: bbox, imgWidth: imgWidth, imgHeight: imgHeight);
      }

      if (amtCls.isAmount) {
        classified.add(ClassifiedToken(
          text: rawText,
          textNormalized: normText,
          confidence: conf,
          compositeScore: compScore,
          bbox: bbox,
          tokenType: 'amount',
          amountClassification: amtCls.toJson(),
        ));
        continue;
      }

      // ── Merchant: left-side non-amount text ──
      if (imgWidth <= 0 || (cx / imgWidth) <= merchantRightThreshold) {
        classified.add(ClassifiedToken(
          text: rawText,
          textNormalized: normText,
          confidence: conf,
          compositeScore: compScore,
          bbox: bbox,
          tokenType: 'merchant',
          amountClassification: amtCls.toJson(),
        ));
        continue;
      }

      // ── Unknown ──
      classified.add(ClassifiedToken(
        text: rawText,
        textNormalized: normText,
        confidence: conf,
        compositeScore: compScore,
        bbox: bbox,
        tokenType: 'unknown',
        amountClassification: amtCls.toJson(),
      ));
    }

    return classified;
  }

  static double _candidateConfidence({
    required bool hasMerchant,
    required bool hasDate,
    required double amountConf,
  }) {
    var base = amountConf * 0.50;
    if (hasMerchant) base += 0.35;
    if (hasDate) base += 0.15;
    return double.parse(min(base, 1.0).toStringAsFixed(4));
  }

  static List<int> _findMerchantsInRow({
    required List<ClassifiedToken> merchants,
    required double amtCy,
    required BoundingBox amtBbox,
    required double rowH,
    required Set<int> usedIndices,
    required int imgWidth,
    required List<ClassifiedToken> allAmounts,
  }) {
    final List<int> matched = [];
    final double maxBandAbove = rowH * 1.0;
    final double maxBandBelow = rowH * 2.2;

    for (int i = 0; i < merchants.length; i++) {
      if (usedIndices.contains(i)) continue;
      final m = merchants[i];
      final mCy = m.bbox.center.y;

      // Must be horizontally to the left of amount
      final isLeft = (m.bbox.maxX <= amtBbox.minX + 30) ||
          (imgWidth > 0 && (m.bbox.center.x / imgWidth) <= merchantRightThreshold);
      if (!isLeft) continue;

      // Must be within vertical window around amount
      final diff = mCy - amtCy;
      if (diff < -maxBandAbove || diff > maxBandBelow) continue;

      // Must be closer to THIS amount than to any other amount
      bool closerToThis = true;
      final distToThis = (mCy - amtCy).abs();
      for (final otherAmt in allAmounts) {
        final otherCy = otherAmt.bbox.center.y;
        if ((otherCy - amtCy).abs() < 1.0) continue; // Same amount
        if ((mCy - otherCy).abs() < distToThis) {
          closerToThis = false;
          break;
        }
      }
      if (!closerToThis) continue;

      matched.add(i);
    }

    // Sort matching merchant lines top-to-bottom
    matched.sort((a, b) => merchants[a].bbox.center.y.compareTo(merchants[b].bbox.center.y));
    return matched;
  }

  static int? _findDateForRow({
    required List<ClassifiedToken> dateTokens,
    required double refBottomY,
    required double refCy,
    required double rowH,
    required Set<int> usedIndices,
    required List<ClassifiedToken> allAmounts,
  }) {
    int? bestIdx;
    double bestDist = double.infinity;

    for (int i = 0; i < dateTokens.length; i++) {
      if (usedIndices.contains(i)) continue;
      final d = dateTokens[i];
      final dCy = d.bbox.center.y;
      final dTop = d.bbox.minY;

      // Date should generally be below the merchant or near the amount
      final diffFromRef = dCy - refCy;
      if (diffFromRef < -rowH * 0.8 || diffFromRef > rowH * 3.8) continue;

      // Distance from bottom of merchant or center of amount
      final dist = (dTop >= refBottomY) ? (dTop - refBottomY) : (dCy - refCy).abs();

      // Check if closer to this amount than other amounts
      bool closerToThis = true;
      final distToThisAmt = (dCy - refCy).abs();
      for (final otherAmt in allAmounts) {
        final otherCy = otherAmt.bbox.center.y;
        if ((otherCy - refCy).abs() < 1.0) continue;
        if ((dCy - otherCy).abs() < distToThisAmt - 5.0) {
          closerToThis = false;
          break;
        }
      }
      if (!closerToThis) continue;

      if (dist < bestDist) {
        bestDist = dist;
        bestIdx = i;
      }
    }

    return bestIdx;
  }

  static String _detectTransactionType({
    required String amountRaw,
    required String amountNorm,
    required String? merchantText,
  }) {
    final amtCombined = '$amountRaw $amountNorm';
    if (amtCombined.contains('+')) {
      return 'income';
    }

    final merchLower = (merchantText ?? '').toLowerCase();
    final incomeKeywords = [
      'received from',
      'received',
      'credited',
      'money received',
      'refund',
      'cashback',
    ];
    for (final kw in incomeKeywords) {
      if (merchLower.contains(kw)) return 'income';
    }

    final expenseKeywords = [
      'paid to',
      'payment to',
      'paid',
      'debited',
      'sent',
      'you paid',
      'money sent',
    ];
    for (final kw in expenseKeywords) {
      if (merchLower.contains(kw)) return 'expense';
    }

    return 'expense';
  }

  static String _cleanMerchantPrefix(String text) {
    var s = text.trim();
    s = s.replaceAll(RegExp(r'^(?:Paid to|Payment to|Received from|Sent to)\s+', caseSensitive: false), '');
    return s;
  }
}

