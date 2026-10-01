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

    test('PhonePe history item with "Paid to Zomato" and relative date extracted correctly', () {
      final dets = [
        _makeDet('Paid to Zomato', 'Paid to Zomato', 78, 200, 300, 220, confidence: 0.95),
        _makeDet('8 hours ago', '8 hours ago', 78, 225, 180, 240, confidence: 0.90),
        _makeDet('R350', '₹350', 380, 200, 440, 220, confidence: 1.0),
        _makeDet('Debited from HDFC Bank', 'Debited from HDFC Bank', 78, 245, 320, 260, confidence: 0.88),
      ];
      final result = TransactionGrouper.group(
        detections: dets,
        imgWidth: 462,
        imgHeight: 1024,
      );

      expect(result.transactionCandidates.length, equals(1));
      final cand = result.transactionCandidates.first;
      expect(cand.amountValue, equals(350));
      expect(cand.merchantText, equals('Zomato'));
      expect(cand.dateText, equals('8 hours ago'));
    });

    test('Single payment receipt view with top merchant name extracted correctly', () {
      final dets = [
        _makeDet('PhonePe', 'PhonePe', 180, 30, 280, 50, confidence: 0.95),
        _makeDet('Paid to Swiggy', 'Paid to Swiggy', 140, 100, 320, 130, confidence: 0.95),
        _makeDet('R500', '₹500', 160, 200, 300, 240, confidence: 1.1),
        _makeDet('Transaction Successful', 'Transaction Successful', 120, 250, 340, 270, confidence: 0.92),
        _makeDet('15 Sep 2026 at 4:30 PM', '15 Sep 2026 at 4:30 PM', 100, 300, 360, 320, confidence: 0.90),
      ];
      final result = TransactionGrouper.group(
        detections: dets,
        imgWidth: 462,
        imgHeight: 1024,
      );

      expect(result.transactionCandidates.length, equals(1));
      final cand = result.transactionCandidates.first;
      expect(cand.amountValue, equals(500));
      expect(cand.merchantText, equals('Swiggy'));
    });

    test('User Screenshot 1: GPay Single Receipt (To DIPALI BAL ₹40 Completed)', () {
      final dets = [
        _makeDet('To DIPALI BAL', 'To DIPALI BAL', 150, 150, 330, 180, confidence: 0.96),
        _makeDet('₹40', '₹40', 180, 200, 300, 250, confidence: 1.1),
        _makeDet('Pay again', 'Pay again', 170, 280, 310, 320, confidence: 0.95),
        _makeDet('Completed', 'Completed', 180, 350, 300, 370, confidence: 0.94),
        _makeDet('14 Sept 2026, 7:53 pm', '14 Sept 2026, 7:53 pm', 140, 400, 340, 420, confidence: 0.92),
        _makeDet('HDFC Bank 2711', 'HDFC Bank 2711', 100, 460, 250, 480, confidence: 0.90),
        _makeDet('UPI transaction ID', 'UPI transaction ID', 50, 520, 220, 540, confidence: 0.91),
        _makeDet('129613467802', '129613467802', 50, 550, 180, 570, confidence: 0.89),
      ];
      final result = TransactionGrouper.group(
        detections: dets,
        imgWidth: 480,
        imgHeight: 1050,
      );

      expect(result.transactionCandidates.length, equals(1));
      final cand = result.transactionCandidates.first;
      expect(cand.amountValue, equals(40));
      expect(cand.merchantText, equals('DIPALI BAL'));
      expect(cand.transactionType, equals('expense'));
    });

    test('User Screenshot 2: PhonePe History list with 7 transactions extracted cleanly', () {
      // 7 transactions: Subashish Cst, ICCL, PARIKSIT, Baba, Reliance Jio, Baba, Baba
      final dets = [
        _makeDet('History', 'History', 20, 80, 120, 110, confidence: 0.95),
        _makeDet('Search', 'Search', 80, 130, 200, 160, confidence: 0.92),
        // Item 1: Subashish Cst (+ ₹2,500)
        _makeDet('Received from', 'Received from', 100, 220, 220, 240, confidence: 0.95),
        _makeDet('Subashish Cst', 'Subashish Cst', 100, 245, 250, 270, confidence: 0.94),
        _makeDet('+ ₹2,500', '+ ₹2,500', 380, 235, 470, 265, confidence: 1.05),
        _makeDet('13 Sept', '13 Sept', 100, 275, 170, 295, confidence: 0.91),
        _makeDet('Credited to', 'Credited to', 370, 275, 450, 295, confidence: 0.88),

        // Item 2: ICCL Mutual Funds Autopay (₹1,500)
        _makeDet('Payment to', 'Payment to', 100, 330, 200, 350, confidence: 0.95),
        _makeDet('ICCL Mutual Funds Autopay', 'ICCL Mutual Funds Autopay', 100, 355, 340, 380, confidence: 0.93),
        _makeDet('₹1,500', '₹1,500', 390, 345, 470, 375, confidence: 1.05),
        _makeDet('08 Sept', '08 Sept', 100, 385, 170, 405, confidence: 0.90),
        _makeDet('Debited from', 'Debited from', 360, 385, 450, 405, confidence: 0.87),

        // Item 3: PARIKSIT INCORPORATION INDIA (+ ₹8,000)
        _makeDet('Received from', 'Received from', 100, 440, 220, 460, confidence: 0.95),
        _makeDet('PARIKSIT INCORPORATION INDIA ...', 'PARIKSIT INCORPORATION INDIA ...', 100, 465, 360, 490, confidence: 0.94),
        _makeDet('+ ₹8,000', '+ ₹8,000', 380, 455, 470, 485, confidence: 1.05),
        _makeDet('07 Sept', '07 Sept', 100, 495, 170, 515, confidence: 0.90),
        _makeDet('Credited to', 'Credited to', 370, 495, 450, 515, confidence: 0.88),

        // Item 4: Baba (+ ₹1)
        _makeDet('Received from', 'Received from', 100, 550, 220, 570, confidence: 0.95),
        _makeDet('Baba', 'Baba', 100, 575, 160, 600, confidence: 0.96),
        _makeDet('+ ₹1', '+ ₹1', 420, 565, 470, 595, confidence: 1.0),
        _makeDet('07 Sept', '07 Sept', 100, 605, 170, 625, confidence: 0.90),
        _makeDet('Credited to', 'Credited to', 370, 605, 450, 625, confidence: 0.88),

        // Item 5: RELIANCE JIO INFOCOMM (₹349)
        _makeDet('Paid to', 'Paid to', 100, 660, 180, 680, confidence: 0.95),
        _makeDet('RELIANCE JIO INFOCOMM', 'RELIANCE JIO INFOCOMM', 100, 685, 320, 710, confidence: 0.94),
        _makeDet('₹349', '₹349', 410, 675, 470, 705, confidence: 1.05),
        _makeDet('04 Sept', '04 Sept', 100, 715, 170, 735, confidence: 0.90),
        _makeDet('Debited from', 'Debited from', 360, 715, 450, 735, confidence: 0.87),

        // Item 6: Baba (₹1)
        _makeDet('Paid to', 'Paid to', 100, 770, 180, 790, confidence: 0.95),
        _makeDet('Baba', 'Baba', 100, 795, 160, 820, confidence: 0.96),
        _makeDet('₹1', '₹1', 430, 785, 470, 815, confidence: 1.0),
        _makeDet('02 Sept', '02 Sept', 100, 825, 170, 845, confidence: 0.90),
        _makeDet('Debited from', 'Debited from', 360, 825, 450, 845, confidence: 0.87),

        // Item 7: Baba (₹1)
        _makeDet('Paid to', 'Paid to', 100, 880, 180, 900, confidence: 0.95),
        _makeDet('Baba', 'Baba', 100, 905, 160, 930, confidence: 0.96),
        _makeDet('₹1', '₹1', 430, 895, 470, 925, confidence: 1.0),
      ];

      final result = TransactionGrouper.group(
        detections: dets,
        imgWidth: 480,
        imgHeight: 1050,
      );

      expect(result.transactionCandidates.length, equals(7));
      final amounts = result.transactionCandidates.map((c) => c.amountValue).toList();
      expect(amounts, equals([2500, 1500, 8000, 1, 349, 1, 1]));

      // Verify income vs expense direction
      expect(result.transactionCandidates[0].transactionType, equals('income')); // + ₹2,500
      expect(result.transactionCandidates[1].transactionType, equals('expense')); // ₹1,500
      expect(result.transactionCandidates[2].transactionType, equals('income')); // + ₹8,000
      expect(result.transactionCandidates[3].transactionType, equals('income')); // + ₹1
      expect(result.transactionCandidates[4].transactionType, equals('expense')); // ₹349
      expect(result.transactionCandidates[5].transactionType, equals('expense')); // ₹1
      expect(result.transactionCandidates[6].transactionType, equals('expense')); // ₹1

      // Verify merchants
      expect(result.transactionCandidates[0].merchantText, contains('Subashish Cst'));
      expect(result.transactionCandidates[1].merchantText, contains('ICCL Mutual Funds Autopay'));
      expect(result.transactionCandidates[2].merchantText, contains('PARIKSIT INCORPORATION INDIA'));
      expect(result.transactionCandidates[4].merchantText, contains('RELIANCE JIO INFOCOMM'));
    });

    test('User Screenshot 3: PhonePe Single Receipt (Paid to Shiva ₹70 with debit footer ignored)', () {
      final dets = [
        _makeDet('Transaction Successful', 'Transaction Successful', 80, 60, 320, 85, confidence: 0.96),
        _makeDet('07:13 pm on 14 Aug 2026', '07:13 pm on 14 Aug 2026', 80, 90, 270, 110, confidence: 0.94),
        _makeDet('Paid to', 'Paid to', 30, 140, 100, 160, confidence: 0.95),
        _makeDet('Shiva', 'Shiva', 90, 170, 160, 195, confidence: 0.96),
        _makeDet('₹70', '₹70', 410, 170, 460, 200, confidence: 1.1),
        _makeDet('Banking Name: Shivananda Behera', 'Banking Name: Shivananda Behera', 30, 240, 280, 260, confidence: 0.91),
        _makeDet('Transfer Details', 'Transfer Details', 70, 290, 200, 315, confidence: 0.93),
        _makeDet('PhonePe Transaction ID', 'PhonePe Transaction ID', 30, 325, 200, 345, confidence: 0.92),
        _makeDet('Debited from', 'Debited from', 30, 380, 140, 400, confidence: 0.90),
        _makeDet('sumit639', 'sumit639', 90, 405, 180, 425, confidence: 0.90),
        _makeDet('₹70', '₹70', 410, 405, 460, 425, confidence: 0.85),
      ];

      final result = TransactionGrouper.group(
        detections: dets,
        imgWidth: 480,
        imgHeight: 1050,
      );

      // Ensures the debit footer ₹70 is NOT treated as a 2nd transaction!
      expect(result.transactionCandidates.length, equals(1));
      final cand = result.transactionCandidates.first;
      expect(cand.amountValue, equals(70));
      expect(cand.merchantText, equals('Shiva'));
      expect(cand.transactionType, equals('expense'));
      expect(cand.dateText, contains('14 Aug 2026'));
    });

    test('Real Device Run: 45 Raw OCR Items from PhonePe History (scaled_1000102956.png)', () {
      final dets = [
        _makeDet('· @园l 5G+ 1 64', '· @园l 5G+ 1 64', 595, 40, 1004, 86, confidence: 0.633),
        _makeDet('09:05金', '09:05金', 68, 39, 287, 91, confidence: 0.934),
        _makeDet('0', '0', 984, 161, 1052, 223, confidence: 0.804),
        _makeDet('History', 'History', 28, 163, 181, 227, confidence: 0.901),
        _makeDet(' Search', 'Search', 158, 315, 304, 371, confidence: 0.920),
        _makeDet('0', '0', 78, 319, 134, 370, confidence: 0.593),
        _makeDet('Received from', 'Received from', 181, 525, 389, 570, confidence: 0.911),
        _makeDet('『', '『', 72, 560, 127, 606, confidence: 0.676),
        _makeDet('+#2,500', '+#2,500', 854, 566, 1032, 617, confidence: 0.927),
        _makeDet('Subashish Cst', 'Subashish Cst', 181, 571, 447, 616, confidence: 0.950),
        _makeDet('Credited to 0', 'Credited to 0', 822, 629, 1027, 674, confidence: 0.931),
        _makeDet('13 Sept', '13 Sept', 181, 629, 292, 677, confidence: 0.957),
        _makeDet('Payment to', 'Payment to', 182, 783, 345, 826, confidence: 0.985),
        _makeDet('1,500', '1,500', 896, 823, 1035, 873, confidence: 0.938),
        _makeDet('ICCL Mutual Funds Autopay', 'ICCL Mutual Funds Autopay', 175, 819, 709, 881, confidence: 0.982),
        _makeDet('Debited from 0', 'Debited from 0', 795, 886, 1027, 931, confidence: 0.863),
        _makeDet('08 Sept', '08 Sept', 177, 886, 302, 934, confidence: 0.976),
        _makeDet('Received from', 'Received from', 183, 1041, 384, 1078, confidence: 0.945),
        _makeDet('PARIKSIT INCORPORATION INDIA... + 8,000', 'PARIKSIT INCORPORATION INDIA... + 8,000', 180, 1080, 1028, 1127, confidence: 0.881),
        _makeDet('07 Sept', '07 Sept', 177, 1139, 302, 1188, confidence: 0.987),
        _makeDet('Credited to o', 'Credited to o', 820, 1138, 1029, 1189, confidence: 0.939),
        _makeDet('Received from', 'Received from', 181, 1292, 389, 1337, confidence: 0.913),
        _makeDet('+1', '+1', 947, 1331, 1038, 1383, confidence: 0.895),
        _makeDet('Baba', 'Baba', 179, 1333, 293, 1387, confidence: 1.000),
        _makeDet('Credited to 0', 'Credited to 0', 822, 1396, 1030, 1441, confidence: 0.913),
        _makeDet('07 Sept', '07 Sept', 177, 1396, 302, 1445, confidence: 0.992),
        _makeDet('Paid to', 'Paid to', 181, 1546, 288, 1594, confidence: 0.964),
        _makeDet('RELIANCE JIO INFOCOMM', 'RELIANCE JIO INFOCOMM', 184, 1591, 667, 1637, confidence: 0.995),
        _makeDet('349', '349', 922, 1587, 1032, 1641, confidence: 0.999),
        _makeDet('Debited from α', 'Debited from α', 798, 1655, 1025, 1692, confidence: 0.946),
        _makeDet('04 Sept', '04 Sept', 179, 1654, 304, 1697, confidence: 0.994),
        _makeDet('Paid to', 'Paid to', 183, 1801, 290, 1842, confidence: 0.924),
        _makeDet('1', '1', 980, 1844, 1035, 1890, confidence: 0.754),
        _makeDet('Baba', 'Baba', 181, 1845, 288, 1893, confidence: 0.880),
        _makeDet('Debited from 0', 'Debited from 0', 795, 1907, 1027, 1951, confidence: 0.949),
        _makeDet('02 Sept', '02 Sept', 177, 1906, 302, 1955, confidence: 0.896),
        _makeDet('Paid to', 'Paid to', 181, 2056, 288, 2104, confidence: 0.899),
        _makeDet('1', '1', 979, 2097, 1035, 2148, confidence: 0.918),
        _makeDet('Baba', 'Baba', 180, 2097, 290, 2151, confidence: 0.984),
        _makeDet('D', 'D', 728, 2196, 787, 2256, confidence: 0.773),
        _makeDet('0', '0', 940, 2196, 1004, 2257, confidence: 0.893),
        _makeDet('Search', 'Search', 265, 2261, 383, 2309, confidence: 0.972),
        _makeDet('Alerts', 'Alerts', 708, 2261, 804, 2308, confidence: 0.915),
        _makeDet('Home', 'Home', 58, 2266, 158, 2307, confidence: 1.000),
        _makeDet('History', 'History', 911, 2259, 1033, 2314, confidence: 0.998),
      ];

      final result = TransactionGrouper.group(
        detections: dets,
        imgWidth: 1080,
        imgHeight: 2392,
      );

      // Exactly 7 transactions!
      expect(result.transactionCandidates.length, equals(7));

      final amounts = result.transactionCandidates.map((c) => c.amountValue).toList();
      expect(amounts, equals([2500, 1500, 8000, 1, 349, 1, 1]));

      // Check all 7 merchants
      expect(result.transactionCandidates[0].merchantText, equals('Subashish Cst'));
      expect(result.transactionCandidates[1].merchantText, equals('ICCL Mutual Funds Autopay'));
      expect(result.transactionCandidates[2].merchantText, contains('PARIKSIT INCORPORATION INDIA'));
      expect(result.transactionCandidates[3].merchantText, equals('Baba'));
      expect(result.transactionCandidates[4].merchantText, equals('RELIANCE JIO INFOCOMM'));
      expect(result.transactionCandidates[5].merchantText, equals('Baba'));
      expect(result.transactionCandidates[6].merchantText, equals('Baba'));

      // Check income vs expense
      expect(result.transactionCandidates[0].transactionType, equals('income'));
      expect(result.transactionCandidates[1].transactionType, equals('expense'));
      expect(result.transactionCandidates[2].transactionType, equals('income'));
      expect(result.transactionCandidates[3].transactionType, equals('income'));
      expect(result.transactionCandidates[4].transactionType, equals('expense'));
      expect(result.transactionCandidates[5].transactionType, equals('expense'));
      expect(result.transactionCandidates[6].transactionType, equals('expense'));
    });
  });
}
