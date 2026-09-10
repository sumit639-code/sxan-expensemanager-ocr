import 'dart:math' as math;
import 'dart:ui';

import '../../../../shared/enums/transaction_enums.dart';
import '../../domain/entities/extracted_transaction.dart';
import '../../domain/entities/ocr_document.dart';
import '../../domain/services/transaction_parser.dart';
import '../models/python_ocr_response.dart';
import 'rule_based_transaction_parser.dart';

/// Application/domain-level parser that interprets Python RapidOCR-ONNX API output
/// into structured [ExtractedTransaction] objects.
///
/// Converts raw [PythonOcrItem]s into a layout-aware [OcrDocument] and applies
/// 2D spatial row segmentation, decimal-safe amount reconstruction, date filtering,
/// and categorization rules.
class PythonOcrTransactionParser implements TransactionParser {
  final RuleBasedTransactionParser _innerParser;

  PythonOcrTransactionParser({RuleBasedTransactionParser? innerParser})
      : _innerParser = innerParser ?? RuleBasedTransactionParser();

  @override
  List<ExtractedTransaction> parse(OcrDocument document) {
    return _innerParser.parse(document);
  }

  /// Parses a [PythonOcrResponse] into a list of [ExtractedTransaction] domain objects.
  List<ExtractedTransaction> parseResponse(
    PythonOcrResponse response, {
    String? sourceReference,
    double? imageWidth,
    double? imageHeight,
  }) {
    if (!response.success) {
      return const [];
    }

    // 1. If V2 endpoint returned pre-extracted candidates, convert them directly
    if (response.transactionCandidates.isNotEmpty) {
      final results = <ExtractedTransaction>[];
      final now = DateTime.now();

      for (int i = 0; i < response.transactionCandidates.length; i++) {
        final cand = response.transactionCandidates[i];
        final amount = cand.amount ?? (cand.amountDouble != null ? (cand.amountDouble! * 100).round() : null);
        if (amount == null || amount <= 0) continue;

        final isIncome = (cand.type?.toLowerCase() == 'income' ||
            cand.type?.toLowerCase() == 'credit' ||
            cand.type?.toLowerCase() == 'received');

        final txType = isIncome ? TransactionType.income : TransactionType.expense;
        final title = cand.title ?? cand.merchant ?? 'Transaction #${i + 1}';

        results.add(
          ExtractedTransaction(
            id: cand.id ?? 'tx_v2_${DateTime.now().microsecondsSinceEpoch}_$i',
            date: cand.date ?? now,
            amount: amount,
            currency: cand.currency ?? 'INR',
            title: title,
            merchant: cand.merchant,
            categoryId: cand.category ?? (isIncome ? 'income' : 'general'),
            type: txType,
            confidence: cand.confidence,
            sourceReference: sourceReference ?? response.filename,
            rawText: cand.rawJson?.toString() ?? title,
          ),
        );
      }

      if (results.isNotEmpty) {
        return results;
      }
    }

    if (response.items.isEmpty) {
      return const [];
    }

    // 2. Convert Python OCR items into an OcrDocument (V1 pipeline)
    final ocrDoc = convertToOcrDocument(
      response.items,
      imagePath: sourceReference ?? response.filename,
      estimatedWidth: imageWidth,
      estimatedHeight: imageHeight,
    );

    // 3. Parse through spatial rule-based parser
    final transactions = _innerParser.parse(ocrDoc);

    // 4. Enrich transactions with Python OCR item composite scores if available
    return transactions.map((tx) {
      // Find matching items to compute aggregate OCR confidence
      final relatedScores = <double>[];
      for (final item in response.items) {
        if (tx.merchant != null &&
            item.text.isNotEmpty &&
            tx.merchant!.toLowerCase().contains(item.text.toLowerCase())) {
          relatedScores.add(item.compositeScore);
        }
      }

      double adjustedConfidence = tx.confidence;
      if (relatedScores.isNotEmpty) {
        final avgScore =
            relatedScores.reduce((a, b) => a + b) / relatedScores.length;
        // Blend parser structural confidence (70%) with OCR model confidence (30%)
        adjustedConfidence =
            (tx.confidence * 0.70) + (avgScore.clamp(0.0, 1.0) * 0.30);
      }

      return ExtractedTransaction(
        id: tx.id,
        date: tx.date,
        amount: tx.amount,
        currency: tx.currency,
        title: tx.title,
        merchant: tx.merchant,
        categoryId: tx.categoryId,
        type: tx.type,
        confidence: double.parse(adjustedConfidence.toStringAsFixed(2)),
        sourceReference: tx.sourceReference ?? response.filename,
        rawText: tx.rawText,
        isDuplicate: tx.isDuplicate,
        duplicateSource: tx.duplicateSource,
        note: tx.note,
      );
    }).toList();
  }

  /// Converts a list of [PythonOcrItem]s into a structured [OcrDocument]
  /// preserving 2D spatial positions, reading order, and confidence scores.
  OcrDocument convertToOcrDocument(
    List<PythonOcrItem> items, {
    String? imagePath,
    double? estimatedWidth,
    double? estimatedHeight,
  }) {
    // Sort items by reading_index or top-to-bottom spatial position
    final sorted = List<PythonOcrItem>.from(items);
    sorted.sort((a, b) {
      if (a.boundingBox != null && b.boundingBox != null) {
        final diffY = a.boundingBox!.top - b.boundingBox!.top;
        if (diffY.abs() > 15) {
          return diffY.compareTo(0);
        }
        return a.boundingBox!.left.compareTo(b.boundingBox!.left);
      }
      return a.readingIndex.compareTo(b.readingIndex);
    });

    double maxX = 0;
    double maxY = 0;

    final ocrLines = <OcrLine>[];
    final fullTextLines = <String>[];

    for (final item in sorted) {
      final text = item.effectiveText;
      if (text.isEmpty) continue;

      fullTextLines.add(text);

      if (item.boundingBox != null) {
        maxX = math.max(maxX, item.boundingBox!.right);
        maxY = math.max(maxY, item.boundingBox!.bottom);
      }

      ocrLines.add(
        OcrLine(
          text: text,
          boundingBox: item.boundingBox,
          confidence: item.compositeScore,
          elements: [
            OcrElement(
              text: text,
              boundingBox: item.boundingBox,
              confidence: item.compositeScore,
            ),
          ],
        ),
      );
    }

    final docWidth = estimatedWidth ?? (maxX > 0 ? maxX : 720.0);
    final docHeight = estimatedHeight ?? (maxY > 0 ? maxY : 1600.0);

    return OcrDocument(
      fullText: fullTextLines.join('\n'),
      blocks: [
        OcrBlock(
          text: fullTextLines.join('\n'),
          boundingBox: Rect.fromLTWH(0, 0, docWidth, docHeight),
          lines: ocrLines,
        ),
      ],
      lines: ocrLines,
      imageWidth: docWidth.toInt(),
      imageHeight: docHeight.toInt(),
      imagePath: imagePath,
    );
  }
}
