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
    r'(?:paid\s+on|debited\s+on|credited\s+on)?\s*'
    r'\d{1,2}\s*(?:jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)[a-z]*(?:\s*,?\s*\d{2,4})?(?:\s*(?:at|,)?\s*\d{1,2}:\d{2}(?:\s*[ap]m)?)?'
    r'|'
    r'\d{1,2}:\d{2}(?:\s*[ap]m)?\s+on\s+\d{1,2}\s*(?:jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)[a-z]*(?:\s*,?\s*\d{2,4})?'
    r'|'
    r'(?:january|february|march|april|may|june|july|august|september|october|november|december)\s+\d{4}'
    r'|'
    r'\d+\s+(?:hour|hours|hr|hrs|day|days|min|mins|minute|minutes)\s+ago'
    r'|'
    r'(?:yesterday|today)(?:\s*,?\s*\d{1,2}:\d{2}(?:\s*[ap]m)?)?'
    r')\s*$',
    caseSensitive: false,
  );

  static const Set<String> _uiNoise = {
    'searchtransactions',
    'status',
    'paymentmethod',
    'date',
    'amount',
    'amo',
    'search',
    'filter',
    'all',
    'transactionsuccessful',
    'paymentsuccessful',
    'paidsuccessfully',
    'paymentdetails',
    'transactiondetails',
    'transferdetails',
    'viewdetails',
    'completed',
    'successful',
    'history',
    'help',
    'home',
    'alerts',
    'rewards',
    'offers',
    'coinsredeemed',
    'viewhistory',
    'payagain',
    'sharereceipt',
    'debitedfrom',
    'checkbalance',
    'paymentlocation',
    'openmaps',
    'upitransactionid',
    'transactionid',
    'notesupiintent',
    'upiintent',
    'youvewon',
    'checknow',
    'investment',
    'explore',
    'insurance',
    'viaupi',
    'receivedin',
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

    final splitDetections = _splitCombinedDetections(detections, imgWidth);
    final rowH = _estimateRowHeight(splitDetections);
    final isSingleReceipt = _isSingleReceiptLayout(splitDetections, const []);

    // ── Step 1: Classify each detection ──────────────────────────────
    final classified = _classifyTokens(
      splitDetections,
      imgWidth,
      imgHeight,
      isSingleReceipt: isSingleReceipt,
    );

    final amounts = classified.where((t) => t.tokenType == 'amount').toList();
    final dates = classified.where((t) => t.tokenType == 'date').toList();
    final merchants = classified.where((t) => t.tokenType == 'merchant').toList();
    final noise = classified.where((t) => t.tokenType == 'noise').toList();

    // ── Step 2: Check for Single Receipt / Detail View Layout ─────────
    if (isSingleReceipt || _isSingleReceiptLayout(splitDetections, amounts)) {
      final singleCandidate = _groupSingleReceipt(
        classified: classified,
        amounts: amounts,
        dates: dates,
        merchants: merchants,
        imgWidth: imgWidth,
        imgHeight: imgHeight,
      );
      if (singleCandidate.isNotEmpty) {
        return GrouperResult(
          tokenClassifications: classified,
          transactionCandidates: singleCandidate,
          noiseTokens: noise,
        );
      }
    }

    // ── Step 3: Multi-Transaction History List (Voronoi Boundary Grouping) ──
    final List<ExtractedTransaction> candidates = [];
    final Set<int> usedMerchantIndices = {};
    final Set<int> usedDateIndices = {};

    // Sort amounts top-to-bottom
    amounts.sort((a, b) => a.bbox.center.y.compareTo(b.bbox.center.y));

    for (int aIdx = 0; aIdx < amounts.length; aIdx++) {
      final amtTok = amounts[aIdx];
      final amtCy = amtTok.bbox.center.y;

      // Skip cut-off amounts that overlap the bottom navigation bar
      final overlapsNav = imgHeight > 0 && amtCy > imgHeight * 0.88 && detections.any((d) {
        final b = d['bbox'] is BoundingBox ? d['bbox'] as BoundingBox : BoundingBox.fromJson(d['bbox'] as List<dynamic>);
        final t = (d['text_normalized'] ?? d['text'] ?? '').toString().toLowerCase().replaceAll(RegExp(r'\s+'), '');
        final isNearSameY = (b.center.y - amtCy).abs() <= 45;
        return isNearSameY && ('history' == t || 'home' == t || 'investment' == t || 'explore' == t || 'insurance' == t);
      });
      if (overlapsNav) continue;

      // Calculate dynamic Voronoi vertical boundaries:
      // Halfway to previous amount above, halfway to next amount below.
      final double topBoundary = aIdx > 0
          ? (amounts[aIdx - 1].bbox.center.y + amtCy) / 2.0
          : amtCy - max(rowH * 8.0, 300.0);
      final double bottomBoundary = aIdx < amounts.length - 1
          ? (amtCy + amounts[aIdx + 1].bbox.center.y) / 2.0
          : amtCy + max(rowH * 8.0, 300.0);

      // 1. Multi-line merchant grouping in this vertical boundary
      final merchantIndices = _findMerchantsInRow(
        merchants: merchants,
        amtCy: amtCy,
        amtBbox: amtTok.bbox,
        rowH: rowH,
        usedIndices: usedMerchantIndices,
        imgWidth: imgWidth,
        allAmounts: amounts,
        topBoundary: topBoundary,
        bottomBoundary: bottomBoundary,
      );

      String? merchantText;
      BoundingBox? merchantBbox;

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
        usedMerchantIndices.addAll(merchantIndices);
      }

      // 2. Find date for this row within boundary
      final dateMatchIdx = _findDateForRow(
        dateTokens: dates,
        amtCy: amtCy,
        usedIndices: usedDateIndices,
        allAmounts: amounts,
        topBoundary: topBoundary,
        bottomBoundary: bottomBoundary,
        rowH: rowH,
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

    return GrouperResult(
      tokenClassifications: classified,
      transactionCandidates: candidates,
      noiseTokens: noise,
    );
  }

  static bool _isSingleReceiptLayout(
    List<Map<String, dynamic>> detections, [
    List<ClassifiedToken> amounts = const [],
  ]) {
    int receiptSignals = 0;
    bool hasStrongReceiptMarker = false;

    for (final det in detections) {
      final t = ((det['text_normalized'] as String?) ?? (det['text'] as String? ?? '')).toLowerCase();
      final clean = t.replaceAll(RegExp(r'\s+'), '');
      if (clean.contains('transactionsuccessful') ||
          clean.contains('paymentsuccessful') ||
          clean.contains('paidsuccessfully') ||
          clean.contains('transferdetails') ||
          clean.contains('upitransactionid') ||
          clean.contains('transactionid') ||
          clean.contains('paymentid') ||
          clean.contains('orderid') ||
          clean.contains('referencenumber') ||
          clean.contains('paidvia') ||
          clean.contains('notes:paidvia') ||
          clean.contains('notes:upiintent') ||
          clean.contains('upiintent')) {
        receiptSignals++;
        hasStrongReceiptMarker = true;
      } else if (clean.contains('payagain') ||
          clean.contains('splitexpense') ||
          clean.contains('sharereceipt') ||
          clean.contains('sendagain') ||
          clean.contains('bankingname') ||
          clean.contains('support') ||
          clean.contains('checkbalance') ||
          clean.contains('paymentlocation') ||
          clean == 'viewhistory') {
        receiptSignals++;
      }
    }

    if (hasStrongReceiptMarker || receiptSignals >= 2) return true;

    if (receiptSignals >= 1) {
      if (amounts.isNotEmpty && amounts.length <= 2) return true;
      if (amounts.isNotEmpty) {
        final uniqueVals = amounts.map((a) => a.amountClassification?['parsed_value']).toSet();
        if (uniqueVals.length <= 1) return true;
      }
    }

    return false;
  }

  static List<ExtractedTransaction> _groupSingleReceipt({
    required List<ClassifiedToken> classified,
    required List<ClassifiedToken> amounts,
    required List<ClassifiedToken> dates,
    required List<ClassifiedToken> merchants,
    required int imgWidth,
    required int imgHeight,
  }) {
    // 1. Filter out bank account breakdown debit amounts and bottom reward banners
    final validAmounts = amounts.where((a) {
      final isDebitFooter = classified.any((tok) {
        final t = tok.textNormalized.toLowerCase();
        return (t.startsWith('debited from') || t.startsWith('credited to')) &&
            (a.bbox.center.y - tok.bbox.center.y).abs() < 60;
      });
      if (isDebitFooter) return false;

      // Filter out bottom reward banner numbers (e.g. "You've won 50, Check now" at y > 75% height)
      if (imgHeight > 0 && a.bbox.center.y > imgHeight * 0.75) {
        final hasUpperAmount = amounts.any((other) => other.bbox.center.y <= imgHeight * 0.50);
        if (hasUpperAmount) return false;
      }
      return true;
    }).toList();

    // 2. Emergency hero amount recovery fallback if validAmounts is empty
    if (validAmounts.isEmpty) {
      final heroCandidates = classified.where((t) {
        if (t.tokenType == 'noise' || t.tokenType == 'date') return false;
        final raw = t.text.trim();
        final noCurr = raw.replaceAll(RegExp(r'^[₹#＃\+\-\s]+'), '').trim();
        if (RegExp(r'^\d{1,6}(?:\.\d{1,2})?$').hasMatch(noCurr)) {
          final val = double.tryParse(noCurr);
          if (val != null && val > 0 && val < 10000000 && !raw.startsWith('0')) {
            return imgHeight <= 0 || t.bbox.center.y <= imgHeight * 0.50;
          }
        }
        return false;
      }).toList();

      if (heroCandidates.isNotEmpty) {
        heroCandidates.sort((a, b) => a.bbox.center.y.compareTo(b.bbox.center.y));
        final fallbackHero = heroCandidates.first;
        final rawNoCurr = fallbackHero.text.replaceAll(RegExp(r'^[₹#＃\+\-\s]+'), '').trim();
        final val = double.parse(rawNoCurr);
        validAmounts.add(ClassifiedToken(
          text: fallbackHero.text,
          textNormalized: fallbackHero.textNormalized,
          confidence: fallbackHero.confidence,
          compositeScore: fallbackHero.compositeScore,
          bbox: fallbackHero.bbox,
          tokenType: 'amount',
          amountClassification: {
            'is_amount': true,
            'parsed_value': val,
            'parsed_minor_units': (val * 100).round(),
            'normalized_text': '₹$val',
          },
        ));
      }
    }

    if (validAmounts.isEmpty) return const [];

    // Keep the hero amount: prefer explicit currency symbol ('₹') and top-level position
    ClassifiedToken heroAmt = validAmounts.first;
    for (final a in validAmounts) {
      final aHasCurr = a.textNormalized.contains('₹') || a.text.contains('₹');
      final heroHasCurr = heroAmt.textNormalized.contains('₹') || heroAmt.text.contains('₹');
      if (aHasCurr && !heroHasCurr) {
        heroAmt = a;
        break;
      }
    }

    final amtCy = heroAmt.bbox.center.y;

    // Find merchant in Single Receipt:
    String? merchantText;
    BoundingBox? merchantBbox;

    // Strategy 1: Look for "Paid to" or "To" anchor token, then take the line directly below it
    ClassifiedToken? anchorTok;
    for (final tok in classified) {
      final clean = tok.textNormalized.toLowerCase().replaceAll(RegExp(r'\s+'), '');
      if (clean == 'paidto' || clean == 'paymentto' || clean == 'to' || clean == 'receivedfrom') {
        anchorTok = tok;
        break;
      }
    }

    if (anchorTok != null) {
      // Find candidate tokens directly below anchor (within 10-130px below anchor)
      final belowAnchor = classified.where((tok) {
        final isBelow = tok.bbox.minY >= anchorTok!.bbox.minY - 5 &&
            tok.bbox.center.y > anchorTok.bbox.center.y &&
            tok.bbox.center.y <= anchorTok.bbox.center.y + 130;
        final clean = tok.textNormalized.toLowerCase().replaceAll(RegExp(r'\s+'), '');
        final isNoise = _uiNoise.contains(clean) ||
            clean == 'viewhistory' ||
            clean.contains('@') ||
            clean.contains('debitedfrom');
        return isBelow && !isNoise && tok.tokenType != 'amount' && tok.textNormalized.trim().isNotEmpty;
      }).toList();

      if (belowAnchor.isNotEmpty) {
        belowAnchor.sort((a, b) => a.bbox.center.y.compareTo(b.bbox.center.y));
        final mTok = belowAnchor.first;
        // Also group any tokens on the same horizontal line (within 25px vertically of mTok)
        final sameLineTokens = belowAnchor.where((tok) =>
          tok.tokenType != 'amount' &&
          (tok.bbox.center.y - mTok.bbox.center.y).abs() <= 25
        ).toList();
        sameLineTokens.sort((a, b) => a.bbox.minX.compareTo(b.bbox.minX));

        // Deduplicate words if logo + text detected (e.g. "blinkit" icon and "BLinkit" title)
        final Map<String, String> wordMap = {};
        for (final tok in sameLineTokens) {
          final t = _cleanMerchantPrefix(tok.textNormalized.isNotEmpty ? tok.textNormalized : tok.text);
          final lower = t.toLowerCase();
          if (t.isNotEmpty) {
            // Prefer title/capitalized token over lowercase logo
            if (!wordMap.containsKey(lower) || (t[0] == t[0].toUpperCase() && wordMap[lower]![0] != wordMap[lower]![0].toUpperCase())) {
              wordMap[lower] = t;
            }
          }
        }
        final parts = wordMap.values.toList();

        final combined = parts.join(' ').trim();
        if (combined.isNotEmpty && combined.length >= 2) {
          merchantText = combined;
          merchantBbox = mTok.bbox;
        }
      }
    }

    // Strategy 2: Look for token to the left of "View history"
    if (merchantText == null) {
      ClassifiedToken? viewHistTok;
      for (final tok in classified) {
        if (tok.textNormalized.toLowerCase().replaceAll(RegExp(r'\s+'), '').contains('viewhistory')) {
          viewHistTok = tok;
          break;
        }
      }
      if (viewHistTok != null) {
        final leftOfHist = classified.where((tok) {
          final isSameLine = (tok.bbox.center.y - viewHistTok!.bbox.center.y).abs() <= 50;
          final isLeft = tok.bbox.maxX <= viewHistTok.bbox.minX + 20;
          final clean = tok.textNormalized.toLowerCase().replaceAll(RegExp(r'\s+'), '');
          return isSameLine && isLeft && !_uiNoise.contains(clean) && !clean.contains('@') && clean.length >= 2;
        }).toList();

        if (leftOfHist.isNotEmpty) {
          final mTok = leftOfHist.first;
          final clean = _cleanMerchantPrefix(mTok.textNormalized.isNotEmpty ? mTok.textNormalized : mTok.text);
          if (clean.isNotEmpty && clean.length >= 2) {
            merchantText = clean;
            merchantBbox = mTok.bbox;
          }
        }
      }
    }

    // Strategy 3: Look for explicit "To ...", "Paid to ...", "Payment to ...", "Received from ..." tokens
    if (merchantText == null) {
      for (final m in merchants) {
        final t = m.textNormalized.isNotEmpty ? m.textNormalized : m.text;
        final lower = t.toLowerCase().trim();
        if (lower.startsWith('to ') || lower.startsWith('paid to') || lower.startsWith('payment to') || lower.startsWith('received from')) {
          final clean = _cleanMerchantPrefix(t);
          if (clean.isNotEmpty && clean.length >= 2 && !_uiNoise.contains(clean.toLowerCase().replaceAll(RegExp(r'\s+'), ''))) {
            merchantText = clean;
            merchantBbox = m.bbox;
            break;
          }
        }
      }
    }

    // Strategy 4: If not found, look for tokens adjacent to hero amount (above, same-line, or below within 250px)
    if (merchantText == null) {
      final candidateMerchants = merchants.where((m) {
        final isNear = (amtCy - m.bbox.center.y).abs() <= 250;
        final clean = m.textNormalized.toLowerCase().replaceAll(RegExp(r'\s+'), '');
        return isNear &&
            !_uiNoise.contains(clean) &&
            !clean.contains('@') &&
            !clean.startsWith('+91') &&
            !clean.contains('••••');
      }).toList();

      candidateMerchants.sort((a, b) {
        final distA = (amtCy - a.bbox.center.y).abs();
        final distB = (amtCy - b.bbox.center.y).abs();
        return distA.compareTo(distB);
      });

      for (final t in candidateMerchants) {
        final clean = _cleanMerchantPrefix(t.textNormalized.isNotEmpty ? t.textNormalized : t.text);
        if (clean.isNotEmpty &&
            clean.length >= 2 &&
            !clean.startsWith('+91') &&
            !clean.contains('••••') &&
            !_uiNoise.contains(clean.toLowerCase().replaceAll(RegExp(r'\s+'), ''))) {
          merchantText = clean;
          merchantBbox = t.bbox;
          break;
        }
      }
    }

    // Find date: any date in dates
    final ClassifiedToken? dateMatch = dates.isNotEmpty ? dates.first : null;

    final amtCls = heroAmt.amountClassification ?? {};
    final num? parsedVal = amtCls['parsed_value'] as num?;
    final int? minorUnits = amtCls['parsed_minor_units'] as int? ??
        (parsedVal != null ? (parsedVal * 100).round() : null);

    final txType = _detectTransactionType(
      amountRaw: heroAmt.text,
      amountNorm: heroAmt.textNormalized,
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

    return [
      ExtractedTransaction(
        amountTextRaw: heroAmt.text,
        amountTextNormalized: heroAmt.textNormalized,
        amountValue: parsedVal,
        amountMinorUnits: minorUnits,
        amountConfidence: heroAmt.compositeScore > 0 ? heroAmt.compositeScore : heroAmt.confidence,
        amountBbox: heroAmt.bbox,
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
          amountConf: heroAmt.compositeScore > 0 ? heroAmt.compositeScore : heroAmt.confidence,
        ),
      ),
    ];
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
    int imgHeight, {
    bool isSingleReceipt = false,
  }) {
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

      // ── Noise: UI status bar (top 9% of screen) ───────
      // Protect date tokens (e.g. from single receipts or cropped headers)
      final isDate = _reDateLabel.hasMatch(normText) || _reDateLabel.hasMatch(rawText);
      if (imgHeight > 0 && cy < imgHeight * 0.09 && !isDate) {
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

      // ── Noise: bottom navigation bar (bottom 10% of screen) ──
      final isBottomNav = imgHeight > 0 && cy > imgHeight * 0.90;
      if (isBottomNav && (_uiNoise.contains(cleanLower) || detections.any((d) {
        final b = d['bbox'] is BoundingBox ? d['bbox'] as BoundingBox : BoundingBox.fromJson(d['bbox'] as List<dynamic>);
        if (b.center.y < imgHeight * 0.90) return false;
        final dt = ((d['text_normalized'] as String?) ?? (d['text'] as String? ?? '')).toLowerCase().replaceAll(RegExp(r'\s+'), '');
        return dt == 'history' || dt == 'home' || dt == 'investment' || dt == 'explore' || dt == 'rewards' || dt == 'settings';
      }))) {
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
      // In single receipts, don't reject short amounts in the hero area!
      if (!isSingleReceipt && imgWidth > 0 && (cx / imgWidth) < avatarRightThreshold && normText.trim().length <= 2) {
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

      // ── Noise: known UI labels, bank/tx footers, VPAs, reward points, and status ──
      final normLower = normText.toLowerCase().trim();
      final rawLower = rawText.toLowerCase().trim();
      if (_uiNoise.contains(cleanLower) ||
          rawText.contains('@') ||
          normText.contains('@') ||
          normLower.contains('.rzp') ||
          cleanLower.contains('rzp') ||
          normLower.startsWith('**') ||
          cleanLower.startsWith('**') ||
          normLower.contains('coins redeemed') ||
          rawLower.contains('coins redeemed') ||
          cleanLower == 'coinsredeemed' ||
          cleanLower.contains('youvewon') ||
          cleanLower.contains("you'vewon") ||
          cleanLower.contains('checknow') ||
          normLower.startsWith('notes:') ||
          rawLower.startsWith('notes:') ||
          cleanLower.startsWith('notes:') ||
          normLower.startsWith('debited from') ||
          normLower.startsWith('credited to') ||
          normLower.startsWith('upi ref') ||
          normLower.startsWith('txn id') ||
          normLower.startsWith('utr:') ||
          normLower.startsWith('via upi') ||
          normLower.startsWith('received in') ||
          normLower.startsWith('paid via') ||
          normLower == 'view history' ||
          normLower == 'pay again' ||
          normLower == 'share receipt' ||
          normLower == 'check balance' ||
          normLower == 'payment location' ||
          normLower == 'open maps') {
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
        isSingleReceipt: isSingleReceipt,
      );
      if (!amtCls.isAmount) {
        amtCls = AmountClassifier.classify(
          rawText,
          bbox: bbox,
          imgWidth: imgWidth,
          imgHeight: imgHeight,
          isSingleReceipt: isSingleReceipt,
        );
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
    required double topBoundary,
    required double bottomBoundary,
  }) {
    final List<int> matched = [];

    for (int i = 0; i < merchants.length; i++) {
      if (usedIndices.contains(i)) continue;
      final m = merchants[i];
      final mCy = m.bbox.center.y;

      // Must be horizontally to the left of amount or broadly aligned
      final isLeft = (m.bbox.maxX <= amtBbox.minX + 30) ||
          (imgWidth > 0 && (m.bbox.center.x / imgWidth) <= merchantRightThreshold);
      if (!isLeft) continue;

      // Must be within dynamic Voronoi vertical boundary between adjacent transactions
      if (mCy < topBoundary || mCy > bottomBoundary) continue;

      final distToThis = (mCy - amtCy).abs();
      // Guard against concatenating distant merchant rows when an intermediate amount was missed
      final maxVerticalDistance = max(85.0, rowH * 1.10);
      if (distToThis > maxVerticalDistance) continue;

      // Must be closer to THIS amount than to any other amount
      bool closerToThis = true;
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
    required double amtCy,
    required Set<int> usedIndices,
    required List<ClassifiedToken> allAmounts,
    required double topBoundary,
    required double bottomBoundary,
    double rowH = 65.0,
  }) {
    int? bestIdx;
    double bestDist = double.infinity;

    for (int i = 0; i < dateTokens.length; i++) {
      if (usedIndices.contains(i)) continue;
      final d = dateTokens[i];
      final dCy = d.bbox.center.y;

      // Must be within dynamic Voronoi vertical boundary
      if (dCy < topBoundary || dCy > bottomBoundary) continue;

      final distToThisAmt = (dCy - amtCy).abs();
      // Guard against binding to dates from different rows
      final maxDateVerticalDistance = max(95.0, rowH * 1.25);
      if (distToThisAmt > maxDateVerticalDistance) continue;

      // Check if closer to this amount than other amounts
      bool closerToThis = true;
      for (final otherAmt in allAmounts) {
        final otherCy = otherAmt.bbox.center.y;
        if ((otherCy - amtCy).abs() < 1.0) continue;
        if ((dCy - otherCy).abs() < distToThisAmt - 5.0) {
          closerToThis = false;
          break;
        }
      }
      if (!closerToThis) continue;

      final dist = (dCy - amtCy).abs();
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
    final lower = s.toLowerCase();
    if (lower == 'paid to' ||
        lower == 'payment to' ||
        lower == 'received from' ||
        lower == 'sent to' ||
        lower == 'transfer to' ||
        lower == 'paid' ||
        lower == 'to' ||
        lower == 'from') {
      return '';
    }

    s = s.replaceAll(
      RegExp(r'^(?:Paid to|Payment to|Received from|Sent to|Transfer to|Paid|To:?|From:?)\s+', caseSensitive: false),
      '',
    );
    final avatarMatch = RegExp(r'^([A-Za-z])\s+([A-Za-z])', caseSensitive: false).firstMatch(s);
    if (avatarMatch != null) {
      final initial = avatarMatch.group(1)!.toUpperCase();
      final nextInitial = avatarMatch.group(2)!.toUpperCase();
      if (initial == nextInitial) {
        s = s.replaceFirst(RegExp(r'^[A-Za-z]\s+'), '').trim();
      }
    }
    return s.trim();
  }

  static List<Map<String, dynamic>> _splitCombinedDetections(
    List<Map<String, dynamic>> detections,
    int imgWidth,
  ) {
    final List<Map<String, dynamic>> result = [];
    final combinedRegex = RegExp(
      r'^(.*?)\s+([+-]?\s*(?:[₹#＃Rr\u4e70\u5c10\uffe5\u00a5]|\bINR\b|\bRs\.?|\bRs\b)?\s*[\d,]+(?:\.\d{1,2})?)\s*$',
      caseSensitive: false,
    );

    for (final det in detections) {
      final rawText = (det['text'] as String? ?? '').trim();
      final normText = (det['text_normalized'] as String? ?? rawText).trim();

      // If line is already a pure amount, keep as-is
      final pureAmount = AmountClassifier.classify(normText, imgWidth: imgWidth);
      if (pureAmount.isAmount) {
        result.add(det);
        continue;
      }

      final textToTest = normText.isNotEmpty ? normText : rawText;
      final match = combinedRegex.firstMatch(textToTest);

      if (match != null) {
        final merchantPart = match.group(1)!.trim();
        final amountPart = match.group(2)!.trim();

        final cleanMerch = merchantPart.toLowerCase().replaceAll(RegExp(r'\s+'), '');
        final isDate = _reDateLabel.hasMatch(merchantPart);
        final isNoise = _uiNoise.contains(cleanMerch);
        final amtCls = AmountClassifier.classify(amountPart, imgWidth: imgWidth);

        if (merchantPart.length >= 2 && !isDate && !isNoise && amtCls.isAmount && (amtCls.parsedValue ?? 0) > 0) {
          final bbox = det['bbox'] is BoundingBox
              ? det['bbox'] as BoundingBox
              : BoundingBox.fromJson(det['bbox'] as List<dynamic>);

          final totalLen = textToTest.length;
          final ratio = (merchantPart.length / (totalLen > 0 ? totalLen : 1)).clamp(0.40, 0.85);
          final splitX = bbox.minX + bbox.width * ratio;

          final merchantBbox = BoundingBox.fromRect(
            bbox.minX,
            bbox.minY,
            splitX - 2.0,
            bbox.maxY,
          );
          final amountBbox = BoundingBox.fromRect(
            splitX + 2.0,
            bbox.minY,
            bbox.maxX,
            bbox.maxY,
          );

          final conf = (det['confidence'] as num?)?.toDouble() ?? 0.0;
          final score = (det['composite_score'] as num?)?.toDouble() ?? conf;

          result.add({
            'text': merchantPart,
            'text_normalized': merchantPart,
            'confidence': conf,
            'composite_score': score,
            'bbox': merchantBbox,
          });

          result.add({
            'text': amountPart,
            'text_normalized': amountPart,
            'confidence': conf,
            'composite_score': score,
            'bbox': amountBbox,
          });

          continue;
        }
      }

      result.add(det);
    }

    return result;
  }
}


