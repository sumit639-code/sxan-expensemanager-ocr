import 'dart:ui';

import '../../domain/entities/ocr_document.dart';
import 'amount_reconstructor.dart';
import 'date_extractor.dart';

/// Identified layout type of the screenshot document.
enum DetectedLayoutType {
  /// Google Pay transaction history list:
  /// Left avatar circle, merchant name, date below merchant, amount on right.
  layoutA,

  /// PhonePe / detailed transaction history:
  /// Direction header ("Paid to" / "Received from"), merchant name, amount,
  /// relative/absolute date ("8 hours ago"), account footer ("Debited from" / "Credited to").
  layoutB,

  /// Single transaction receipt screen.
  singleReceipt,
}

/// A structured transaction candidate row segmented from OCR lines.
class SegmentedTransactionRow {
  final List<OcrLine> lines;
  final ReconstructedAmount amount;
  final DateExtractionResult? dateResult;
  final String? merchantRaw;
  final bool hasDirectionHeader;
  final bool isIncomeSignal;
  final DetectedLayoutType layoutType;

  const SegmentedTransactionRow({
    required this.lines,
    required this.amount,
    this.dateResult,
    this.merchantRaw,
    this.hasDirectionHeader = false,
    this.isIncomeSignal = false,
    required this.layoutType,
  });

  @override
  String toString() =>
      'SegmentedTransactionRow(layout: $layoutType, amt: ${amount.amountMinor}, merchant: "$merchantRaw", date: "${dateResult?.rawMatchedText}")';
}

/// Layout-aware segmenter that converts raw OCR lines and blocks into
/// distinct transaction rows by analyzing 2D spatial positions (X, Y bounding boxes).
class LayoutRowSegmenter {
  const LayoutRowSegmenter();

  /// Computes adaptive vertical thresholds based on document height.
  /// On a 1600px screenshot, a transaction row is ~70px tall.
  /// Scale thresholds proportionally for other resolutions.
  static _AdaptiveThresholds _thresholds(double docHeight) {
    // Reference: 1600px high screenshot
    final scale = (docHeight > 0 ? docHeight / 1600.0 : 1.0).clamp(0.5, 3.0);
    return _AdaptiveThresholds(
      rowBandAbove: (30 * scale).round().toDouble(),
      rowBandBelow: (65 * scale).round().toDouble(),
      rowTopToBottom: (45 * scale).round().toDouble(),
      wrappedLineGap: (40 * scale).round().toDouble(),
      dateLookAheadGap: (80 * scale).round().toDouble(),
      sameLineTolerance: (15 * scale).round().toDouble(),
    );
  }

  /// Segments an [OcrDocument] into structured [SegmentedTransactionRow] candidates.
  List<SegmentedTransactionRow> segmentDocument(OcrDocument document) {
    if (document.isEmpty) return const [];

    // 1. Merge split/fragmented OCR lines (e.g. '₹' and '5,000' or '5,' and '000')
    final mergedLines = _mergeFragmentedAmountLines(document.lines);

    // 2. Filter out non-transaction UI chrome (status bar, search bar, filter chips, nav bar, avatar initials)
    final filteredLines = _filterUiChrome(
      mergedLines,
      document.estimatedWidth,
      document.estimatedHeight,
    );

    if (filteredLines.isEmpty) return const [];

    // 3. Detect Layout Type
    final layoutType = _detectLayoutType(filteredLines);
    final docHeight = document.estimatedHeight;

    switch (layoutType) {
      case DetectedLayoutType.layoutB:
        return _segmentLayoutB(filteredLines);
      case DetectedLayoutType.singleReceipt:
        return _segmentSingleReceipt(filteredLines);
      case DetectedLayoutType.layoutA:
        return _segmentLayoutA(filteredLines, document.estimatedWidth, docHeight);
    }
  }

