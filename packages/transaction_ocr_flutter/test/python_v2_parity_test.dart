import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:transaction_ocr_flutter/transaction_ocr_flutter.dart';

void main() {
  group('Python V2 Parity Tests', () {
    test('Parity with screenshot_001_consolidated_ocr.json', () async {
      final file = File('../data/outputs/screenshot_001_consolidated_ocr.json');
      final targetFile = file.existsSync() ? file : File('data/outputs/screenshot_001_consolidated_ocr.json');
      if (!targetFile.existsSync()) return;

      final content = await targetFile.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;

      final rawDetections = (data['detections'] as List<dynamic>).cast<Map<String, dynamic>>();
      final imgW = data['width'] as int? ?? 462;
      final imgH = data['height'] as int? ?? 1024;

      final consolidated = OcrCandidateConsolidator.consolidate(rawDetections);
      consolidated.sort((a, b) {
        final yCmp = a.bbox.center.y.compareTo(b.bbox.center.y);
        if (yCmp != 0) return yCmp;
        return a.bbox.minX.compareTo(b.bbox.minX);
      });

      final grouperInputDets = consolidated.map((c) => {
            'text': c.text,
            'text_normalized': c.textNormalized,
            'confidence': c.confidence,
            'composite_score': c.compositeScore,
            'bbox': c.bbox,
          }).toList();

      final grouperResult = TransactionGrouper.group(
        detections: grouperInputDets,
        imgWidth: imgW,
        imgHeight: imgH,
      );

      expect(grouperResult.transactionCandidates.length, equals(10));

      final extractedAmounts = grouperResult.transactionCandidates
          .map((c) => c.amountValue)
          .where((v) => v != null)
          .toSet();

      expect(extractedAmounts.contains(40), isTrue); // Ashish Nayak
      expect(extractedAmounts.contains(349), isTrue); // Jio
      expect(extractedAmounts.contains(2500), isTrue); // Bishal
      expect(extractedAmounts.contains(20), isTrue); // Hemant / Sarita
      expect(extractedAmounts.contains(50), isTrue); // Krishna Store
      expect(extractedAmounts.contains(205), isTrue); // Prabhat Mistanna
      expect(extractedAmounts.contains(200), isTrue); // Abhijeet
      expect(extractedAmounts.contains(75), isTrue); // Om hotel
      expect(extractedAmounts.contains(110), isTrue); // Sapan
    });

    test('Parity with screenshot_003_consolidated_ocr.json (₹5,000 vs 75,000 normalization)', () async {
      final file = File('../data/outputs/screenshot_003_consolidated_ocr.json');
      final targetFile = file.existsSync() ? file : File('data/outputs/screenshot_003_consolidated_ocr.json');
      if (!targetFile.existsSync()) return;

      final content = await targetFile.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;

      final rawDetections = (data['detections'] as List<dynamic>).cast<Map<String, dynamic>>();
      final imgW = data['width'] as int? ?? 462;
      final imgH = data['height'] as int? ?? 1024;

      final consolidated = OcrCandidateConsolidator.consolidate(rawDetections);
      consolidated.sort((a, b) {
        final yCmp = a.bbox.center.y.compareTo(b.bbox.center.y);
        if (yCmp != 0) return yCmp;
        return a.bbox.minX.compareTo(b.bbox.minX);
      });

      final grouperInputDets = consolidated.map((c) => {
            'text': c.text,
            'text_normalized': c.textNormalized,
            'confidence': c.confidence,
            'composite_score': c.compositeScore,
            'bbox': c.bbox,
          }).toList();

      final grouperResult = TransactionGrouper.group(
        detections: grouperInputDets,
        imgWidth: imgW,
        imgHeight: imgH,
      );

      final sbiCandidate = grouperResult.transactionCandidates.firstWhere(
        (c) => c.amountValue == 5000,
        orElse: () => throw StateError('Expected candidate with amount 5000'),
      );

      expect(sbiCandidate.amountValue, equals(5000));
      expect(sbiCandidate.amountTextRaw, equals('75,000'));
      expect(sbiCandidate.amountTextNormalized, equals('₹5,000'));
      expect(sbiCandidate.merchantText?.contains('SBI'), isTrue);
    });
  });
}
