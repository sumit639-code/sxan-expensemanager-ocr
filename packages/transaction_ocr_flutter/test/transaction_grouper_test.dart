import 'package:flutter_test/flutter_test.dart';
import 'package:transaction_ocr_flutter/transaction_ocr_flutter.dart';

Map<String, dynamic> _makeDet(
  String text,
  String normText,
  double x1,
  double y1,
  double x2,
  double y2, {
  double confidence = 0.9,
}) {
  return {
    'text': text,
    'text_normalized': normText,
    'confidence': confidence,
    'composite_score': confidence,
    'bbox': [
      [x1, y1],
      [x2, y1],
      [x2, y2],
      [x1, y2]
    ],
  };
}

void main() {
  group('TransactionGrouper - Token Classification', () {
    test('status bar time should be classified as noise', () {
      final dets = [
        _makeDet('08:56', '08:56', 30, 18, 119, 36),
      ];
      final result = TransactionGrouper.group(
        detections: dets,
        imgWidth: 462,
        imgHeight: 1024,
      );
      expect(result.tokenClassifications.first.tokenType, equals('noise'));
    });

    test('date string like "7September" should be classified as date', () {
      final dets = [
        _makeDet('7September', '7September', 78, 247, 168, 267),
      ];
      final result = TransactionGrouper.group(
        detections: dets,
        imgWidth: 462,
        imgHeight: 1024,
      );
      expect(result.tokenClassifications.first.tokenType, equals('date'));
    });

    test('date string like "3August" and "1August" should be classified as date', () {
      final dets = [
        _makeDet('3August', '3August', 78, 195, 142, 213),
        _makeDet('1August', '1August', 76, 422, 140, 443),
      ];
      final result = TransactionGrouper.group(
        detections: dets,
        imgWidth: 462,
        imgHeight: 1024,
      );
      expect(result.tokenClassifications[0].tokenType, equals('date'));
      expect(result.tokenClassifications[1].tokenType, equals('date'));
    });

    test('relative date strings "Today" and "Yesterday" should be classified as date, not noise', () {
      final dets = [
        _makeDet('Today', 'Today', 78, 195, 142, 213),
        _makeDet('Yesterday', 'Yesterday', 78, 247, 168, 267),
      ];
      final result = TransactionGrouper.group(
        detections: dets,
        imgWidth: 462,
        imgHeight: 1024,
      );
      expect(result.tokenClassifications[0].tokenType, equals('date'));
      expect(result.tokenClassifications[1].tokenType, equals('date'));
    });

    test('rupee amount on right side should be classified as amount', () {
      final dets = [
        _makeDet('R40', '₹40', 406, 224, 441, 243, confidence: 1.1),
      ];
      final result = TransactionGrouper.group(
        detections: dets,
        imgWidth: 462,
        imgHeight: 1024,
      );
      expect(result.tokenClassifications.first.tokenType, equals('amount'));
    });

    test('left side merchant name should be classified as merchant', () {
      final dets = [
        _makeDet('ASHISHKUMARNAYAK', 'ASHISHKUMARNAYAK', 78, 218, 320, 240),
      ];
      final result = TransactionGrouper.group(
        detections: dets,
        imgWidth: 462,
        imgHeight: 1024,
      );
      expect(result.tokenClassifications.first.tokenType, equals('merchant'));
    });

    test('time string "08:56?" must NOT be classified as amount', () {
      final dets = [
        _makeDet('08:56?', '08:56?', 30, 18, 119, 36),
      ];
      final result = TransactionGrouper.group(
        detections: dets,
        imgWidth: 462,
        imgHeight: 1024,
      );
      expect(result.tokenClassifications.first.tokenType, isNot(equals('amount')));
    });

    test('date label "6September" on left side must NOT be amount', () {
      final dets = [
        _makeDet('6September', '6September', 78, 325, 169, 342),
      ];
      final result = TransactionGrouper.group(
        detections: dets,
        imgWidth: 462,
        imgHeight: 1024,
      );
      expect(result.tokenClassifications.first.tokenType, isNot(equals('amount')));
    });
  });

  group('TransactionGrouper - Spatial Row Grouping', () {
    test('full row (merchant + date + amount) grouped correctly', () {
      final dets = [
        _makeDet('ASHISHKUMARNAYAK', 'ASHISHKUMARNAYAK', 78, 218, 320, 240, confidence: 0.88),
        _makeDet('7September', '7September', 78, 247, 168, 267, confidence: 0.91),
        _makeDet('R40', '₹40', 406, 224, 441, 243, confidence: 1.15),
      ];
      final result = TransactionGrouper.group(
        detections: dets,
        imgWidth: 462,
        imgHeight: 1024,
      );

      expect(result.transactionCandidates.length, equals(1));
      final cand = result.transactionCandidates.first;
      expect(cand.amountValue, equals(40));
      expect(cand.merchantText?.toUpperCase().contains('ASHISH'), isTrue);
      expect(cand.dateText, isNotNull);
    });

    test('two rows produce two separate candidates', () {
      final dets = [
        // Row 1
        _makeDet('ASHISHKUMARNAYAK', 'ASHISHKUMARNAYAK', 78, 218, 320, 240, confidence: 0.88),
        _makeDet('7September', '7September', 78, 247, 168, 267, confidence: 0.91),
        _makeDet('R40', '₹40', 406, 224, 441, 243, confidence: 1.15),
        // Row 2
        _makeDet('JIO', 'JIO', 78, 298, 120, 318, confidence: 0.92),
        _makeDet('6September', '6September', 78, 325, 169, 342, confidence: 0.85),
        _makeDet('349', '349', 399, 299, 441, 319, confidence: 1.05),
      ];
      final result = TransactionGrouper.group(
        detections: dets,
        imgWidth: 462,
        imgHeight: 1024,
      );

      expect(result.transactionCandidates.length, equals(2));
      final amounts = result.transactionCandidates.map((c) => c.amountValue).toSet();
      expect(amounts.contains(40), isTrue);
      expect(amounts.contains(349), isTrue);
    });

    test('missing merchant still produces candidate with amount and date', () {
      final dets = [
        _makeDet('6September', '6September', 78, 325, 169, 342, confidence: 0.85),
        _makeDet('349', '349', 399, 299, 441, 319, confidence: 1.05),
      ];
      final result = TransactionGrouper.group(
        detections: dets,
        imgWidth: 462,
        imgHeight: 1024,
      );

      expect(result.transactionCandidates.length, equals(1));
      final cand = result.transactionCandidates.first;
      expect(cand.amountValue, equals(349));
      expect(cand.merchantText, isNull);
      expect(cand.dateText, isNotNull);
    });

    test('status bar time "08:56?" does NOT produce a false transaction candidate', () {
      final dets = [
        _makeDet('08:56?', '08:56?', 30, 18, 119, 36, confidence: 0.69),
        _makeDet('Searchtransactions', 'Searchtransactions', 73, 70, 390, 100, confidence: 0.93),
        _makeDet('ASHISHKUMARNAYAK', 'ASHISHKUMARNAYAK', 78, 218, 320, 240, confidence: 0.88),
        _makeDet('7September', '7September', 78, 247, 168, 267, confidence: 0.91),
        _makeDet('R40', '₹40', 406, 224, 441, 243, confidence: 1.15),
      ];
      final result = TransactionGrouper.group(
        detections: dets,
        imgWidth: 462,
        imgHeight: 1024,
      );

      final amounts = result.transactionCandidates.map((c) => c.amountValue).toList();
      expect(amounts, equals([40]));
      expect(amounts.contains(856), isFalse);
    });

    test('pure date labels produce zero transaction candidates', () {
      final dets = [
        _makeDet('7September', '7September', 78, 247, 168, 267, confidence: 0.91),
        _makeDet('6September', '6September', 78, 325, 169, 342, confidence: 0.85),
        _makeDet('5September', '5September', 79, 401, 169, 418, confidence: 0.84),
      ];
      final result = TransactionGrouper.group(
        detections: dets,
        imgWidth: 462,
        imgHeight: 1024,
      );

      expect(result.transactionCandidates.isEmpty, isTrue);
    });
  });
}
