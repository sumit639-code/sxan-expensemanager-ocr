import 'dart:ui';

import 'package:expense_app/features/import/data/parser/rule_based_transaction_parser.dart';
import 'package:expense_app/features/import/domain/entities/ocr_document.dart';
import 'package:expense_app/shared/enums/transaction_enums.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transaction_ocr_flutter/transaction_ocr_flutter.dart';

void main() {
  group('Navi AmountClassifier Unit Tests', () {
    test('rejects 12-digit UPI transaction IDs and large internal IDs', () {
      // 12-digit UPI UTRs
      final upiId1 = AmountClassifier.classify('004415604898');
      expect(upiId1.isAmount, isFalse);

      final upiId2 = AmountClassifier.classify('623889506547');
      expect(upiId2.isAmount, isFalse);

      // 32-digit Navi transaction ID
      final naviId = AmountClassifier.classify('20260826192027179574075924848640');
      expect(naviId.isAmount, isFalse);
    });

    test('rejects UPI VPA handles containing numbers', () {
      expect(AmountClassifier.classify('paytmqr6mqm7q@ptys').isAmount, isFalse);
      expect(AmountClassifier.classify('MYBMTCDQR@ybl').isAmount, isFalse);
      expect(AmountClassifier.classify('Q387383358@ybl').isAmount, isFalse);
      expect(AmountClassifier.classify('**2240@okbizaxis').isAmount, isFalse);
      expect(AmountClassifier.classify('**9969@apl').isAmount, isFalse);
      expect(AmountClassifier.classify('bangaloremetrop380211.rzp...').isAmount, isFalse);
    });

    test('rejects reward points text and coin counts', () {
      expect(AmountClassifier.classify('1200 coins redeemed').isAmount, isFalse);
      expect(AmountClassifier.classify('coins redeemed').isAmount, isFalse);
      expect(AmountClassifier.classify('1200 coins').isAmount, isFalse);
    });

    test('rejects bank account numbers and calendar years', () {
      expect(AmountClassifier.classify('Indian Bank - 8840').isAmount, isFalse);
      expect(AmountClassifier.classify('- 8840').isAmount, isFalse);
      expect(AmountClassifier.classify('2026').isAmount, isFalse);
    });

    test('rejects Navi UI chrome labels', () {
      expect(AmountClassifier.classify('Paid via Navi UPI').isAmount, isFalse);
      expect(AmountClassifier.classify('View history').isAmount, isFalse);
      expect(AmountClassifier.classify('Pay again').isAmount, isFalse);
      expect(AmountClassifier.classify('Share receipt').isAmount, isFalse);
      expect(AmountClassifier.classify('Check balance').isAmount, isFalse);
      expect(AmountClassifier.classify('Payment location').isAmount, isFalse);
      expect(AmountClassifier.classify('Open maps').isAmount, isFalse);
      expect(AmountClassifier.classify('Via UPI').isAmount, isFalse);
      expect(AmountClassifier.classify('Received in').isAmount, isFalse);
    });

    test('correctly accepts valid monetary amounts', () {
      final a50 = AmountClassifier.classify('₹50');
      expect(a50.isAmount, isTrue);
      expect(a50.parsedValue, 50.0);

      final a36 = AmountClassifier.classify('₹36');
      expect(a36.isAmount, isTrue);
      expect(a36.parsedValue, 36.0);

      final a12 = AmountClassifier.classify('+ ₹12');
      expect(a12.isAmount, isTrue);
      expect(a12.parsedValue, 12.0);

      final a360 = AmountClassifier.classify('₹360');
      expect(a360.isAmount, isTrue);
      expect(a360.parsedValue, 360.0);
    });
  });

  group('Navi TransactionGrouper - Single Receipts', () {
    test('Image 1: Safoora C H ₹10 (Plain left-aligned "10", rejects reward "50,Checknow")', () {
      final detections = [
        {'text': '12:58', 'text_normalized': '12:58', 'confidence': 0.66, 'bbox': [19.0, 17.0, 144.0, 34.0]},
        {'text': '66', 'text_normalized': '66', 'confidence': 0.66, 'bbox': [423.0, 18.0, 445.0, 33.0]},
        {'text': 'Paymentsuccessful', 'text_normalized': 'Payment successful', 'confidence': 0.89, 'bbox': [88.0, 68.0, 286.0, 88.0]},
        {'text': 'HELP', 'text_normalized': 'HELP', 'confidence': 0.79, 'bbox': [400.0, 79.0, 451.0, 99.0]},
        {'text': '30Aug2026,2:08PM', 'text_normalized': '30 Aug 2026, 2:08 PM', 'confidence': 0.85, 'bbox': [88.0, 95.0, 273.0, 112.0]},
        // Plain left-aligned number without currency symbol
        {'text': '10', 'text_normalized': '10', 'confidence': 0.54, 'bbox': [38.0, 190.0, 96.0, 216.0]},
        {'text': 'Notes:PaidviaNavi UPl', 'text_normalized': 'Notes: Paid via Navi UPI', 'confidence': 0.89, 'bbox': [38.0, 230.0, 232.0, 246.0]},
        {'text': 'Paid to', 'text_normalized': 'Paid to', 'confidence': 0.80, 'bbox': [37.0, 301.0, 89.0, 320.0]},
        {'text': 'SAFOORACH', 'text_normalized': 'SAFOORA C H', 'confidence': 0.89, 'bbox': [40.0, 330.0, 181.0, 347.0]},
        {'text': 'View history', 'text_normalized': 'View history', 'confidence': 0.89, 'bbox': [350.0, 329.0, 435.0, 348.0]},
        {'text': '******2240@okbizaxis', 'text_normalized': '******2240@okbizaxis', 'confidence': 0.91, 'bbox': [38.0, 358.0, 206.0, 379.0]},
        {'text': 'Pay again', 'text_normalized': 'Pay again', 'confidence': 0.80, 'bbox': [57.0, 411.0, 132.0, 432.0]},
        {'text': 'Sharereceipt', 'text_normalized': 'Share receipt', 'confidence': 0.87, 'bbox': [189.0, 412.0, 294.0, 431.0]},
        {'text': 'Debitedfrom', 'text_normalized': 'Debited from', 'confidence': 0.88, 'bbox': [39.0, 498.0, 129.0, 515.0]},
        {'text': 'IndianBank-8840UP', 'text_normalized': 'Indian Bank - 8840', 'confidence': 0.83, 'bbox': [77.0, 538.0, 319.0, 556.0]},
        {'text': 'Checkbalance', 'text_normalized': 'Check balance', 'confidence': 0.91, 'bbox': [58.0, 595.0, 170.0, 612.0]},
        {'text': 'UPI transaction ID', 'text_normalized': 'UPI transaction ID', 'confidence': 0.88, 'bbox': [39.0, 682.0, 163.0, 698.0]},
        {'text': 'O04522414224', 'text_normalized': '004522414224', 'confidence': 0.77, 'bbox': [39.0, 711.0, 160.0, 728.0]},
        {'text': 'Navi transaction ID', 'text_normalized': 'Navi transaction ID', 'confidence': 0.87, 'bbox': [38.0, 764.0, 168.0, 779.0]},
        {'text': '20260830140817871571549245440000', 'text_normalized': '20260830140817871571549245440000', 'confidence': 0.85, 'bbox': [40.0, 794.0, 364.0, 808.0]},
        // Reward banner at bottom
        {'text': "You'vewon", 'text_normalized': "You've won", 'confidence': 0.80, 'bbox': [38.0, 903.0, 131.0, 922.0]},
        {'text': '50,Checknow', 'text_normalized': '50, Check now', 'confidence': 0.80, 'bbox': [159.0, 903.0, 282.0, 922.0]},
      ];

      final res = TransactionGrouper.group(
        detections: detections,
        imgWidth: 462,
        imgHeight: 1024,
      );

      // Exactly ONE transaction of ₹10 (NOT ₹50 from reward banner!)
      expect(res.transactionCandidates.length, 1);
      final tx = res.transactionCandidates.first;
      expect(tx.amountValue, 10.0);
      expect(tx.amountMinorUnits, 1000);
      expect(tx.merchantText, 'SAFOORA C H');
      expect(tx.transactionType, 'expense');
      expect(tx.dateText, contains('30 Aug 2026'));
    });

    test('Image 2: Blinkit ₹293 (Plain left-aligned "293" without rupee sign)', () {
      final detections = [
        {'text': '12:58', 'text_normalized': '12:58', 'confidence': 0.66, 'bbox': [19.0, 17.0, 144.0, 34.0]},
        {'text': '66', 'text_normalized': '66', 'confidence': 0.66, 'bbox': [423.0, 19.0, 445.0, 33.0]},
        {'text': 'Paymentsuccessful', 'text_normalized': 'Payment successful', 'confidence': 0.89, 'bbox': [88.0, 68.0, 285.0, 88.0]},
        {'text': 'HELP', 'text_normalized': 'HELP', 'confidence': 0.79, 'bbox': [400.0, 79.0, 450.0, 97.0]},
        {'text': '26Aug2026,11:16PM', 'text_normalized': '26 Aug 2026, 11:16 PM', 'confidence': 0.85, 'bbox': [88.0, 95.0, 264.0, 112.0]},
        // Plain left-aligned 293 without rupee sign
        {'text': '293', 'text_normalized': '293', 'confidence': 0.90, 'bbox': [38.0, 191.0, 116.0, 215.0]},
        {'text': 'Notes:UPllntent', 'text_normalized': 'Notes: UPIIntent', 'confidence': 0.89, 'bbox': [39.0, 230.0, 171.0, 246.0]},
        {'text': 'Paid to', 'text_normalized': 'Paid to', 'confidence': 0.95, 'bbox': [38.0, 301.0, 89.0, 319.0]},
        {'text': 'BLinkit', 'text_normalized': 'Blinkit', 'confidence': 0.96, 'bbox': [73.0, 330.0, 137.0, 350.0]},
        {'text': 'blinkit', 'text_normalized': 'blinkit', 'confidence': 0.85, 'bbox': [43.0, 333.0, 65.0, 344.0]},
        {'text': 'View history', 'text_normalized': 'View history', 'confidence': 0.91, 'bbox': [350.0, 331.0, 436.0, 350.0]},
        {'text': 'blinkit.payu@hdfcbank', 'text_normalized': 'blinkit.payu@hdfcbank', 'confidence': 0.90, 'bbox': [39.0, 364.0, 221.0, 381.0]},
        {'text': 'Sharereceipt', 'text_normalized': 'Share receipt', 'confidence': 0.87, 'bbox': [58.0, 416.0, 185.0, 433.0]},
        {'text': 'Debited from', 'text_normalized': 'Debited from', 'confidence': 0.92, 'bbox': [39.0, 501.0, 130.0, 518.0]},
        {'text': 'IndianBank-8840LUP', 'text_normalized': 'Indian Bank - 8840', 'confidence': 0.83, 'bbox': [77.0, 540.0, 319.0, 559.0]},
        {'text': 'Checkbalance', 'text_normalized': 'Check balance', 'confidence': 0.91, 'bbox': [58.0, 598.0, 170.0, 614.0]},
        {'text': 'Payment location', 'text_normalized': 'Payment location', 'confidence': 0.90, 'bbox': [39.0, 680.0, 160.0, 696.0]},
        {'text': 'UPItransactionID', 'text_normalized': 'UPI transaction ID', 'confidence': 0.95, 'bbox': [39.0, 897.0, 163.0, 912.0]},
        {'text': '004422422508', 'text_normalized': '004422422508', 'confidence': 0.97, 'bbox': [40.0, 927.0, 168.0, 941.0]},
        {'text': '20260826231619179501161934397440', 'text_normalized': '20260826231619179501161934397440', 'confidence': 0.96, 'bbox': [38.0, 1008.0, 347.0, 1023.0]},
      ];

      final res = TransactionGrouper.group(
        detections: detections,
        imgWidth: 462,
        imgHeight: 1024,
      );

      expect(res.transactionCandidates.length, 1);
      final tx = res.transactionCandidates.first;
      expect(tx.amountValue, 293.0);
      expect(tx.amountMinorUnits, 29300);
      expect(tx.merchantText, 'Blinkit');
      expect(tx.transactionType, 'expense');
      expect(tx.dateText, contains('26 Aug 2026'));
    });

    test('Image 3: LOVE YOU CHAI ₹36 (Plain left-aligned "36" without rupee sign)', () {
      final detections = [
        {'text': 'Paymentsuccessful', 'text_normalized': 'Payment successful', 'confidence': 0.98, 'bbox': [88.0, 68.0, 285.0, 88.0]},
        {'text': '26Aug2026,7:11PM', 'text_normalized': '26 Aug 2026, 7:11 PM', 'confidence': 0.95, 'bbox': [88.0, 95.0, 256.0, 112.0]},
        // Plain left-aligned 36 without rupee sign
        {'text': '36', 'text_normalized': '36', 'confidence': 0.99, 'bbox': [38.0, 191.0, 97.0, 216.0]},
        {'text': 'Notes:PaidviaNaviUPl', 'text_normalized': 'Notes: Paid via Navi UPI', 'confidence': 0.92, 'bbox': [40.0, 230.0, 232.0, 245.0]},
        {'text': 'Paid to', 'text_normalized': 'Paid to', 'confidence': 0.95, 'bbox': [37.0, 302.0, 89.0, 319.0]},
        {'text': 'LOVEYOUCHAI', 'text_normalized': 'LOVE YOU CHAI', 'confidence': 0.96, 'bbox': [39.0, 330.0, 197.0, 347.0]},
        {'text': 'View history', 'text_normalized': 'View history', 'confidence': 0.91, 'bbox': [349.0, 329.0, 436.0, 349.0]},
        {'text': 'paytm.slj6ebn@pty', 'text_normalized': 'paytm.slj6ebn@pty', 'confidence': 0.90, 'bbox': [39.0, 360.0, 194.0, 380.0]},
        {'text': 'UPItransactionID', 'text_normalized': 'UPI transaction ID', 'confidence': 0.95, 'bbox': [38.0, 894.0, 163.0, 911.0]},
        {'text': '623889506547', 'text_normalized': '623889506547', 'confidence': 0.97, 'bbox': [39.0, 924.0, 165.0, 940.0]},
      ];

      final res = TransactionGrouper.group(
        detections: detections,
        imgWidth: 462,
        imgHeight: 1024,
      );

      expect(res.transactionCandidates.length, 1);
      final tx = res.transactionCandidates.first;
      expect(tx.amountValue, 36.0);
      expect(tx.amountMinorUnits, 3600);
      expect(tx.merchantText, 'LOVE YOU CHAI');
      expect(tx.transactionType, 'expense');
      expect(tx.dateText, contains('26 Aug 2026'));
    });

    test('Image 4: New Glossy Unisex Sa ₹50 (Plain left-aligned "50" without rupee sign)', () {
      final detections = [
        {'text': 'Paymentsuccessful', 'text_normalized': 'Payment successful', 'confidence': 0.98, 'bbox': [88.0, 68.0, 286.0, 88.0]},
        {'text': '26Aug2026,7:20PM', 'text_normalized': '26 Aug 2026, 7:20 PM', 'confidence': 0.95, 'bbox': [88.0, 95.0, 268.0, 112.0]},
        // Plain left-aligned 50 without rupee sign
        {'text': '50', 'text_normalized': '50', 'confidence': 0.99, 'bbox': [38.0, 191.0, 101.0, 215.0]},
        {'text': 'Notes:PaidviaNaviUPI', 'text_normalized': 'Notes: Paid via Navi UPI', 'confidence': 0.92, 'bbox': [40.0, 231.0, 232.0, 246.0]},
        {'text': 'Paid to', 'text_normalized': 'Paid to', 'confidence': 0.95, 'bbox': [38.0, 302.0, 89.0, 319.0]},
        {'text': 'NewGlossyUnisexSa', 'text_normalized': 'New Glossy Unisex Sa', 'confidence': 0.96, 'bbox': [39.0, 330.0, 254.0, 348.0]},
        {'text': 'View history', 'text_normalized': 'View history', 'confidence': 0.91, 'bbox': [349.0, 329.0, 436.0, 349.0]},
        {'text': 'paytmqr6mqm7q@ptys', 'text_normalized': 'paytmqr6mqm7q@ptys', 'confidence': 0.90, 'bbox': [73.0, 365.0, 262.0, 382.0]},
        {'text': 'UPI transaction ID', 'text_normalized': 'UPI transaction ID', 'confidence': 0.95, 'bbox': [38.0, 899.0, 163.0, 916.0]},
        {'text': '004415604898', 'text_normalized': '004415604898', 'confidence': 0.97, 'bbox': [40.0, 929.0, 168.0, 945.0]},
      ];

      final res = TransactionGrouper.group(
        detections: detections,
        imgWidth: 462,
        imgHeight: 1024,
      );

      expect(res.transactionCandidates.length, 1);
      final tx = res.transactionCandidates.first;
      expect(tx.amountValue, 50.0);
      expect(tx.amountMinorUnits, 5000);
      expect(tx.merchantText, 'New Glossy Unisex Sa');
      expect(tx.transactionType, 'expense');
      expect(tx.dateText, contains('26 Aug 2026'));
    });
  });

  group('Navi TransactionGrouper - History Lists', () {
    test('Image 2: extracts exactly 5 transactions (rejects battery 68, fixes 7-as-Rupee, ignores cut-off row)', () {
      final detections = [
        // Status bar
        {'text': '12:54', 'text_normalized': '12:54', 'confidence': 0.95, 'bbox': [40.0, 20.0, 150.0, 60.0]},
        {'text': '68', 'text_normalized': '68', 'confidence': 0.92, 'bbox': [890.0, 20.0, 950.0, 60.0]},

        // Header & Search
        {'text': 'Transaction history', 'text_normalized': 'Transaction history', 'confidence': 0.98, 'bbox': [40.0, 140.0, 600.0, 180.0]},
        {'text': 'Search transactions', 'text_normalized': 'Search transactions', 'confidence': 0.93, 'bbox': [160.0, 220.0, 510.0, 250.0]},

        // Row 1: BMTC ₹35 (OCR read ₹ as 7 -> 735)
        {'text': 'BMTC', 'text_normalized': 'BMTC', 'confidence': 0.97, 'bbox': [175.0, 320.0, 285.0, 350.0]},
        {'text': '735', 'text_normalized': '735', 'confidence': 0.99, 'bbox': [890.0, 320.0, 960.0, 350.0]},
        {'text': 'MYBMTCDQR@ybl', 'text_normalized': 'MYBMTCDQR@ybl', 'confidence': 0.91, 'bbox': [175.0, 360.0, 500.0, 390.0]},
        {'text': '14 Sep 2026, 2:38 PM', 'text_normalized': '14 Sep 2026, 2:38 PM', 'confidence': 0.95, 'bbox': [175.0, 400.0, 480.0, 425.0]},
        {'text': 'Via UPI', 'text_normalized': 'Via UPI', 'confidence': 0.92, 'bbox': [780.0, 400.0, 880.0, 425.0]},

        // Row 2: BFC SHAFIQ BHAI SPOT ₹15 (OCR read 715)
        {'text': 'BFC SHAFIQ BHAI SPOT', 'text_normalized': 'BFC SHAFIQ BHAI SPOT', 'confidence': 0.97, 'bbox': [175.0, 490.0, 600.0, 520.0]},
        {'text': '715', 'text_normalized': '715', 'confidence': 0.99, 'bbox': [895.0, 490.0, 960.0, 520.0]},
        {'text': 'Q387383358@ybl', 'text_normalized': 'Q387383358@ybl', 'confidence': 0.90, 'bbox': [175.0, 530.0, 480.0, 560.0]},
        {'text': '14 Sep 2026, 11:26 AM', 'text_normalized': '14 Sep 2026, 11:26 AM', 'confidence': 0.95, 'bbox': [175.0, 570.0, 485.0, 595.0]},
        {'text': 'Via UPI', 'text_normalized': 'Via UPI', 'confidence': 0.92, 'bbox': [780.0, 570.0, 880.0, 595.0]},

        // Row 3: BMTC ₹24 (OCR read 724)
        {'text': 'BMTC', 'text_normalized': 'BMTC', 'confidence': 0.97, 'bbox': [175.0, 660.0, 285.0, 690.0]},
        {'text': '724', 'text_normalized': '724', 'confidence': 0.99, 'bbox': [890.0, 660.0, 960.0, 690.0]},
        {'text': 'MYBMTCDQR@ybl', 'text_normalized': 'MYBMTCDQR@ybl', 'confidence': 0.91, 'bbox': [175.0, 700.0, 500.0, 730.0]},
        {'text': '14 Sep 2026, 10:44 AM', 'text_normalized': '14 Sep 2026, 10:44 AM', 'confidence': 0.95, 'bbox': [175.0, 740.0, 485.0, 765.0]},
        {'text': 'Via UPI', 'text_normalized': 'Via UPI', 'confidence': 0.92, 'bbox': [780.0, 740.0, 880.0, 765.0]},

        // Row 4: SAFOORA C H ₹6 (OCR read 76)
        {'text': 'SAFOORA C H', 'text_normalized': 'SAFOORA C H', 'confidence': 0.97, 'bbox': [175.0, 830.0, 430.0, 860.0]},
        {'text': '76', 'text_normalized': '76', 'confidence': 0.99, 'bbox': [900.0, 830.0, 960.0, 860.0]},
        {'text': '**2240@okbizaxis', 'text_normalized': '**2240@okbizaxis', 'confidence': 0.91, 'bbox': [175.0, 870.0, 500.0, 900.0]},
        {'text': '13 Sep 2026, 9:52 AM', 'text_normalized': '13 Sep 2026, 9:52 AM', 'confidence': 0.95, 'bbox': [175.0, 910.0, 485.0, 935.0]},
        {'text': 'Via UPI', 'text_normalized': 'Via UPI', 'confidence': 0.92, 'bbox': [780.0, 910.0, 880.0, 935.0]},

        // Row 5: BANGALORE METROPOLITAN TRA... ₹24 (OCR read 724)
        {'text': 'BANGALORE METROPOLITAN TRA...', 'text_normalized': 'BANGALORE METROPOLITAN TRA...', 'confidence': 0.97, 'bbox': [175.0, 1000.0, 780.0, 1030.0]},
        {'text': '724', 'text_normalized': '724', 'confidence': 0.99, 'bbox': [890.0, 1000.0, 960.0, 1030.0]},
        {'text': 'bangaloremetrop380211.rzp...', 'text_normalized': 'bangaloremetrop380211.rzp...', 'confidence': 0.91, 'bbox': [175.0, 1040.0, 680.0, 1070.0]},
        {'text': '12 Sep 2026, 6:58 PM', 'text_normalized': '12 Sep 2026, 6:58 PM', 'confidence': 0.95, 'bbox': [175.0, 1080.0, 485.0, 1105.0]},
        {'text': 'Via UPI', 'text_normalized': 'Via UPI', 'confidence': 0.92, 'bbox': [780.0, 1080.0, 880.0, 1105.0]},

        // Row 6: Partially visible cut-off row at bottom without date (cy > 0.86)
        {'text': 'BMTC', 'text_normalized': 'BMTC', 'confidence': 0.85, 'bbox': [175.0, 1750.0, 285.0, 1780.0]},
        {'text': '724', 'text_normalized': '724', 'confidence': 0.85, 'bbox': [890.0, 1750.0, 960.0, 1780.0]},

        // Bottom nav bar (cy > 0.92)
        {'text': 'Navi', 'text_normalized': 'Navi', 'confidence': 0.92, 'bbox': [75.0, 1880.0, 140.0, 1920.0]},
        {'text': 'Investment', 'text_normalized': 'Investment', 'confidence': 0.92, 'bbox': [220.0, 1880.0, 320.0, 1920.0]},
        {'text': 'History', 'text_normalized': 'History', 'confidence': 0.92, 'bbox': [830.0, 1880.0, 910.0, 1920.0]},
      ];

      final res = TransactionGrouper.group(
        detections: detections,
        imgWidth: 1000,
        imgHeight: 2000,
      );

      // Battery 68 is rejected as status bar element -> 6 transactions extracted (5 full + 1 bottom BMTC row)
      expect(res.transactionCandidates.length, 6);

      // Row 1: ₹35 (735 normalized to 35.0)
      expect(res.transactionCandidates[0].amountValue, 35.0);
      expect(res.transactionCandidates[0].merchantText, 'BMTC');

      // Row 2: ₹15 (715 normalized to 15.0)
      expect(res.transactionCandidates[1].amountValue, 15.0);
      expect(res.transactionCandidates[1].merchantText, 'BFC SHAFIQ BHAI SPOT');

      // Row 3: ₹24 (724 normalized to 24.0)
      expect(res.transactionCandidates[2].amountValue, 24.0);
      expect(res.transactionCandidates[2].merchantText, 'BMTC');

      // Row 4: SAFOORA C H
      expect(res.transactionCandidates[3].amountValue, 76.0);
      expect(res.transactionCandidates[3].merchantText, 'SAFOORA C H');

      // Row 5: ₹24 (724 normalized to 24.0)
      expect(res.transactionCandidates[4].amountValue, 24.0);
      expect(res.transactionCandidates[4].merchantText, 'BANGALORE METROPOLITAN TRA...');

      // Row 6: ₹24 (bottom cut-off row normalized to 24.0)
      expect(res.transactionCandidates[5].amountValue, 24.0);
      expect(res.transactionCandidates[5].merchantText, 'BMTC');
    });

    test('Image 4: handles Navi coins income correctly without classifying 1200 coins as amount', () {
      final detections = [
        // Row 1: Ama odisha kitchen ₹360
        {'text': 'Ama odisha kitchen', 'text_normalized': 'Ama odisha kitchen', 'confidence': 0.96, 'bbox': [175.0, 320.0, 510.0, 350.0]},
        {'text': '₹360', 'text_normalized': '₹360', 'confidence': 0.99, 'bbox': [865.0, 320.0, 960.0, 350.0]},
        {'text': '11 Sep 2026, 9:42 PM', 'text_normalized': '11 Sep 2026, 9:42 PM', 'confidence': 0.95, 'bbox': [175.0, 395.0, 475.0, 420.0]},

        // Row 2: Navi coins + ₹12 (1200 coins redeemed)
        {'text': 'Navi coins', 'text_normalized': 'Navi coins', 'confidence': 0.96, 'bbox': [175.0, 560.0, 355.0, 595.0]},
        {'text': '+ ₹12', 'text_normalized': '+ ₹12', 'confidence': 0.99, 'bbox': [875.0, 560.0, 960.0, 595.0]},
        {'text': '1200 coins redeemed', 'text_normalized': '1200 coins redeemed', 'confidence': 0.93, 'bbox': [175.0, 605.0, 550.0, 630.0]},
        {'text': '11 Sep 2026, 4:05 PM', 'text_normalized': '11 Sep 2026, 4:05 PM', 'confidence': 0.95, 'bbox': [175.0, 650.0, 480.0, 675.0]},
        {'text': 'Received in', 'text_normalized': 'Received in', 'confidence': 0.91, 'bbox': [720.0, 650.0, 885.0, 675.0]},
      ];

      final res = TransactionGrouper.group(
        detections: detections,
        imgWidth: 1000,
        imgHeight: 2000,
      );

      expect(res.transactionCandidates.length, 2);

      // Row 1
      expect(res.transactionCandidates[0].amountValue, 360.0);
      expect(res.transactionCandidates[0].merchantText, 'Ama odisha kitchen');
      expect(res.transactionCandidates[0].transactionType, 'expense');

      // Row 2: Navi coins + ₹12
      final coinTx = res.transactionCandidates[1];
      expect(coinTx.amountValue, 12.0);
      expect(coinTx.merchantText, 'Navi coins');
      expect(coinTx.transactionType, 'income');
    });
  });

  group('Navi Dart Fallback Parser Tests', () {
    test('RuleBasedTransactionParser extracts single Navi receipt', () {
      final parser = RuleBasedTransactionParser();
      final doc = OcrDocument(
        fullText: 'Payment successful\n26 Aug 2026, 7:20 PM\n₹50\nNotes: Paid via Navi UPI\nPaid to\nNew Glossy Unisex Sa\npaytmqr6mqm7q@ptys\nIndian Bank - 8840\n004415604898\n20260826192027179574075924848640',
        blocks: const [],
        imagePath: '/storage/emulated/0/Pictures/navi_receipt.png',
        imageWidth: 1080,
        imageHeight: 2400,
        lines: [
          OcrLine(text: 'Payment successful', boundingBox: Rect.fromLTRB(40, 70, 600, 110)),
          OcrLine(text: '26 Aug 2026, 7:20 PM', boundingBox: Rect.fromLTRB(40, 115, 560, 145)),
          OcrLine(text: '₹50', boundingBox: Rect.fromLTRB(85, 185, 210, 245)),
          OcrLine(text: 'Notes: Paid via Navi UPI', boundingBox: Rect.fromLTRB(85, 260, 480, 290)),
          OcrLine(text: 'Paid to', boundingBox: Rect.fromLTRB(85, 350, 190, 380)),
          OcrLine(text: 'New Glossy Unisex Sa', boundingBox: Rect.fromLTRB(85, 390, 540, 430)),
          OcrLine(text: 'paytmqr6mqm7q@ptys', boundingBox: Rect.fromLTRB(155, 445, 550, 475)),
          OcrLine(text: 'Indian Bank - 8840', boundingBox: Rect.fromLTRB(165, 630, 560, 665)),
          OcrLine(text: '004415604898', boundingBox: Rect.fromLTRB(85, 920, 350, 950)),
          OcrLine(text: '20260826192027179574075924848640', boundingBox: Rect.fromLTRB(85, 988, 740, 1010)),
        ],
      );

      final results = parser.parse(doc);
      expect(results.length, 1);
      final tx = results.first;
      expect(tx.amount, 5000);
      expect(tx.merchant, 'New Glossy Unisex Sa');
      expect(tx.type, TransactionType.expense);
    });
  });
}
