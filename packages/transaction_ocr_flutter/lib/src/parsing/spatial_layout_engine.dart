import '../core/models/bounding_box.dart';
import '../core/models/extracted_transaction.dart';
import '../core/models/ocr_item.dart';
import '../core/models/semantic_role.dart';
import 'amount_classifier.dart';
import 'generic_semantic_classifier.dart';
import 'merchant_entity_scorer.dart';
import 'universal_date_detector.dart';

/// Document layout structure type.
enum DocumentLayoutType {
  historyFeed,
  singleReceipt,
  table,
  unknown,
}

/// Result of 2D Spatial Layout analysis and transaction grouping.
class SpatialLayoutResult {
  final DocumentLayoutType layoutType;
  final List<ExtractedTransaction> transactions;
  final List<OcrItem> classifiedItems;
  final List<OcrItem> noiseItems;

  const SpatialLayoutResult({
    required this.layoutType,
    required this.transactions,
    required this.classifiedItems,
    required this.noiseItems,
  });
}

/// 2D Spatial Relationship and Universal Transaction Grouping Engine.
///
/// Operates without app-specific layout assumptions:
/// - Replaces fixed 1D heuristics with 2D geometric clustering and periodicity analysis.
/// - Supports arbitrary amount positioning: left, right, centered, inside cards, or table cells.
/// - Detects history feeds vs single receipts dynamically from layout structure.
/// - Extracts prefix-free merchant entities and robust dates.
class SpatialLayoutEngine {
  /// Analyzes OCR items and groups them into transactions.
  static SpatialLayoutResult process({
    required List<OcrItem> items,
    required int imgWidth,
    required int imgHeight,
  }) {
    if (items.isEmpty) {
      return const SpatialLayoutResult(
        layoutType: DocumentLayoutType.unknown,
        transactions: [],
        classifiedItems: [],
        noiseItems: [],
      );
    }

    // Step 1: Semantic Classification of all OCR items
    final classified = <OcrItem>[];
    for (final item in items) {
      final roleScores = GenericSemanticClassifier.classifyItem(
        item,
        imgWidth: imgWidth,
        imgHeight: imgHeight,
      );

      final amtCls = AmountClassifier.classify(
        item.textNormalized,
        bbox: item.bbox,
        imgWidth: imgWidth,
        imgHeight: imgHeight,
      );

      final isNumAmt = amtCls.isAmount && (amtCls.parsedMinorUnits ?? 0) > 0;
      final parsedInt = amtCls.parsedMinorUnits != null ? (amtCls.parsedMinorUnits! / 100.0).round() : null;

      String tokenType = 'unknown';
      final topRole = _topRole(roleScores);
      if (topRole == SemanticRole.amountPrimary || topRole == SemanticRole.amountSecondary) {
        tokenType = 'amount';
      } else if (topRole == SemanticRole.date || topRole == SemanticRole.time || topRole == SemanticRole.dateTime) {
        tokenType = 'date';
      } else if (topRole == SemanticRole.merchantCandidate || topRole == SemanticRole.personCandidate) {
        tokenType = 'merchant';
      } else if (topRole == SemanticRole.systemChrome || topRole == SemanticRole.navigation) {
        tokenType = 'noise';
      }

      classified.add(item.copyWith(
        tokenType: tokenType,
        amountClassification: amtCls,
        isNumericAmount: isNumAmt,
        parsedIntegerAmount: parsedInt,
        roleScores: roleScores,
      ));
    }

    // Step 2: Separate noise and identify amounts
    final noise = classified.where((it) {
      final r = it.primaryRole;
      return r == SemanticRole.systemChrome || r == SemanticRole.navigation;
    }).toList();

    final nonNoise = classified.where((it) {
      final r = it.primaryRole;
      return r != SemanticRole.systemChrome && r != SemanticRole.navigation;
    }).toList();

    // Find primary amount candidates
    final primaryAmounts = nonNoise.where((it) {
      final r = it.primaryRole;
      final isAmt = it.amountClassification?.isAmount == true;
      final isNotSecondary = r != SemanticRole.reward &&
          r != SemanticRole.promotion &&
          r != SemanticRole.balance &&
          r != SemanticRole.amountSecondary;
      return isAmt && isNotSecondary;
    }).toList();

    // Step 3: Determine Document Structure (History Feed vs Single Receipt)
    final layoutType = _determineLayoutType(
      items: nonNoise,
      amounts: primaryAmounts,
      imgWidth: imgWidth,
      imgHeight: imgHeight,
    );

    List<ExtractedTransaction> transactions;
    if (layoutType == DocumentLayoutType.singleReceipt) {
      transactions = _groupSingleReceipt(
        items: nonNoise,
        primaryAmounts: primaryAmounts,
        imgWidth: imgWidth,
        imgHeight: imgHeight,
      );
    } else {
      transactions = _groupHistoryFeed(
        items: nonNoise,
        primaryAmounts: primaryAmounts,
        imgWidth: imgWidth,
        imgHeight: imgHeight,
      );
    }

    return SpatialLayoutResult(
      layoutType: layoutType,
      transactions: transactions,
      classifiedItems: classified,
      noiseItems: noise,
    );
  }