  // ---------------------------------------------------------------------------
  // 1. Layout Detection
  // ---------------------------------------------------------------------------
  DetectedLayoutType _detectLayoutType(List<OcrLine> lines) {
    int layoutBMarkers = 0;
    int amountCount = 0;

    for (final line in lines) {
      final lower = line.text.toLowerCase();
      if (lower.contains('paid to') ||
          lower.contains('payment to') ||
          lower.contains('received from') ||
          lower.contains('debited from') ||
          lower.contains('credited to')) {
        layoutBMarkers++;
      }

      if (AmountReconstructor.parseAmount(line.text) != null) {
        amountCount++;
      }
    }

    if (layoutBMarkers >= 2 || (layoutBMarkers >= 1 && amountCount >= 2)) {
      return DetectedLayoutType.layoutB;
    }

    if (amountCount <= 1 &&
        (layoutBMarkers >= 1 ||
            lines.any((l) => l.text.toLowerCase().contains('successful')))) {
      return DetectedLayoutType.singleReceipt;
    }

    return DetectedLayoutType.layoutA;
  }

  // ---------------------------------------------------------------------------
  // 2. Layout A Segmentation (Google Pay list style)
  // ---------------------------------------------------------------------------
  List<SegmentedTransactionRow> _segmentLayoutA(
    List<OcrLine> lines,
    double docWidth,
    double docHeight,
  ) {
    final th = _thresholds(docHeight);
    final sorted = List<OcrLine>.from(lines);
    sorted.sort((a, b) {
      final aTop = a.boundingBox?.top ?? 0;
      final bTop = b.boundingBox?.top ?? 0;
      return aTop.compareTo(bTop);
    });

    final rows = <SegmentedTransactionRow>[];
    final processedLineIndices = <int>{};

    // PASS 1: Check for combined lines (e.g. "ASHISH KUMAR NAYAK ₹40" or "JIO ₹349")
    for (int i = 0; i < sorted.length; i++) {
      final line = sorted[i];
      final split = AmountReconstructor.splitCombinedMerchantAndAmount(
        line.text,
      );
      if (split != null) {
        processedLineIndices.add(i);

        // Check preceding line for wrapped multi-line merchant title (e.g. "SBI ATM CASH WITHDRAWAL")
        var effectiveMerchant = split.merchantPart;
        if (i > 0 && !processedLineIndices.contains(i - 1)) {
          final prevLine = sorted[i - 1];
          final prevText = _cleanTitleText(prevLine.text);
          if (prevText.isNotEmpty &&
              !_isSingleLetterAvatar(prevText) &&
              DateExtractor.parseDate(prevText) == null &&
              AmountReconstructor.parseAmount(prevText) == null) {
            // Check vertical closeness using adaptive threshold
            final prevBottom = prevLine.boundingBox?.bottom ?? 0;
            final curTop = line.boundingBox?.top ?? 0;
            if ((curTop - prevBottom).abs() <= th.wrappedLineGap) {
              effectiveMerchant = '$prevText $effectiveMerchant';
              processedLineIndices.add(i - 1);
            }
          }
        }

        // Check next 1-3 lines for date (e.g. "7 September", "2 September 2026 at 2:35 pm")
        // ML Kit may insert extra lines between the merchant+amount and the date.
        DateExtractionResult? dateRes;
        final curBottom = line.boundingBox?.bottom ?? 0;
        for (int d = 1; d <= 3 && (i + d) < sorted.length; d++) {
          final candidateLine = sorted[i + d];
          if (processedLineIndices.contains(i + d)) continue;
          final candidateTop = candidateLine.boundingBox?.top ?? 0;
          // Only look within a reasonable vertical distance
          if ((candidateTop - curBottom).abs() > th.dateLookAheadGap) break;
          final parsed = DateExtractor.parseDate(candidateLine.text);
          if (parsed != null) {
            dateRes = parsed;
            processedLineIndices.add(i + d);
            break;
          }
          // If the candidate is another amount or combined line, stop looking
          if (AmountReconstructor.parseAmount(candidateLine.text) != null ||
              AmountReconstructor.splitCombinedMerchantAndAmount(candidateLine.text) != null) {
            break;
          }
        }

        rows.add(
          SegmentedTransactionRow(
            lines: [line],
            amount: split.amount,
            dateResult: dateRes,
            merchantRaw: effectiveMerchant,
            isIncomeSignal: split.amount.isIncome,
            layoutType: DetectedLayoutType.layoutA,
          ),
        );
      }
    }

    // PASS 2: Separate-line amounts (e.g. standalone "₹5,000", "₹40", or right-side numbers)
    final remainingLines = <OcrLine>[];
    for (int i = 0; i < sorted.length; i++) {
      if (!processedLineIndices.contains(i)) {
        remainingLines.add(sorted[i]);
      }
    }

    // Identify amount candidates from remaining lines
    final amountLines = <OcrLine>[];
    for (final line in remainingLines) {
      if (AmountReconstructor.isBlacklistedBalanceOrSummary(line.text)) {
        continue;
      }
      final isRightAligned = (line.boundingBox?.left ?? 0) > docWidth * 0.45;
      final amt =
          AmountReconstructor.parseAmount(line.text) ??
          (isRightAligned
              ? AmountReconstructor.parseRightSideCandidate(line.text)
              : null);

      if (amt != null) {
        amountLines.add(line);
      }
    }

    final hasReal2DLayout = amountLines.any(
      (l) => (l.boundingBox?.left ?? 0) > docWidth * 0.40,
    );

    if (hasReal2DLayout) {
      // Spatial 2D grouping by vertical proximity:
      for (final amtLine in amountLines) {
        final amt =
            AmountReconstructor.parseAmount(amtLine.text) ??
            AmountReconstructor.parseRightSideCandidate(amtLine.text)!;
        final amtCenterY = amtLine.boundingBox?.center.dy ?? 0;
        final amtTop = amtLine.boundingBox?.top ?? 0;
        final amtBottom = amtLine.boundingBox?.bottom ?? 0;

        final rowLines = <OcrLine>[];
        for (final candidate in remainingLines) {
          if (candidate == amtLine) continue;
          final cTop = candidate.boundingBox?.top ?? 0;
          final cBottom = candidate.boundingBox?.bottom ?? 0;
          final cCenterY = candidate.boundingBox?.center.dy ?? 0;

          // 1. Must be closer vertically to THIS amount than any other amount line
          bool isClosest = true;
          final distToThis = (cCenterY - amtCenterY).abs();
          for (final other in amountLines) {
            if (other == amtLine) continue;
            final otherCenterY = other.boundingBox?.center.dy ?? 0;
            if ((cCenterY - otherCenterY).abs() < distToThis) {
              isClosest = false;
              break;
            }
          }
          if (!isClosest) continue;

          // 2. Must be within reasonable vertical band for a row (adaptive thresholds)
          final isVerticallyNear =
              (cTop >= amtTop - th.rowBandAbove && cBottom <= amtBottom + th.rowBandBelow) ||
              (cTop >= amtTop - th.sameLineTolerance && cTop <= amtBottom + th.rowTopToBottom);

          // 3. Must be left of amount
          final isLeftOfAmount =
              (candidate.boundingBox?.right ?? 0) <=
              (amtLine.boundingBox?.left ?? docWidth) + 25;

          if (isVerticallyNear && isLeftOfAmount) {
            rowLines.add(candidate);
          }
        }

        DateExtractionResult? detectedDate;
        final merchantParts = <String>[];

        for (final rl in rowLines) {
          final d = DateExtractor.parseDate(rl.text);
          if (d != null && detectedDate == null) {
            detectedDate = d;
          } else {
            final clean = _cleanTitleText(rl.text);
            if (clean.isNotEmpty && !_isSingleLetterAvatar(clean)) {
              merchantParts.add(clean);
            }
          }
        }

        // If no date found in the row lines, look for date-only lines
        // directly below the amount (GPay puts dates on the line below).
        if (detectedDate == null) {
          for (final candidate in remainingLines) {
            if (rowLines.contains(candidate) || candidate == amtLine) continue;
            final cTop = candidate.boundingBox?.top ?? 0;
            final cCenterY = candidate.boundingBox?.center.dy ?? 0;
            // Must be BELOW the amount
            if (cTop < amtBottom) continue;
            // Must be within date look-ahead distance
            if ((cTop - amtBottom) > th.dateLookAheadGap) continue;
            // Must be closest to THIS amount
            bool isClosest = true;
            final distToThis = (cCenterY - amtCenterY).abs();
            for (final other in amountLines) {
              if (other == amtLine) continue;
              final otherCenterY = other.boundingBox?.center.dy ?? 0;
              if ((cCenterY - otherCenterY).abs() < distToThis) {
                isClosest = false;
                break;
              }
            }
            if (!isClosest) continue;
            final d = DateExtractor.parseDate(candidate.text);
            if (d != null) {
              detectedDate = d;
              break;
            }
          }
        }

        final combinedMerchant = merchantParts.join(' ').trim();

        rows.add(
          SegmentedTransactionRow(
            lines: [amtLine, ...rowLines],
            amount: amt,
            dateResult: detectedDate,
            merchantRaw: combinedMerchant.isNotEmpty ? combinedMerchant : null,
            isIncomeSignal: amt.isIncome,
            layoutType: DetectedLayoutType.layoutA,
          ),
        );
      }
    } else {
      // Sequential fallback for 1D plain text feeds
      int lastAmountIndex = -1;
      for (int i = 0; i < remainingLines.length; i++) {
        final line = remainingLines[i];
        final amt =
            AmountReconstructor.parseAmount(line.text) ??
            AmountReconstructor.parseRightSideCandidate(line.text);
        if (amt != null) {
          final cluster = remainingLines.sublist(lastAmountIndex + 1, i);
          lastAmountIndex = i;

          DateExtractionResult? dateRes;
          String? merchant;

          for (final cl in cluster) {
            final d = DateExtractor.parseDate(cl.text);
            if (d != null && dateRes == null) {
              dateRes = d;
            } else {
              final c = _cleanTitleText(cl.text);
              if (c.isNotEmpty &&
                  !_isDirectionPrefix(c) &&
                  !_isDebitCreditFooter(c) &&
                  !_isSingleLetterAvatar(c) &&
                  AmountReconstructor.parseAmount(c) == null &&
                  merchant == null) {
                merchant = c;
              }
            }
          }

          rows.add(
            SegmentedTransactionRow(
              lines: [...cluster, line],
              amount: amt,
              dateResult: dateRes,
              merchantRaw: merchant,
              isIncomeSignal: amt.isIncome,
              layoutType: DetectedLayoutType.layoutA,
            ),
          );
        }
      }
    }

    return rows;
  }

