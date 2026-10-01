import 'package:flutter_test/flutter_test.dart';
import 'package:transaction_ocr_flutter/transaction_ocr_flutter.dart';

OcrItem _createItem({
  required int readingIndex,
  required String text,
  String? textNorm,
  required double x1,
  required double y1,
  required double x2,
  required double y2,
  double confidence = 0.95,
}) {
  return OcrItem(
    readingIndex: readingIndex,
    text: text,
    textNormalized: textNorm ?? text,
    compositeScore: confidence,
    confidence: confidence,
    bbox: BoundingBox.fromRect(x1, y1, x2, y2),
  );
}

void main() {
  group('Universal Financial Amount Morphology & Decimal Preservation', () {
    test('Exact decimal preservation for ₹200.90 -> 20090 paise', () {
      final cls = AmountClassifier.classify('₹200.90');
      expect(cls.isAmount, isTrue);
      expect(cls.parsedValue, equals(200.90));
      expect(cls.parsedMinorUnits, equals(20090));
    });

    test('Exact decimal preservation for ₹3,700.97 -> 370097 paise', () {
      final cls = AmountClassifier.classify('₹3,700.97');
      expect(cls.isAmount, isTrue);
      expect(cls.parsedValue, equals(3700.97));
      expect(cls.parsedMinorUnits, equals(370097));
    });

    test('Financial amounts: ₹20, ₹205, ₹2,200, ₹5,000, ₹75,000', () {
      final amounts = {
        '₹20': 2000,
        '₹205': 20500,
        '₹2,200': 220000,
        '₹5,000': 500000,
        '₹75,000': 7500000,
      };

      for (final entry in amounts.entries) {
        final cls = AmountClassifier.classify(entry.key);
        expect(cls.isAmount, isTrue, reason: 'Failed for ${entry.key}');
        expect(cls.parsedMinorUnits, equals(entry.value),
            reason: 'Minor units mismatch for ${entry.key}');
      }
    });

    test('Critical financial safety: never turn ₹5,000 into ₹75,000', () {
      final cls5000 = AmountClassifier.classify('₹5,000');
      expect(cls5000.parsedMinorUnits, equals(500000));
      expect(cls5000.parsedMinorUnits, isNot(equals(7500000)));

      final cls75000 = AmountClassifier.classify('₹75,000');
      expect(cls75000.parsedMinorUnits, equals(7500000));
      expect(cls75000.parsedMinorUnits, isNot(equals(500000)));
    });

    test('Disambiguation: UTR, Phone numbers, Times, and Dates must NOT be amounts', () {
      expect(AmountClassifier.classify('123456789012').isAmount, isFalse, reason: '12-digit UTR');
      expect(AmountClassifier.classify('9876543210').isAmount, isFalse, reason: '10-digit Phone');
      expect(AmountClassifier.classify('16:48').isAmount, isFalse, reason: 'Time 16:48');
      expect(AmountClassifier.classify('14:22:05').isAmount, isFalse, reason: 'Time 14:22:05');
      expect(AmountClassifier.classify('4 September').isAmount, isFalse, reason: 'Date 4 September');
      expect(AmountClassifier.classify('1Aug').isAmount, isFalse, reason: 'Compact date 1Aug');
      expect(AmountClassifier.classify('18Sep2026').isAmount, isFalse, reason: 'Date 18Sep2026');
      expect(AmountClassifier.classify('1200 coins redeemed').isAmount, isFalse, reason: 'Coin count');
    });
  });

  group('20 Generic Layout Scenarios via SpatialLayoutEngine', () {
    // 1. GPay-style history (Merchant on left, Amount on right, Date below merchant)
    test('1. GPay-style history', () {
      final items = [
        _createItem(readingIndex: 1, text: 'Zomato', x1: 50, y1: 100, x2: 200, y2: 130),
        _createItem(readingIndex: 2, text: '₹349', x1: 700, y1: 100, x2: 800, y2: 130),
        _createItem(readingIndex: 3, text: '18 Sep', x1: 50, y1: 140, x2: 150, y2: 165),

        _createItem(readingIndex: 4, text: 'Swiggy Instamart', x1: 50, y1: 250, x2: 300, y2: 280),
        _createItem(readingIndex: 5, text: '₹520', x1: 700, y1: 250, x2: 800, y2: 280),
        _createItem(readingIndex: 6, text: '17 Sep', x1: 50, y1: 290, x2: 150, y2: 315),
      ];

      final res = SpatialLayoutEngine.process(items: items, imgWidth: 900, imgHeight: 1600);
      expect(res.layoutType, DocumentLayoutType.historyFeed);
      expect(res.transactions.length, 2);
      expect(res.transactions[0].merchantText, 'Zomato');
      expect(res.transactions[0].amountMinorUnits, 34900);
      expect(res.transactions[1].merchantText, 'Swiggy Instamart');
      expect(res.transactions[1].amountMinorUnits, 52000);
    });

    // 2. PhonePe-style history ("Paid to [Merchant]", Amount on right, Date below)
    test('2. PhonePe-style history', () {
      final items = [
        _createItem(readingIndex: 1, text: 'Paid to Rahul Sharma', x1: 60, y1: 120, x2: 350, y2: 150),
        _createItem(readingIndex: 2, text: '₹500', x1: 750, y1: 120, x2: 850, y2: 150),
        _createItem(readingIndex: 3, text: '18 Sep 2026', x1: 60, y1: 160, x2: 200, y2: 185),
      ];

      final res = SpatialLayoutEngine.process(items: items, imgWidth: 900, imgHeight: 1600);
      expect(res.transactions.length, 1);
      expect(res.transactions[0].merchantText, 'Rahul Sharma');
      expect(res.transactions[0].amountMinorUnits, 50000);
      expect(res.transactions[0].transactionType, 'expense');
    });

    // 3. Navi-style receipt (Left-aligned plain amount without rupee symbol)
    test('3. Navi-style receipt', () {
      final items = [
        _createItem(readingIndex: 1, text: 'Payment successful', x1: 50, y1: 100, x2: 300, y2: 130),
        _createItem(readingIndex: 2, text: '293', x1: 50, y1: 160, x2: 180, y2: 220),
        _createItem(readingIndex: 3, text: 'Paid to Blinkit', x1: 50, y1: 240, x2: 250, y2: 270),
        _createItem(readingIndex: 4, text: '18 Sep 2026, 2:30 PM', x1: 50, y1: 300, x2: 350, y2: 330),
        _createItem(readingIndex: 5, text: 'UPI Transaction ID: 123456789012', x1: 50, y1: 450, x2: 450, y2: 480),
      ];

      final res = SpatialLayoutEngine.process(items: items, imgWidth: 900, imgHeight: 1600);
      expect(res.layoutType, DocumentLayoutType.singleReceipt);
      expect(res.transactions.length, 1);
      expect(res.transactions[0].merchantText, 'Blinkit');
      expect(res.transactions[0].amountMinorUnits, 29300);
    });

    // 4. Left-aligned amount in general layout
    test('4. Left-aligned amount', () {
      final items = [
        _createItem(readingIndex: 1, text: '₹1,500', x1: 50, y1: 100, x2: 180, y2: 140),
        _createItem(readingIndex: 2, text: 'Cafe 47', x1: 220, y1: 100, x2: 380, y2: 140),
        _createItem(readingIndex: 3, text: 'Today, 10:42 AM', x1: 50, y1: 160, x2: 250, y2: 190),
      ];

      final res = SpatialLayoutEngine.process(items: items, imgWidth: 900, imgHeight: 1600);
      expect(res.transactions.length, 1);
      expect(res.transactions[0].amountMinorUnits, 150000);
      expect(res.transactions[0].merchantText, 'Cafe 47');
    });

    // 5. Centered amount inside card
    test('5. Centered amount', () {
      final items = [
        _createItem(readingIndex: 1, text: 'Paid successfully', x1: 300, y1: 100, x2: 600, y2: 140),
        _createItem(readingIndex: 2, text: '₹2,200', x1: 350, y1: 170, x2: 550, y2: 230),
        _createItem(readingIndex: 3, text: 'Starbucks Coffee', x1: 320, y1: 260, x2: 580, y2: 300),
        _createItem(readingIndex: 4, text: '18 September 2026', x1: 340, y1: 320, x2: 560, y2: 350),
      ];

      final res = SpatialLayoutEngine.process(items: items, imgWidth: 900, imgHeight: 1600);
      expect(res.transactions.length, 1);
      expect(res.transactions[0].amountMinorUnits, 220000);
      expect(res.transactions[0].merchantText, 'Starbucks Coffee');
    });

    // 6. Amount above merchant
    test('6. Amount above merchant', () {
      final items = [
        _createItem(readingIndex: 1, text: '₹750', x1: 100, y1: 100, x2: 250, y2: 150),
        _createItem(readingIndex: 2, text: 'Hemant Store', x1: 100, y1: 170, x2: 320, y2: 200),
        _createItem(readingIndex: 3, text: 'Yesterday', x1: 100, y1: 220, x2: 200, y2: 250),
      ];

      final res = SpatialLayoutEngine.process(items: items, imgWidth: 900, imgHeight: 1600);
      expect(res.transactions.length, 1);
      expect(res.transactions[0].amountMinorUnits, 75000);
      expect(res.transactions[0].merchantText, 'Hemant Store');
    });

    // 7. Amount below merchant
    test('7. Amount below merchant', () {
      final items = [
        _createItem(readingIndex: 1, text: 'Sector 18 Petrol Pump', x1: 100, y1: 100, x2: 450, y2: 135),
        _createItem(readingIndex: 2, text: '₹2,000', x1: 100, y1: 160, x2: 250, y2: 200),
        _createItem(readingIndex: 3, text: '18-09-2026', x1: 100, y1: 220, x2: 250, y2: 250),
      ];

      final res = SpatialLayoutEngine.process(items: items, imgWidth: 900, imgHeight: 1600);
      expect(res.transactions.length, 1);
      expect(res.transactions[0].amountMinorUnits, 200000);
      expect(res.transactions[0].merchantText, 'Sector 18 Petrol Pump');
    });

    // 8. Date above merchant
    test('8. Date above merchant', () {
      final items = [
        _createItem(readingIndex: 1, text: '18 September', x1: 80, y1: 80, x2: 220, y2: 110),
        _createItem(readingIndex: 2, text: 'Uber India', x1: 80, y1: 130, x2: 250, y2: 165),
        _createItem(readingIndex: 3, text: '₹425', x1: 700, y1: 130, x2: 800, y2: 165),
      ];

      final res = SpatialLayoutEngine.process(items: items, imgWidth: 900, imgHeight: 1600);
      expect(res.transactions.length, 1);
      expect(res.transactions[0].amountMinorUnits, 42500);
      expect(res.transactions[0].merchantText, 'Uber India');
    });

    // 9. Date below merchant
    test('9. Date below merchant', () {
      final items = [
        _createItem(readingIndex: 1, text: 'Jio Prepaid Recharge', x1: 80, y1: 100, x2: 380, y2: 135),
        _createItem(readingIndex: 2, text: '₹299', x1: 700, y1: 100, x2: 800, y2: 135),
        _createItem(readingIndex: 3, text: '18/09/2026', x1: 80, y1: 150, x2: 220, y2: 180),
      ];

      final res = SpatialLayoutEngine.process(items: items, imgWidth: 900, imgHeight: 1600);
      expect(res.transactions.length, 1);
      expect(res.transactions[0].amountMinorUnits, 29900);
      expect(res.transactions[0].merchantText, 'Jio Prepaid Recharge');
    });

    // 10. Two-column statement table
    test('10. Two-column statement table', () {
      final items = [
        _createItem(readingIndex: 1, text: 'Amazon Pay India', x1: 50, y1: 100, x2: 300, y2: 130),
        _createItem(readingIndex: 2, text: '₹1,299', x1: 650, y1: 100, x2: 800, y2: 130),
        _createItem(readingIndex: 3, text: '18 Sep', x1: 50, y1: 140, x2: 150, y2: 165),

        _createItem(readingIndex: 4, text: 'Flipkart Internet', x1: 50, y1: 240, x2: 300, y2: 270),
        _createItem(readingIndex: 5, text: '₹849', x1: 650, y1: 240, x2: 800, y2: 270),
        _createItem(readingIndex: 6, text: '17 Sep', x1: 50, y1: 280, x2: 150, y2: 305),
      ];

      final res = SpatialLayoutEngine.process(items: items, imgWidth: 900, imgHeight: 1600);
      expect(res.transactions.length, 2);
      expect(res.transactions[0].merchantText, 'Amazon Pay India');
      expect(res.transactions[0].amountMinorUnits, 129900);
      expect(res.transactions[1].merchantText, 'Flipkart Internet');
      expect(res.transactions[1].amountMinorUnits, 84900);
    });

    // 11. Bank statement layout
    test('11. Bank statement layout', () {
      final items = [
        _createItem(readingIndex: 1, text: '18-09-2026', x1: 40, y1: 100, x2: 160, y2: 130),
        _createItem(readingIndex: 2, text: 'POS SWIGGY BANGALORE', x1: 200, y1: 100, x2: 550, y2: 130),
        _createItem(readingIndex: 3, text: '- ₹340.00', x1: 650, y1: 100, x2: 800, y2: 130),

        _createItem(readingIndex: 4, text: '17-09-2026', x1: 40, y1: 220, x2: 160, y2: 250),
        _createItem(readingIndex: 5, text: 'SALARY CREDIT ACME CORP', x1: 200, y1: 220, x2: 550, y2: 250),
        _createItem(readingIndex: 6, text: '+ ₹75,000.00', x1: 650, y1: 220, x2: 830, y2: 250),
      ];

      final res = SpatialLayoutEngine.process(items: items, imgWidth: 900, imgHeight: 1600);
      expect(res.transactions.length, 2);
      expect(res.transactions[0].transactionType, 'expense');
      expect(res.transactions[0].amountMinorUnits, 34000);
      expect(res.transactions[1].transactionType, 'income');
      expect(res.transactions[1].amountMinorUnits, 7500000);
    });

    // 12. Completely unknown / new payment app layout
    test('12. Unknown payment app layout', () {
      final items = [
        _createItem(readingIndex: 1, text: 'Transferred to LOVE YOU CHAI', x1: 80, y1: 150, x2: 450, y2: 185),
        _createItem(readingIndex: 2, text: '₹36', x1: 80, y1: 210, x2: 150, y2: 260),
        _createItem(readingIndex: 3, text: '18 September 2026', x1: 80, y1: 290, x2: 300, y2: 320),
        _createItem(readingIndex: 4, text: 'Reference No: 994827163829', x1: 80, y1: 360, x2: 420, y2: 390),
      ];

      final res = SpatialLayoutEngine.process(items: items, imgWidth: 900, imgHeight: 1600);
      expect(res.transactions.length, 1);
      expect(res.transactions[0].merchantText, 'LOVE YOU CHAI');
      expect(res.transactions[0].amountMinorUnits, 3600);
      expect(res.transactions[0].transactionType, 'expense');
    });

    // 13. Reward / Cashback / Balance screen (must NOT create fake transactions)
    test('13. Reward/cashback screen', () {
      final items = [
        _createItem(readingIndex: 1, text: 'Rewards & Coins', x1: 80, y1: 80, x2: 300, y2: 110),
        _createItem(readingIndex: 2, text: '1200 coins redeemed', x1: 80, y1: 140, x2: 350, y2: 170),
        _createItem(readingIndex: 3, text: "You've won ₹50", x1: 80, y1: 200, x2: 280, y2: 230),
        _createItem(readingIndex: 4, text: 'Available Balance: ₹5,000', x1: 80, y1: 260, x2: 380, y2: 290),
      ];

      final res = SpatialLayoutEngine.process(items: items, imgWidth: 900, imgHeight: 1600);
      // No primary transaction should be generated from rewards, coins, and balance
      expect(res.transactions.isEmpty, isTrue);
    });

    // 14. Receipt with UTR (UTR must not become an amount)
    test('14. Receipt with UTR', () {
      final items = [
        _createItem(readingIndex: 1, text: 'Payment Completed', x1: 100, y1: 100, x2: 350, y2: 130),
        _createItem(readingIndex: 2, text: '₹1,500', x1: 100, y1: 160, x2: 260, y2: 210),
        _createItem(readingIndex: 3, text: 'Paid to Apex Pharmacy', x1: 100, y1: 230, x2: 400, y2: 260),
        _createItem(readingIndex: 4, text: 'UTR: 004415604898', x1: 100, y1: 300, x2: 350, y2: 330),
      ];

      final res = SpatialLayoutEngine.process(items: items, imgWidth: 900, imgHeight: 1600);
      expect(res.transactions.length, 1);
      expect(res.transactions[0].amountMinorUnits, 150000);
      expect(res.transactions[0].amountMinorUnits, isNot(equals(441560489800)));
      expect(res.transactions[0].merchantText, 'Apex Pharmacy');
    });

    // 15. Receipt with bank account number
    test('15. Receipt with account number', () {
      final items = [
        _createItem(readingIndex: 1, text: 'Payment Successful', x1: 100, y1: 100, x2: 350, y2: 130),
        _createItem(readingIndex: 2, text: '₹850', x1: 100, y1: 160, x2: 240, y2: 210),
        _createItem(readingIndex: 3, text: 'To 3M Car Care', x1: 100, y1: 230, x2: 320, y2: 260),
        _createItem(readingIndex: 4, text: 'Debited from HDFC Bank - 8840', x1: 100, y1: 300, x2: 480, y2: 330),
        _createItem(readingIndex: 5, text: '18 Sep 2026', x1: 100, y1: 360, x2: 250, y2: 390),
      ];

      final res = SpatialLayoutEngine.process(items: items, imgWidth: 900, imgHeight: 1600);
      expect(res.transactions.length, 1);
      expect(res.transactions[0].amountMinorUnits, 85000);
      expect(res.transactions[0].merchantText, '3M Car Care');
    });

    // 16. Decimal amount preservation
    test('16. Decimal amount', () {
      final items = [
        _createItem(readingIndex: 1, text: 'D-Mart Supermarket', x1: 60, y1: 100, x2: 320, y2: 130),
        _createItem(readingIndex: 2, text: '₹3,700.97', x1: 650, y1: 100, x2: 820, y2: 130),
        _createItem(readingIndex: 3, text: '18 Sep 2026', x1: 60, y1: 150, x2: 200, y2: 180),
      ];

      final res = SpatialLayoutEngine.process(items: items, imgWidth: 900, imgHeight: 1600);
      expect(res.transactions.length, 1);
      expect(res.transactions[0].amountMinorUnits, 370097);
    });

    // 17. Large amount (₹75,000)
    test('17. Large amount', () {
      final items = [
        _createItem(readingIndex: 1, text: 'Rent Transfer', x1: 60, y1: 100, x2: 250, y2: 130),
        _createItem(readingIndex: 2, text: '₹75,000', x1: 650, y1: 100, x2: 800, y2: 130),
        _createItem(readingIndex: 3, text: '01 Sep 2026', x1: 60, y1: 150, x2: 200, y2: 180),
      ];

      final res = SpatialLayoutEngine.process(items: items, imgWidth: 900, imgHeight: 1600);
      expect(res.transactions.length, 1);
      expect(res.transactions[0].amountMinorUnits, 7500000);
      expect(res.transactions[0].amountMinorUnits, isNot(equals(500000)));
    });

    // 18. Missing currency symbol (plain 50)
    test('18. Missing currency symbol', () {
      final items = [
        _createItem(readingIndex: 1, text: 'New Glossy Unisex Salon', x1: 50, y1: 100, x2: 400, y2: 130),
        _createItem(readingIndex: 2, text: '50', x1: 50, y1: 160, x2: 120, y2: 210),
        _createItem(readingIndex: 3, text: '18 Sep 2026', x1: 50, y1: 240, x2: 200, y2: 270),
        _createItem(readingIndex: 4, text: 'Payment Successful', x1: 50, y1: 50, x2: 300, y2: 80),
      ];

      final res = SpatialLayoutEngine.process(items: items, imgWidth: 900, imgHeight: 1600);
      expect(res.transactions.length, 1);
      expect(res.transactions[0].amountMinorUnits, 5000);
      expect(res.transactions[0].merchantText, 'New Glossy Unisex Salon');
    });

    // 19. Unknown merchant with embedded digits (e.g. 7-Eleven, 3M Car Care, Cafe 47)
    test('19. Unknown merchant with digits', () {
      final items = [
        _createItem(readingIndex: 1, text: '7-Eleven Convenience Store', x1: 60, y1: 100, x2: 420, y2: 130),
        _createItem(readingIndex: 2, text: '₹185', x1: 700, y1: 100, x2: 800, y2: 130),
        _createItem(readingIndex: 3, text: '18 Sep', x1: 60, y1: 150, x2: 160, y2: 180),
      ];

      final res = SpatialLayoutEngine.process(items: items, imgWidth: 900, imgHeight: 1600);
      expect(res.transactions.length, 1);
      expect(res.transactions[0].merchantText, '7-Eleven Convenience Store');
      expect(res.transactions[0].amountMinorUnits, 18500);
    });

    // 20. Multiple transactions with different row heights
    test('20. Multiple transactions with different row heights', () {
      final items = [
        // Short single-line row: height ~40px
        _createItem(readingIndex: 1, text: 'Blinkit', x1: 60, y1: 100, x2: 200, y2: 130),
        _createItem(readingIndex: 2, text: '₹205', x1: 700, y1: 100, x2: 800, y2: 130),
        _createItem(readingIndex: 3, text: '18 Sep', x1: 60, y1: 140, x2: 160, y2: 165),

        // Tall multi-line merchant row: height ~110px
        _createItem(readingIndex: 4, text: 'BANGALORE METROPOLITAN TRANSPORT CORPORATION', x1: 60, y1: 280, x2: 600, y2: 340),
        _createItem(readingIndex: 5, text: '₹24', x1: 700, y1: 280, x2: 800, y2: 310),
        _createItem(readingIndex: 6, text: '17 Sep 2026', x1: 60, y1: 360, x2: 220, y2: 390),
      ];

      final res = SpatialLayoutEngine.process(items: items, imgWidth: 900, imgHeight: 1600);
      expect(res.transactions.length, 2);
      expect(res.transactions[0].merchantText, 'Blinkit');
      expect(res.transactions[0].amountMinorUnits, 20500);
      expect(res.transactions[1].merchantText, 'BANGALORE METROPOLITAN TRANSPORT CORPORATION');
      expect(res.transactions[1].amountMinorUnits, 2400);
    });
  });
}