  static SemanticRole _topRole(Map<SemanticRole, double> scores) {
    if (scores.isEmpty) return SemanticRole.unknown;
    var best = SemanticRole.unknown;
    var maxVal = -1.0;
    for (final e in scores.entries) {
      if (e.value > maxVal) {
        maxVal = e.value;
        best = e.key;
      }
    }
    return best;
  }

  /// Evaluates document structure dynamically without brand names.
  static DocumentLayoutType _determineLayoutType({
    required List<OcrItem> items,
    required List<OcrItem> amounts,
    required int imgWidth,
    required int imgHeight,
  }) {
    // Check for explicit single receipt signals (Status = Completed, UTR, Share Receipt)
    int receiptSignals = 0;
    bool hasStatus = false;
    for (final it in items) {
      final r = it.primaryRole;
      if (r == SemanticRole.status) {
        receiptSignals += 2;
        hasStatus = true;
      }
      if (r == SemanticRole.header || r == SemanticRole.transactionReference) {
        receiptSignals++;
      }
    }

    if (amounts.length <= 1) {
      return DocumentLayoutType.singleReceipt;
    }

    // Check if multiple amounts are actually duplicate reads of the same hero amount
    final uniqueValues = amounts
        .map((a) => a.amountClassification?.parsedMinorUnits)
        .where((v) => v != null)
        .toSet();

    if (uniqueValues.length == 1 && hasStatus) {
      return DocumentLayoutType.singleReceipt;
    }

    // Analyze vertical periodicity of amounts:
    amounts.sort((a, b) => a.centerY.compareTo(b.centerY));
    if (amounts.length >= 3) {
      return DocumentLayoutType.historyFeed;
    }

    if (amounts.length == 2 && receiptSignals >= 2) {
      // Often single receipts show: hero amount at top + debited from amount at bottom
      final topY = amounts[0].centerY;
      final bottomY = amounts[1].centerY;
      if ((bottomY - topY) > (imgHeight * 0.25)) {
        return DocumentLayoutType.singleReceipt;
      }
    }

    return amounts.length >= 2
        ? DocumentLayoutType.historyFeed
        : DocumentLayoutType.singleReceipt;
  }