  // ---------------------------------------------------------------------------
  // 3. Layout B Segmentation (PhonePe / Timeline style)
  // ---------------------------------------------------------------------------
  List<SegmentedTransactionRow> _segmentLayoutB(List<OcrLine> lines) {
    final rows = <SegmentedTransactionRow>[];

    // Anchors are marked by: "Paid to", "Payment to", "Received from"
    final anchorIndices = <int>[];
    for (int i = 0; i < lines.length; i++) {
      final lower = lines[i].text.toLowerCase();
      if (lower.startsWith('paid to') ||
          lower.startsWith('payment to') ||
          lower.startsWith('received from')) {
        anchorIndices.add(i);
      }
    }

    if (anchorIndices.isEmpty) {
      for (int i = 0; i < lines.length; i++) {
        if (AmountReconstructor.parseAmount(lines[i].text) != null ||
            AmountReconstructor.splitCombinedMerchantAndAmount(lines[i].text) !=
                null) {
          anchorIndices.add(i > 0 ? i - 1 : 0);
        }
      }
    }

    for (int a = 0; a < anchorIndices.length; a++) {
      final start = anchorIndices[a];
      final end = (a < anchorIndices.length - 1)
          ? anchorIndices[a + 1]
          : lines.length;
      final blockLines = lines.sublist(start, end);

      ReconstructedAmount? amt;
      DateExtractionResult? dateRes;
      String? merchant;
      bool isIncome = false;
      bool hasDirection = false;

      for (final line in blockLines) {
        final text = line.text;
        final lower = text.toLowerCase();

        // Direction detection
        if (lower.contains('received from') || lower.contains('credited to')) {
          isIncome = true;
          hasDirection = true;
        } else if (lower.contains('paid to') ||
            lower.contains('payment to') ||
            lower.contains('debited from')) {
          hasDirection = true;
        }

        // Check if line is combined merchant + amount (e.g. "ICCL Mutual Funds Autopay ₹1,500")
        final split = AmountReconstructor.splitCombinedMerchantAndAmount(text);
        if (split != null) {
          amt ??= split.amount;
          if (split.amount.isIncome) isIncome = true;
          merchant ??= split.merchantPart;
          continue;
        }

        // Standalone amount detection
        if (amt == null) {
          final parsed =
              AmountReconstructor.parseAmount(text) ??
              AmountReconstructor.parseRightSideCandidate(text);
          if (parsed != null) {
            amt = parsed;
            if (parsed.isIncome) isIncome = true;
          }
        }

        // Date detection
        if (dateRes == null) {
          final d = DateExtractor.parseDate(text);
          if (d != null) {
            dateRes = d;
          }
        }

        // Merchant extraction
        if (merchant == null) {
          final cleaned = _cleanTitleText(text);
          if (cleaned.isNotEmpty &&
              !_isDirectionPrefix(cleaned) &&
              !_isDebitCreditFooter(cleaned) &&
              DateExtractor.parseDate(cleaned) == null &&
              AmountReconstructor.parseAmount(cleaned) == null) {
            merchant = cleaned;
          }
        }
      }

      if (amt != null) {
        rows.add(
          SegmentedTransactionRow(
            lines: blockLines,
            amount: amt,
            dateResult: dateRes,
            merchantRaw: merchant,
            hasDirectionHeader: hasDirection,
            isIncomeSignal: isIncome || amt.isIncome,
            layoutType: DetectedLayoutType.layoutB,
          ),
        );
      }
    }

    return rows;
  }

