import 'package:flutter_test/flutter_test.dart';
import 'package:expense_app/shared/enums/transaction_enums.dart';
import 'package:expense_app/features/import/domain/entities/ocr_document.dart';
import 'package:expense_app/features/import/data/parser/rule_based_transaction_parser.dart';

void main() {
  late RuleBasedTransactionParser parser;

  setUp(() {
    parser = RuleBasedTransactionParser();
  });

  group('RuleBasedTransactionParser Fixture Tests', () {
    test(
      '1. Simple UPI transaction: extracts 1 expense with correct amount, merchant, date',
      () {
        const ocrText = '''
07 Sep 2026
Paid to Swiggy
₹420
Successful
''';
        final doc = OcrDocument.fromText(
          ocrText,
          imagePath: 'screenshot_1.jpg',
        );
        final results = parser.parse(doc);

        expect(results.length, equals(1));
        final tx = results.first;
        expect(tx.merchant, equals('Swiggy'));
        expect(tx.amount, equals(42000)); // 420.00 in minor units
        expect(tx.type, equals(TransactionType.expense));
        expect(tx.categoryId, equals('food'));
        expect(tx.date, equals(DateTime(2026, 9, 7)));
        expect(tx.confidence, greaterThan(0.80));
      },
    );

    test(
      '2. Multiple transactions in history list: extracts 3 transactions',
      () {
        const ocrText = '''
07 Sep 2026
Swiggy
₹420

06 Sep 2026
Uber
₹280

05 Sep 2026
Amazon
₹1,299
''';
        final doc = OcrDocument.fromText(ocrText, imagePath: 'statement.png');
        final results = parser.parse(doc);

        expect(results.length, equals(3));

        expect(results[0].merchant, equals('Swiggy'));
        expect(results[0].amount, equals(42000));
        expect(results[0].categoryId, equals('food'));
        expect(results[0].date, equals(DateTime(2026, 9, 7)));

        expect(results[1].merchant, equals('Uber'));
        expect(results[1].amount, equals(28000));
        expect(results[1].categoryId, equals('transport'));
        expect(results[1].date, equals(DateTime(2026, 9, 6)));

        expect(results[2].merchant, equals('Amazon'));
        expect(results[2].amount, equals(129900));
        expect(results[2].categoryId, equals('shopping'));
        expect(results[2].date, equals(DateTime(2026, 9, 5)));
      },
    );

    test(
      '3. Income transaction: parses income correctly with credit terminology',
      () {
        const ocrText = '''
Received from Company
₹72,500
05 Sep 2026
''';
        final doc = OcrDocument.fromText(ocrText, imagePath: 'salary.png');
        final results = parser.parse(doc);

        expect(results.length, equals(1));
        final tx = results.first;
        expect(tx.type, equals(TransactionType.income));
        expect(tx.amount, equals(7250000)); // 72,500.00
        expect(tx.categoryId, equals('income'));
        expect(tx.merchant, equals('Company'));
        expect(tx.date, equals(DateTime(2026, 9, 5)));
      },
    );

    test(
      '4. Balance + transaction: only extracts the transaction and ignores Available Balance',
      () {
        const ocrText = '''
Available Balance ₹24,580

Swiggy
₹420
''';
        final doc = OcrDocument.fromText(
          ocrText,
          imagePath: 'balance_screen.jpg',
        );
        final results = parser.parse(doc);

        expect(results.length, equals(1));
        final tx = results.first;
        expect(tx.amount, equals(42000)); // Only 420.00, NOT 24,580
        expect(tx.merchant, equals('Swiggy'));
      },
    );

    test(
      '5. Duplicate formatting: normalizes Rs. vs ₹ and different date strings',
      () {
        const ocrText1 = '''
07/09/2026
SWIGGY
Rs. 420
''';
        const ocrText2 = '''
07 Sep 2026
Swiggy
₹420
''';
        final doc1 = OcrDocument.fromText(ocrText1);
        final doc2 = OcrDocument.fromText(ocrText2);

        final r1 = parser.parse(doc1).first;
        final r2 = parser.parse(doc2).first;

        expect(r1.amount, equals(42000));
        expect(r2.amount, equals(42000));
        expect(r1.date, equals(DateTime(2026, 9, 7)));
        expect(r2.date, equals(DateTime(2026, 9, 7)));
        expect(r1.normalizedFingerprint, equals(r2.normalizedFingerprint));
      },
    );

    test(
      '6. Unrelated numbers: ignores Transaction ID, Available Balance, and Summary Total',
      () {
        const ocrText = '''
Transaction ID:
9283749283

Available Balance:
₹24,580

Total:
₹1,719
''';
        final doc = OcrDocument.fromText(ocrText, imagePath: 'summary.jpg');
        final results = parser.parse(doc);

        // No actual merchant transaction exists, so no false transaction should be generated
        expect(results.isEmpty, isTrue);
      },
    );

    test(
      '7. Recognizes various currency tokens: INR, Rs, Rs., ₹ with decimal amounts',
      () {
        const ocrText = '''
05 Sep 2026
Uber Ride
INR 1,299.50
Completed
''';
        final doc = OcrDocument.fromText(ocrText);
        final results = parser.parse(doc);

        expect(results.length, equals(1));
        expect(results.first.amount, equals(129950));
        expect(results.first.merchant, equals('Uber Ride'));
      },
    );

    test(
      '8. Category inference assigns appropriate category for various merchants',
      () {
        final merchantsAndCategories = {
          'Blinkit': 'groceries',
          'Zomato': 'food',
          'Ola Cabs': 'transport',
          'Netflix': 'entertainment',
          'Apollo Pharmacy': 'health',
          'Airtel Broadband': 'bills',
        };

        for (final entry in merchantsAndCategories.entries) {
          final text =
              '''
05 Sep 2026
Paid to ${entry.key}
₹250
''';
          final res = parser.parse(OcrDocument.fromText(text));
          expect(
            res.first.categoryId,
            equals(entry.value),
            reason: 'Expected ${entry.value} for ${entry.key}',
          );
        }
      },
    );
  });
}
