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
    'today',
    'yesterday',
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

    // ── Step 2: For each amount, find matching merchant + date ────────
    final List<ExtractedTransaction> candidates = [];
    final Set<int> usedMerchantIndices = {};
    final Set<int> usedDateIndices = {};

    // Sort amounts top-to-bottom
    amounts.sort((a, b) => a.bbox.center.y.compareTo(b.bbox.center.y));

    for (final amtTok in amounts) {
      final amtCy = amtTok.bbox.center.y;

      // Find nearest merchant within vertical band
      final merchantMatchIdx = _findNearestInYBand(
        candidates: merchants,
        refCy: amtCy,
        bandHalf: rowH * merchantYBand,
        usedIndices: usedMerchantIndices,
        imgWidth: imgWidth,
      );

      ClassifiedToken? merchantMatch;
      if (merchantMatchIdx != null) {
        merchantMatch = merchants[merchantMatchIdx];
        usedMerchantIndices.add(merchantMatchIdx);
      }

      // Find nearest date
      int? dateMatchIdx;
      if (merchantMatch != null) {
        final merchCy = merchantMatch.bbox.center.y;
        dateMatchIdx = _findDateBelowMerchant(
          dateTokens: dates,
          merchantCy: merchCy,
          rowH: rowH,
          bandBelow: rowH * dateYBandBelow,
          usedIndices: usedDateIndices,
        );
      } else {
        // Fallback: search date near amount row directly
        dateMatchIdx = _findNearestInYBand(
          candidates: dates,
          refCy: amtCy,
          bandHalf: rowH * 1.5,
          usedIndices: usedDateIndices,
          imgWidth: imgWidth,
        );
      }

      ClassifiedToken? dateMatch;
      if (dateMatchIdx != null) {
        dateMatch = dates[dateMatchIdx];
        usedDateIndices.add(dateMatchIdx);
      }

      final amtCls = amtTok.amountClassification ?? {};
      final num? parsedVal = amtCls['parsed_value'] as num?;

      candidates.add(ExtractedTransaction(
        amountTextRaw: amtTok.text,
        amountTextNormalized: amtTok.textNormalized,
        amountValue: parsedVal,
        amountConfidence: amtTok.compositeScore > 0 ? amtTok.compositeScore : amtTok.confidence,
        amountBbox: amtTok.bbox,
        merchantText: merchantMatch?.textNormalized.isNotEmpty == true
            ? merchantMatch!.textNormalized
            : merchantMatch?.text,
        merchantBbox: merchantMatch?.bbox,
        dateText: dateMatch?.textNormalized.isNotEmpty == true
            ? dateMatch!.textNormalized
            : dateMatch?.text,
        dateBbox: dateMatch?.bbox,
        groupingConfidence: _candidateConfidence(
          hasMerchant: merchantMatch != null,
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

      // ── Date: matches date label pattern ──
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

  static int? _findNearestInYBand({
    required List<ClassifiedToken> candidates,
    required double refCy,
    required double bandHalf,
    required Set<int> usedIndices,
    required int imgWidth,
  }) {
    final List<int> inBandIndices = [];
    for (int i = 0; i < candidates.length; i++) {
      if ((candidates[i].bbox.center.y - refCy).abs() <= bandHalf) {
        inBandIndices.add(i);
      }
    }

    if (inBandIndices.isEmpty) return null;

    final unused = inBandIndices.where((idx) => !usedIndices.contains(idx)).toList();
    final pool = unused.isNotEmpty ? unused : inBandIndices;

    pool.sort((a, b) =>
        (candidates[a].bbox.center.y - refCy).abs().compareTo((candidates[b].bbox.center.y - refCy).abs()));

    return pool.first;
  }

  static int? _findDateBelowMerchant({
    required List<ClassifiedToken> dateTokens,
    required double merchantCy,
    required double rowH,
    required double bandBelow,
    required Set<int> usedIndices,
  }) {
    final List<int> belowIndices = [];
    for (int i = 0; i < dateTokens.length; i++) {
      final diff = dateTokens[i].bbox.center.y - merchantCy;
      if (diff >= 0 && diff <= bandBelow) {
        belowIndices.add(i);
      }
    }

    if (belowIndices.isEmpty) return null;

    final unused = belowIndices.where((idx) => !usedIndices.contains(idx)).toList();
    final pool = unused.isNotEmpty ? unused : belowIndices;

    pool.sort((a, b) =>
        (dateTokens[a].bbox.center.y - merchantCy).compareTo(dateTokens[b].bbox.center.y - merchantCy));

    return pool.first;
  }

  static double _candidateConfidence({
    required bool hasMerchant,
    required bool hasDate,
    required double amountConf,
  }) {
    var base = amountConf;
    if (hasMerchant) base += 0.30;
    if (hasDate) base += 0.15;
    return double.parse(min(base, 1.0).toStringAsFixed(4));
  }
}