  // ---------------------------------------------------------------------------
  // 4. Single Receipt Segmentation
  // ---------------------------------------------------------------------------
  List<SegmentedTransactionRow> _segmentSingleReceipt(List<OcrLine> lines) {
    ReconstructedAmount? primaryAmt;
    DateExtractionResult? dateRes;
    String? merchant;
    bool isIncome = false;

    for (final line in lines) {
      final text = line.text;
      final lower = text.toLowerCase();

      if (lower.contains('received from') ||
          lower.contains('credited to') ||
          text.contains('+')) {
        isIncome = true;
      }

      if (primaryAmt == null) {
        final a = AmountReconstructor.parseAmount(text);
        if (a != null) {
          primaryAmt = a;
          if (a.isIncome) isIncome = true;
        }
      }

      dateRes ??= DateExtractor.parseDate(text);

      if (merchant == null) {
        final c = _cleanTitleText(text);
        if (c.isNotEmpty &&
            !_isDirectionPrefix(c) &&
            !_isDebitCreditFooter(c) &&
            DateExtractor.parseDate(c) == null &&
            AmountReconstructor.parseAmount(c) == null) {
          merchant = c;
        }
      }
    }

    if (primaryAmt == null) return const [];

    return [
      SegmentedTransactionRow(
        lines: lines,
        amount: primaryAmt,
        dateResult: dateRes,
        merchantRaw: merchant,
        isIncomeSignal: isIncome,
        layoutType: DetectedLayoutType.singleReceipt,
      ),
    ];
  }