  /// Groups transactions for a History Feed layout.
  static List<ExtractedTransaction> _groupHistoryFeed({
    required List<OcrItem> items,
    required List<OcrItem> primaryAmounts,
    required int imgWidth,
    required int imgHeight,
  }) {
    if (primaryAmounts.isEmpty) return const [];

    primaryAmounts.sort((a, b) => a.centerY.compareTo(b.centerY));

    final results = <ExtractedTransaction>[];
    final usedTokens = <OcrItem>{};

    for (int i = 0; i < primaryAmounts.length; i++) {
      final amtItem = primaryAmounts[i];
      final amtCy = amtItem.centerY;

      // 2D dynamic vertical boundary
      final double topBoundary = i > 0
          ? (primaryAmounts[i - 1].centerY + amtCy) / 2.0
          : amtCy - (imgHeight * 0.15);
      final double bottomBoundary = i < primaryAmounts.length - 1
          ? (amtCy + primaryAmounts[i + 1].centerY) / 2.0
          : amtCy + (imgHeight * 0.15);

      // Collect candidate items in this vertical boundary
      final rowItems = items.where((it) {
        if (it == amtItem || usedTokens.contains(it)) return false;
        return it.centerY >= topBoundary && it.centerY <= bottomBoundary;
      }).toList();

      // Extract Date
      OcrItem? dateItem;
      String? dateText;
      BoundingBox? dateBbox;
      double dateConf = 0.50;

      for (final it in rowItems) {
        final dRes = UniversalDateDetector.detect(it.textNormalized);
        if (dRes.isAny) {
          dateItem = it;
          dateText = it.textNormalized;
          dateBbox = it.bbox;
          dateConf = dRes.confidence;
          break;
        }
      }

      // Extract Direction
      var direction = 'expense';
      double dirConf = 0.85;
      final amtNorm = amtItem.textNormalized;
      if (amtNorm.startsWith('+')) {
        direction = 'income';
        dirConf = 0.95;
      } else if (amtNorm.startsWith('-')) {
        direction = 'expense';
        dirConf = 0.95;
      } else {
        for (final it in rowItems) {
          final clean = it.textNormalized.toLowerCase().replaceAll(RegExp(r'\s+'), '');
          if (clean.contains('received') || clean.contains('refund') || clean.contains('credited')) {
            direction = 'income';
            dirConf = 0.95;
            break;
          }
          if (clean.contains('paid') || clean.contains('spent') || clean.contains('debited')) {
            direction = 'expense';
            dirConf = 0.95;
            break;
          }
        }
      }

      // Extract Merchant / Entity
      final merchantResult = MerchantEntityScorer.scoreCandidate(
        candidateTokens: rowItems,
        amountBbox: amtItem.bbox,
        dateBbox: dateBbox,
        imgWidth: imgWidth,
        imgHeight: imgHeight,
      );

      final warnings = <String>[];
      if (merchantResult.name == null) {
        warnings.add('Merchant uncertain');
      }
      if (dateText == null) {
        warnings.add('Date not detected');
      }
      if (dirConf < 0.70) {
        warnings.add('Transaction type uncertain');
      }

      final amtCls = amtItem.amountClassification;
      final amtMinor = amtCls?.parsedMinorUnits ?? ((amtCls?.parsedValue ?? 0) * 100).round();
      final amtConfidence = amtItem.confidence;

      final double groupingConf = (amtConfidence * 0.4 +
              merchantResult.confidence * 0.35 +
              dateConf * 0.25)
          .clamp(0.1, 1.0);

      // OCR evidence dictionary
      final evidence = {
        'amount_token': amtItem.text,
        'amount_normalized': amtItem.textNormalized,
        'amount_bbox': amtItem.bbox.toJson(),
        'merchant_tokens': merchantResult.sourceTokens.map((t) => t.text).toList(),
        'date_token': dateText,
        'direction': direction,
      };

      results.add(ExtractedTransaction(
        amountTextRaw: amtItem.text,
        amountTextNormalized: amtItem.textNormalized,
        amountValue: amtCls?.parsedValue,
        amountMinorUnits: amtMinor,
        amountConfidence: amtConfidence,
        amountBbox: amtItem.bbox,
        merchantText: merchantResult.name,
        merchantBbox: merchantResult.bbox,
        merchantConfidence: merchantResult.confidence,
        dateText: dateText,
        dateBbox: dateBbox,
        dateConfidence: dateConf,
        groupingConfidence: groupingConf,
        transactionType: direction,
        typeConfidence: dirConf,
        warnings: warnings,
        ocrEvidence: evidence,
      ));

      usedTokens.add(amtItem);
      if (dateItem != null) usedTokens.add(dateItem);
      usedTokens.addAll(merchantResult.sourceTokens);
    }

    return results;
  }

