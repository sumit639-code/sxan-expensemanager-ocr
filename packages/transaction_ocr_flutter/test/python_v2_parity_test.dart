import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:transaction_ocr_flutter/transaction_ocr_flutter.dart';

File? _findFixture(String name) {
  final candidates = [
    File('test/fixtures/$name'),
    File('fixtures/$name'),
    File('../fixtures/$name'),
    File('../data/outputs/$name'),
    File('data/outputs/$name'),
  ];
  for (final f in candidates) {
    if (f.existsSync()) return f;
  }
  return null;
}

void main() {
  group('Python V2 Parity Tests', () {
    test('Parity with screenshot_001_consolidated_ocr.json', () async {
      final targetFile = _findFixture('screenshot_001_consolidated_ocr.json');
      expect(targetFile, isNotNull, reason: 'Fixture screenshot_001_consolidated_ocr.json must exist');

      final content = await targetFile!.readAsString();
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

    test('Parity with screenshot_003_consolidated_ocr.json (All 10 Google Pay Transactions Extracted)', () async {
      final targetFile = _findFixture('screenshot_003_consolidated_ocr.json');
      expect(targetFile, isNotNull, reason: 'Fixture screenshot_003_consolidated_ocr.json must exist');

      final content = await targetFile!.readAsString();
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

      // Verify exact count: 10 transactions
      expect(grouperResult.transactionCandidates.length, equals(10));

      // Check 1: Hemant Store — ₹20
      final tx1 = grouperResult.transactionCandidates[0];
      expect(tx1.merchantText, equals('HemantStore'));
      expect(tx1.amountValue, equals(20));
      expect(tx1.amountMinorUnits, equals(2000));
      expect(tx1.dateText, contains('September'));

      // Check 2: THE PRABHAT MISTANNA BHANDAR — ₹205 (from 7205)
      final tx2 = grouperResult.transactionCandidates[1];
      expect(tx2.merchantText, equals('THE PRABHAT MISTANNA BHANDAR'));
      expect(tx2.amountValue, equals(205));
      expect(tx2.amountMinorUnits, equals(20500));

      // Check 3: ABHIJEET KUMAR SINGH — ₹200
      final tx3 = grouperResult.transactionCandidates[2];
      expect(tx3.merchantText, equals('ABHIJEET KUMAR SINGH'));
      expect(tx3.amountValue, equals(200));
      expect(tx3.amountMinorUnits, equals(20000));

      // Check 4: Om hotel sweet and snacks — ₹75
      final tx4 = grouperResult.transactionCandidates[3];
      expect(tx4.merchantText, equals('Omhotelsweetandsnacks'));
      expect(tx4.amountValue, equals(75));
      expect(tx4.amountMinorUnits, equals(7500));

      // Check 5: SAPAN KUMAR MANDAL — ₹110
      final tx5 = grouperResult.transactionCandidates[4];
      expect(tx5.merchantText, equals('SAPAN KUMAR MANDAL'));
      expect(tx5.amountValue, equals(110));
      expect(tx5.amountMinorUnits, equals(11000));

      // Check 6: SBI ATM CASH WITHDRAWAL THROUGH UPI — ₹5,000 (Multi-line merchant!)
      final tx6 = grouperResult.transactionCandidates[5];
      expect(tx6.merchantText, contains('SBIATM CASH WITHDRAWAL'));
      expect(tx6.merchantText, contains('THROUGH UPI'));
      expect(tx6.amountValue, equals(5000));
      expect(tx6.amountMinorUnits, equals(500000));
      expect(tx6.amountValue, isNot(equals(75000)));
      expect(tx6.dateText, contains('2September'));

      // Check 7: MS SATYAM SERVICE STA — ₹2,200
      final tx7 = grouperResult.transactionCandidates[6];
      expect(tx7.merchantText, equals('MS SATYAM SERVICE STA'));
      expect(tx7.amountValue, equals(2200));
      expect(tx7.amountMinorUnits, equals(220000));

      // Check 8: POOJA — ₹120
      final tx8 = grouperResult.transactionCandidates[7];
      expect(tx8.merchantText, equals('POOJA'));
      expect(tx8.amountValue, equals(120));
      expect(tx8.amountMinorUnits, equals(12000));

      // Check 9: Sri Ram store — ₹138
      final tx9 = grouperResult.transactionCandidates[8];
      expect(tx9.merchantText, equals('Sri Ram store'));
      expect(tx9.amountValue, equals(138));
      expect(tx9.amountMinorUnits, equals(13800));

      // Check 10: VIKASH MUNDHRA — ₹425
      final tx10 = grouperResult.transactionCandidates[9];
      expect(tx10.merchantText, equals('VIKASH MUNDHRA'));
      expect(tx10.amountValue, equals(425));
      expect(tx10.amountMinorUnits, equals(42500));

      // Total sum check: exactly 849300 minor units (₹8,493.00)
      final totalMinor = grouperResult.transactionCandidates
          .map((c) => c.amountMinorUnits ?? 0)
          .fold<int>(0, (sum, m) => sum + m);
      expect(totalMinor, equals(849300));
    });
  });
}