  // ---------------------------------------------------------------------------
  // 5. Amount Fragment Reconstruction Across Lines
  // ---------------------------------------------------------------------------
  /// Combines split OCR lines:
  /// e.g. Line 1: '₹', Line 2: '5,000' -> '₹5,000'
  /// e.g. Line 1: '5,', Line 2: '000' -> '5,000'
  /// e.g. Line 1: '+', Line 2: '₹8,000' -> '+ ₹8,000'
  List<OcrLine> _mergeFragmentedAmountLines(List<OcrLine> inputLines) {
    if (inputLines.isEmpty) return const [];

    final merged = <OcrLine>[];
    int i = 0;

    while (i < inputLines.length) {
      final current = inputLines[i];
      final curText = current.text.trim();

      if (i + 1 < inputLines.length) {
        final next = inputLines[i + 1];
        final nextText = next.text.trim();

        // Check vertical alignment if bounding boxes exist
        bool isSpatiallyAligned = true;
        if (current.boundingBox != null && next.boundingBox != null) {
          final curBox = current.boundingBox!;
          final nextBox = next.boundingBox!;
          final vDiff = (curBox.center.dy - nextBox.center.dy).abs();
          final hDist = nextBox.left - curBox.right;
          // Must be roughly on the same vertical baseline and nearby horizontally
          if (vDiff > 25 || hDist > 80 || hDist < -20) {
            isSpatiallyAligned = false;
          }
        }

        // Never merge if either line is a recognized date
        final curIsDate = DateExtractor.parseDate(curText) != null;
        final nextIsDate = DateExtractor.parseDate(nextText) != null;

        if (isSpatiallyAligned && !curIsDate && !nextIsDate) {
          // 1. Standalone currency symbol or sign: e.g. '₹', '+', '-', '+ ₹'
          if (curText == '₹' ||
              curText == '+' ||
              curText == '-' ||
              curText == '+ ₹' ||
              curText == '- ₹') {
            if (RegExp(r'^[\d,.]+$').hasMatch(nextText) ||
                nextText.startsWith('₹')) {
              final combinedText = '$curText $nextText';
              final newBox = _unionRects(current.boundingBox, next.boundingBox);
              merged.add(
                OcrLine(
                  text: combinedText,
                  boundingBox: newBox,
                  elements: [...current.elements, ...next.elements],
                  confidence: current.confidence,
                ),
              );
              i += 2;
              continue;
            }
          }

          // 2. Trailing comma split: e.g. '5,' and next is '000' -> '5,000'
          if (curText.endsWith(',') &&
              (RegExp(r'^\d{3}$').hasMatch(nextText) ||
                  nextText.startsWith(',000') ||
                  nextText.startsWith('000'))) {
            final cleanNext = nextText.startsWith(',')
                ? nextText.substring(1)
                : nextText;
            final cleanCur = curText.substring(0, curText.length - 1);
            final combinedText = '$cleanCur,$cleanNext';
            final newBox = _unionRects(current.boundingBox, next.boundingBox);
            merged.add(
              OcrLine(
                text: combinedText,
                boundingBox: newBox,
                elements: [...current.elements, ...next.elements],
                confidence: current.confidence,
              ),
            );
            i += 2;
            continue;
          }
        }
      }

      merged.add(current);
      i++;
    }

    return merged;
  }