  /// Groups transactions for a Single Receipt layout.
  static List<ExtractedTransaction> _groupSingleReceipt({
    required List<OcrItem> items,
    required List<OcrItem> primaryAmounts,
    required int imgWidth,
    required int imgHeight,
  }) {
    if (items.isEmpty) return const [];

    // Filter out bank account breakdown debit amounts and bottom reward banners
    final validAmounts = primaryAmounts.where((a) {
      // Reject if inside "Debited from" or "Credited to" line
      final isDebitFooter = items.any((tok) {
        final t = tok.textNormalized.toLowerCase();
        return (t.startsWith('debited from') || t.startsWith('credited to')) &&
            (a.centerY - tok.centerY).abs() < 60;
      });
      if (isDebitFooter) return false;

      // Filter out bottom reward banner numbers (e.g. "You've won 50" at y > 75% height)
      if (imgHeight > 0 && a.centerY > imgHeight * 0.75) {
        final hasUpper = primaryAmounts.any((other) => other.centerY <= imgHeight * 0.50);
        if (hasUpper) return false;
      }
      return true;
    }).toList();

    // Emergency hero amount recovery if validAmounts is empty
    if (validAmounts.isEmpty) {
      for (final it in items) {
        if (it.tokenType == 'noise' || it.tokenType == 'date') continue;
        final raw = it.text.trim();
        final noCurr = raw.replaceAll(RegExp(r'^[₹#＃\+\-\s]+'), '').trim();
        if (RegExp(r'^\d{1,6}(?:\.\d{1,2})?$').hasMatch(noCurr)) {
          final val = double.tryParse(noCurr);
          if (val != null && val > 0 && val < 10000000 && !raw.startsWith('0')) {
            if (imgHeight <= 0 || it.centerY <= imgHeight * 0.50) {
              validAmounts.add(it);
              break;
            }
          }
        }
      }
    }

    if (validAmounts.isEmpty) return const [];

    // Prefer amount with explicit currency symbol or highest on screen
    validAmounts.sort((a, b) {
      final aCurr = a.textNormalized.contains('₹') || a.text.contains('₹');
      final bCurr = b.textNormalized.contains('₹') || b.text.contains('₹');
      if (aCurr && !bCurr) return -1;
      if (!aCurr && bCurr) return 1;
      return a.centerY.compareTo(b.centerY);
    });

    final heroAmount = validAmounts.first;
    final amtCls = heroAmount.amountClassification;
    final amtMinor = amtCls?.parsedMinorUnits ??
        ((amtCls?.parsedValue ?? 0) * 100).round();

    // Direction Anchor ("Paid to", "Sent to", "Received from")
    OcrItem? anchorItem;
    for (final it in items) {
      final clean = it.textNormalized.toLowerCase().replaceAll(RegExp(r'\s+'), '');
      if (clean == 'paidto' || clean == 'paymentto' || clean == 'to' || clean == 'sentto' || clean == 'receivedfrom') {
        anchorItem = it;
        break;
      }
    }

    // Direction (expense vs income)
    var direction = 'expense';
    double dirConf = 0.90;
    final heroNorm = heroAmount.textNormalized;
    if (heroNorm.startsWith('+')) {
      direction = 'income';
      dirConf = 0.95;
    } else if (heroNorm.startsWith('-')) {
      direction = 'expense';
      dirConf = 0.95;
    } else {
      for (final it in items) {
        final clean = it.textNormalized.toLowerCase().replaceAll(RegExp(r'\s+'), '');
        if (clean.contains('received') || clean.contains('refund') || clean.contains('credited')) {
          direction = 'income';
          dirConf = 0.95;
          break;
        }
      }
    }

    // Merchant Extraction
    final merchantResult = MerchantEntityScorer.scoreCandidate(
      candidateTokens: items.where((it) => it != heroAmount).toList(),
      amountBbox: heroAmount.bbox,
      directionAnchorBbox: anchorItem?.bbox,
      imgWidth: imgWidth,
      imgHeight: imgHeight,
    );

    // Date Extraction
    String? dateText;
    BoundingBox? dateBbox;
    double dateConf = 0.50;
    for (final it in items) {
      if (it == heroAmount) continue;
      final dRes = UniversalDateDetector.detect(it.textNormalized);
      if (dRes.isAny) {
        dateText = it.textNormalized;
        dateBbox = it.bbox;
        dateConf = dRes.confidence;
        break;
      }
    }

    final warnings = <String>[];
    if (merchantResult.name == null) {
      warnings.add('Merchant uncertain');
    }
    if (dateText == null) {
      warnings.add('Date not detected');
    }

    final amtConfidence = heroAmount.confidence;
    final groupingConf = (amtConfidence * 0.4 +
            merchantResult.confidence * 0.35 +
            dateConf * 0.25)
        .clamp(0.1, 1.0);

    final evidence = {
      'layout': 'single_receipt',
      'amount_token': heroAmount.text,
      'amount_normalized': heroAmount.textNormalized,
      'amount_bbox': heroAmount.bbox.toJson(),
      'merchant_tokens': merchantResult.sourceTokens.map((t) => t.text).toList(),
      'date_token': dateText,
      'direction': direction,
    };

    return [
      ExtractedTransaction(
        amountTextRaw: heroAmount.text,
        amountTextNormalized: heroAmount.textNormalized,
        amountValue: amtCls?.parsedValue,
        amountMinorUnits: amtMinor,
        amountConfidence: amtConfidence,
        amountBbox: heroAmount.bbox,
        merchantText: merchantResult.name,
        merchantBbox: merchantResult.bbox,
        merchantConfidence: merchantResult.confidence,
        dateText: dateText,
        dateBbox: dateBbox,
        dateConfidence: dateConf,
        groupingConfidence: groupingConf,
        transactionType: direction,
        typeConfidence: dirConf,
        warnings: warnings,
        ocrEvidence: evidence,
      )
    ];
  }
}