  // ---------------------------------------------------------------------------
  // 6. UI Chrome Filtering
  // ---------------------------------------------------------------------------
  List<OcrLine> _filterUiChrome(
    List<OcrLine> lines,
    double docWidth,
    double docHeight,
  ) {
    final blacklistedIndices = <int>{};
    for (int i = 0; i < lines.length; i++) {
      final text = lines[i].text.trim();
      if (AmountReconstructor.isBlacklistedBalanceOrSummary(text) ||
          AmountReconstructor.isIdentifierOrPhone(text)) {
        blacklistedIndices.add(i);
        if (i + 1 < lines.length) {
          final nextText = lines[i + 1].text.trim();
          if (AmountReconstructor.parseAmount(nextText) != null ||
              RegExp(r'^\d+$').hasMatch(nextText)) {
            blacklistedIndices.add(i + 1);
          }
        }
      }
    }

    final filtered = <OcrLine>[];
    for (int i = 0; i < lines.length; i++) {
      if (blacklistedIndices.contains(i)) continue;
      final line = lines[i];
      final text = line.text.trim();
      final lower = text.toLowerCase();

      // Top status bar (time, 5G, battery)
      if (RegExp(
        r'^\d{1,2}:\d{2}(?:\s*(?:am|pm))?$',
        caseSensitive: false,
      ).hasMatch(text)) {
        continue;
      }
      if (RegExp(r'^\d{1,3}%$').hasMatch(text) ||
          lower == '5g' ||
          lower == 'volte' ||
          lower == '4g') {
        continue;
      }

      // Search bar and top nav
      if (lower == 'search transactions' ||
          lower == 'search' ||
          lower == 'history' ||
          lower == 'help') {
        continue;
      }

      // Filter chips
      if (lower == 'status' ||
          lower == 'payment method' ||
          lower == 'date' ||
          lower == 'amount') {
        continue;
      }

      // Bottom bar
      if (lower == 'home' ||
          lower == 'alerts' ||
          lower == 'history' ||
          lower == 'rewards') {
        continue;
      }

      // Standalone circular avatar initial: single letter A-Z
      if (_isSingleLetterAvatar(text)) {
        continue;
      }

      // Blacklisted balances & summaries
      if (AmountReconstructor.isBlacklistedBalanceOrSummary(text)) {
        continue;
      }

      filtered.add(line);
    }

    return filtered;
  }

  bool _isSingleLetterAvatar(String s) {
    final clean = s.trim();
    return clean.length == 1 && RegExp(r'^[A-Za-z]$').hasMatch(clean);
  }

  bool _isDirectionPrefix(String s) {
    final lower = s.toLowerCase();
    return lower == 'paid to' ||
        lower == 'payment to' ||
        lower == 'received from' ||
        lower == 'sent to';
  }

  bool _isDebitCreditFooter(String s) {
    final lower = s.toLowerCase();
    return lower.startsWith('debited from') || lower.startsWith('credited to');
  }

  String _cleanTitleText(String s) {
    var text = s.trim();
    text = text.replaceAll(
      RegExp(
        r'^(paid to|payment to|received from|sent to)\s*',
        caseSensitive: false,
      ),
      '',
    );
    text = text.replaceAll(
      RegExp(r'\s+(debited from|credited to).*$', caseSensitive: false),
      '',
    );
    return text.trim();
  }

  Rect? _unionRects(Rect? a, Rect? b) {
    if (a == null) return b;
    if (b == null) return a;
    return Rect.fromLTRB(
      a.left < b.left ? a.left : b.left,
      a.top < b.top ? a.top : b.top,
      a.right > b.right ? a.right : b.right,
      a.bottom > b.bottom ? a.bottom : b.bottom,
    );
  }
}

/// Adaptive vertical thresholds scaled to image resolution.
class _AdaptiveThresholds {
  /// Max distance above an amount line to include as same row.
  final double rowBandAbove;

  /// Max distance below an amount line to include as same row.
  final double rowBandBelow;

  /// Max distance from amount top to candidate top for same-row check.
  final double rowTopToBottom;

  /// Max gap between lines for wrapped merchant titles.
  final double wrappedLineGap;

  /// Max vertical distance to search for a date line below a combined line.
  final double dateLookAheadGap;

  /// Tolerance for lines on the exact same visual row (same Y baseline).
  final double sameLineTolerance;

  const _AdaptiveThresholds({
    required this.rowBandAbove,
    required this.rowBandBelow,
    required this.rowTopToBottom,
    required this.wrappedLineGap,
    required this.dateLookAheadGap,
    required this.sameLineTolerance,
  });
}
