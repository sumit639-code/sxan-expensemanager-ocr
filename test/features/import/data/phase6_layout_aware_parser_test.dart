import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:expense_app/shared/enums/transaction_enums.dart';
import 'package:expense_app/features/import/domain/entities/ocr_document.dart';
import 'package:expense_app/features/import/data/parser/amount_reconstructor.dart';
import 'package:expense_app/features/import/data/parser/date_extractor.dart';
import 'package:expense_app/features/import/data/parser/rule_based_transaction_parser.dart';

void main() {
  late RuleBasedTransactionParser parser;

  setUp(() {
    parser = RuleBasedTransactionParser();
  });

  group('Phase 6: Section 40 Required Unit Tests', () {
    test('1. ₹40 parsing produces 4000 minor units', () {
      final amt = AmountReconstructor.parseAmount('₹40');
      expect(amt, isNotNull);
      expect(amt!.amountMinor, equals(4000));
      expect(amt.isIncome, isFalse);
    });

    test('2. ₹349 parsing produces 34900 minor units', () {
      final amt = AmountReconstructor.parseAmount('₹349');
      expect(amt, isNotNull);
      expect(amt!.amountMinor, equals(34900));
    });

    test('3. ₹2,500 parsing produces 250000 minor units', () {
      final amt = AmountReconstructor.parseAmount('₹2,500');
      expect(amt, isNotNull);
      expect(amt!.amountMinor, equals(250000));
    });

    test(
      '4. ₹5,000 parsing produces 500000 minor units (CRITICAL: NEVER drops digits to 5 or 50)',
      () {
        final amt = AmountReconstructor.parseAmount('₹5,000');
        expect(amt, isNotNull);
        expect(amt!.amountMinor, equals(500000));
        expect(amt.amountMinor, isNot(equals(500)));
        expect(amt.amountMinor, isNot(equals(5000)));
      },
    );

    test('5. ₹2,200 parsing produces 220000 minor units', () {
      final amt = AmountReconstructor.parseAmount('₹2,200');
      expect(amt, isNotNull);
      expect(amt!.amountMinor, equals(220000));
    });

    test('6. ₹8,000 parsing produces 800000 minor units', () {
      final amt = AmountReconstructor.parseAmount('₹8,000');
      expect(amt, isNotNull);
      expect(amt!.amountMinor, equals(800000));
    });

    test('7. ₹1,500 parsing produces 150000 minor units', () {
      final amt = AmountReconstructor.parseAmount('₹1,500');
      expect(amt, isNotNull);
      expect(amt!.amountMinor, equals(150000));
    });

    test('8. Decimal amount parsing: ₹420.50 produces 42050 minor units', () {
      final amt = AmountReconstructor.parseAmount('₹420.50');
      expect(amt, isNotNull);
      expect(amt!.amountMinor, equals(42050));
    });

    test(
      '9. Indian comma formatting: 1,00,000 and 10,00,000 are parsed accurately',
      () {
        final lakh = AmountReconstructor.parseAmount('₹1,00,000');
        expect(lakh, isNotNull);
        expect(lakh!.amountMinor, equals(10000000)); // 1 lakh rupees in paise

        final tenLakh = AmountReconstructor.parseAmount('₹10,00,000');
        expect(tenLakh, isNotNull);
        expect(
          tenLakh!.amountMinor,
          equals(100000000),
        ); // 10 lakh rupees in paise
      },
    );

    test(
      '10. Split OCR amount elements: merges fragmented tokens ["₹", "5", ",", "000"] into 500000 paise',
      () {
        final reconstructed = AmountReconstructor.reconstructFromTokens([
          '₹',
          '5',
          ',',
          '000',
        ]);
        expect(reconstructed, isNotNull);
        expect(reconstructed!.amountMinor, equals(500000));
        expect(reconstructed.formattedText, contains('5,000'));

        final reconstructed2 = AmountReconstructor.reconstructFromTokens([
          '5,',
          '000',
        ]);
        expect(reconstructed2, isNotNull);
        expect(reconstructed2!.amountMinor, equals(500000));

        final reconstructed3 = AmountReconstructor.reconstructFromTokens([
          '+',
          '₹',
          '8,000',
        ]);
        expect(reconstructed3, isNotNull);
        expect(reconstructed3!.amountMinor, equals(800000));
        expect(reconstructed3.isIncome, isTrue);
      },
    );

    test(
      '11. Date parsing: supports relative, Layout A, and timestamp formats',
      () {
        final now = DateTime(2026, 9, 8, 12, 0);

        // Relative dates
        final hoursRes = DateExtractor.parseDate('8 hours ago', now: now);
        expect(hoursRes, isNotNull);
        expect(hoursRes!.date.hour, equals(4));

        final daysRes = DateExtractor.parseDate('1 day ago', now: now);
        expect(daysRes, isNotNull);
        expect(daysRes!.date.day, equals(7));

        // Layout A month dates without year
        final dMmm = DateExtractor.parseDate('7 September', now: now);
        expect(dMmm, isNotNull);
        expect(dMmm!.date.day, equals(7));
        expect(dMmm.date.month, equals(9));

        // Layout B dates
        final septShort = DateExtractor.parseDate('04 Sept', now: now);
        expect(septShort, isNotNull);
        expect(septShort!.date.day, equals(4));
        expect(septShort.date.month, equals(9));

        // Full timestamp with time
        final fullTs = DateExtractor.parseDate('2 September 2026 at 2:35 pm');
        expect(fullTs, isNotNull);
        expect(fullTs!.date.year, equals(2026));
        expect(fullTs.date.month, equals(9));
        expect(fullTs.date.day, equals(2));
        expect(fullTs.date.hour, equals(14));
        expect(fullTs.date.minute, equals(35));
      },
    );

    test(
      '12. Merchant extraction: ignores UI text like Search, Status, History',
      () {
        const text = '''
Search transactions
Status
7 September
ASHISH KUMAR NAYAK
₹40
''';
        final results = parser.parse(OcrDocument.fromText(text));
        expect(results.length, equals(1));
        expect(results.first.merchant, equals('ASHISH KUMAR NAYAK'));
      },
    );

    test('13. Paid to -> expense', () {
      const text = '''
Paid to RELIANCE JIO INFOCOMM
₹349
04 Sept
''';
      final results = parser.parse(OcrDocument.fromText(text));
      expect(results.length, equals(1));
      expect(results.first.type, equals(TransactionType.expense));
    });

    test('14. Received from -> income', () {
      const text = '''
Received from Baba
+ ₹1
1 day ago
Credited to
''';
      final results = parser.parse(OcrDocument.fromText(text));
      expect(results.length, equals(1));
      expect(results.first.type, equals(TransactionType.income));
      expect(results.first.amount, equals(100)); // 1.00 in minor units
    });

    test('15. Debited from -> expense', () {
      const text = '''
Payment to ICCL Mutual Funds Autopay
₹1,500
8 hours ago
Debited from
''';
      final results = parser.parse(OcrDocument.fromText(text));
      expect(results.length, equals(1));
      expect(results.first.type, equals(TransactionType.expense));
    });

    test('16. Credited to -> income', () {
      const text = '''
PARIKSIT INCORPORATION INDIA
₹8,000
1 day ago
Credited to
''';
      final results = parser.parse(OcrDocument.fromText(text));
      expect(results.length, equals(1));
      expect(results.first.type, equals(TransactionType.income));
    });

    test('17. + amount -> income', () {
      const text = '''
PARIKSIT INCORPORATION INDIA
+ ₹8,000
1 day ago
''';
      final results = parser.parse(OcrDocument.fromText(text));
      expect(results.length, equals(1));
      expect(results.first.type, equals(TransactionType.income));
      expect(results.first.amount, equals(800000));
    });

    test(
      '18. Balance filtering: Available Balance is never converted to a transaction',
      () {
        const text = '''
Available Balance
₹24,580
Swiggy
₹420
7 September
''';
        final results = parser.parse(OcrDocument.fromText(text));
        expect(results.length, equals(1));
        expect(results.first.amount, equals(42000));
        expect(results.first.merchant, equals('Swiggy'));
      },
    );

    test(
      '19. Total filtering: Summary totals like "Total" and monthly summaries are rejected',
      () {
        const text = '''
Total
₹1,719
Swiggy
₹420
7 September
''';
        final results = parser.parse(OcrDocument.fromText(text));
        expect(results.length, equals(1));
        expect(results.first.amount, equals(42000));
      },
    );

    test(
      '20. Reference number filtering: 10-18 digit IDs and phone numbers are rejected',
      () {
        expect(AmountReconstructor.isIdentifierOrPhone('9283749283'), isTrue);
        expect(
          AmountReconstructor.isIdentifierOrPhone('Transaction ID: 9283749283'),
          isTrue,
        );
        expect(
          AmountReconstructor.isIdentifierOrPhone('UPI Ref 123456789012'),
          isTrue,
        );
        expect(AmountReconstructor.isIdentifierOrPhone('9876543210'), isTrue);
      },
    );

    test(
      '21. Transaction row grouping: Layout B block creates 1 single transaction',
      () {
        const text = '''
Payment to
ICCL Mutual Funds Autopay
₹1,500
8 hours ago
Debited from
''';
        final results = parser.parse(OcrDocument.fromText(text));
        expect(results.length, equals(1));
        expect(results.first.merchant, equals('ICCL Mutual Funds Autopay'));
        expect(results.first.amount, equals(150000));
        expect(results.first.type, equals(TransactionType.expense));
      },
    );

    test(
      '22. Duplicate normalization: compares different casings and currency tokens',
      () {
        final tx1 = parser
            .parse(OcrDocument.fromText('07 Sep 2026\nSWIGGY\n₹420'))
            .first;
        final tx2 = parser
            .parse(OcrDocument.fromText('07 Sep 2026\nswiggy\nRs. 420'))
            .first;

        expect(tx1.normalizedFingerprint, equals(tx2.normalizedFingerprint));
      },
    );

    test('23. Confidence calculation: complete row yields high confidence', () {
      const text = '''
Paid to Swiggy
₹420
07 Sep 2026
Debited from
''';
      final results = parser.parse(OcrDocument.fromText(text));
      expect(results.length, equals(1));
      expect(results.first.confidence, greaterThanOrEqualTo(0.85));
      expect(results.first.confidenceLabel, equals('High confidence'));
    });

    test(
      '24. Multiple screenshot extraction: parsing multiple documents produces distinct items',
      () {
        final doc1 = OcrDocument.fromText('7 September\nJIO\n₹349');
        final doc2 = OcrDocument.fromText('6 September\nOD07 SNACKS\n₹80');

        final r1 = parser.parse(doc1);
        final r2 = parser.parse(doc2);
        final combined = [...r1, ...r2];

        expect(combined.length, equals(2));
        expect(combined[0].merchant, equals('JIO'));
        expect(combined[1].merchant, equals('OD07 SNACKS'));
      },
    );
  });

  group('Phase 6: Section 29 & 30 Target Screenshot Fixtures', () {
    test(
      'Section 29: Screenshot 1 & 3 Fixture with 2D spatial coordinates (including ₹5,000)',
      () {
        // Build 2D spatial OCR document representing Google Pay transaction list
        final lines = <OcrLine>[
          // Status bar & search
          const OcrLine(
            text: '08:56',
            boundingBox: Rect.fromLTWH(20, 10, 60, 20),
          ),
          const OcrLine(
            text: 'Search transactions',
            boundingBox: Rect.fromLTWH(80, 50, 200, 30),
          ),
          const OcrLine(
            text: 'Status',
            boundingBox: Rect.fromLTWH(40, 100, 60, 25),
          ),

          // Row 1: ASHISH KUMAR NAYAK, 7 September, ₹40
          const OcrLine(text: 'A', boundingBox: Rect.fromLTWH(40, 150, 30, 30)),
          const OcrLine(
            text: 'ASHISH KUMAR NAYAK',
            boundingBox: Rect.fromLTWH(90, 145, 300, 20),
          ),
          const OcrLine(
            text: '₹40',
            boundingBox: Rect.fromLTWH(550, 145, 70, 20),
          ),
          const OcrLine(
            text: '7 September',
            boundingBox: Rect.fromLTWH(90, 170, 140, 18),
          ),

          // Row 2: JIO, 6 September, ₹349
          const OcrLine(text: 'J', boundingBox: Rect.fromLTWH(40, 220, 30, 30)),
          const OcrLine(
            text: 'JIO',
            boundingBox: Rect.fromLTWH(90, 215, 80, 20),
          ),
          const OcrLine(
            text: '₹349',
            boundingBox: Rect.fromLTWH(550, 215, 80, 20),
          ),
          const OcrLine(
            text: '6 September',
            boundingBox: Rect.fromLTWH(90, 240, 140, 18),
          ),

          // Row 3: Bishal BhanjDeo, 5 September, ₹2,500
          const OcrLine(text: 'B', boundingBox: Rect.fromLTWH(40, 290, 30, 30)),
          const OcrLine(
            text: 'Bishal BhanjDeo',
            boundingBox: Rect.fromLTWH(90, 285, 200, 20),
          ),
          const OcrLine(
            text: '₹2,500',
            boundingBox: Rect.fromLTWH(550, 285, 90, 20),
          ),
          const OcrLine(
            text: '5 September',
            boundingBox: Rect.fromLTWH(90, 310, 140, 18),
          ),

          // Row 4: OD07 SNACKS, 5 September, ₹80
          const OcrLine(text: 'O', boundingBox: Rect.fromLTWH(40, 360, 30, 30)),
          const OcrLine(
            text: 'OD07 SNACKS',
            boundingBox: Rect.fromLTWH(90, 355, 180, 20),
          ),
          const OcrLine(
            text: '₹80',
            boundingBox: Rect.fromLTWH(550, 355, 70, 20),
          ),
          const OcrLine(
            text: '5 September',
            boundingBox: Rect.fromLTWH(90, 380, 140, 18),
          ),

          // Row 5: SBI ATM CASH WITHDRAWAL THROUGH UPI, 2 September, ₹5,000 (Wrapped merchant title)
          const OcrLine(text: 'S', boundingBox: Rect.fromLTWH(40, 430, 30, 30)),
          const OcrLine(
            text: 'SBI ATM CASH WITHDRAWAL',
            boundingBox: Rect.fromLTWH(90, 425, 350, 20),
          ),
          const OcrLine(
            text: 'THROUGH UPI',
            boundingBox: Rect.fromLTWH(90, 448, 160, 18),
          ),
          const OcrLine(
            text: '₹5,000',
            boundingBox: Rect.fromLTWH(550, 425, 90, 20),
          ),
          const OcrLine(
            text: '2 September',
            boundingBox: Rect.fromLTWH(90, 470, 140, 18),
          ),

          // Row 6: M S SATYAM SERVICE STA, 2 September 2026 at 2:35 pm, ₹2,200
          const OcrLine(text: 'M', boundingBox: Rect.fromLTWH(40, 520, 30, 30)),
          const OcrLine(
            text: 'M S SATYAM SERVICE STA',
            boundingBox: Rect.fromLTWH(90, 515, 300, 20),
          ),
          const OcrLine(
            text: '₹2,200',
            boundingBox: Rect.fromLTWH(550, 515, 90, 20),
          ),
          const OcrLine(
            text: '2 September 2026 at 2:35 pm',
            boundingBox: Rect.fromLTWH(90, 540, 250, 18),
          ),
        ];

        final doc = OcrDocument(
          fullText: lines.map((l) => l.text).join('\n'),
          blocks: [],
          lines: lines,
          imageWidth: 720,
          imageHeight: 1600,
          imagePath: 'gpay_history.png',
        );

        final results = parser.parse(doc);
        expect(results.length, equals(6));

        // 1. Ashish Kumar Nayak
        expect(results[0].merchant, equals('ASHISH KUMAR NAYAK'));
        expect(results[0].amount, equals(4000));
        expect(results[0].type, equals(TransactionType.expense));

        // 2. Jio
        expect(results[1].merchant, equals('JIO'));
        expect(results[1].amount, equals(34900));
        expect(results[1].categoryId, equals('bills'));

        // 3. Bishal BhanjDeo
        expect(results[2].merchant, equals('Bishal BhanjDeo'));
        expect(results[2].amount, equals(250000)); // 2,500.00

        // 4. OD07 Snacks
        expect(results[3].merchant, equals('OD07 SNACKS'));
        expect(results[3].amount, equals(8000));
        expect(results[3].categoryId, equals('food'));

        // 5. CRITICAL: SBI ATM CASH WITHDRAWAL THROUGH UPI -> 500000 (NOT 5!)
        expect(
          results[4].merchant,
          equals('SBI ATM CASH WITHDRAWAL THROUGH UPI'),
        );
        expect(
          results[4].amount,
          equals(500000),
        ); // Exactly ₹5,000 = 500000 paise
        expect(results[4].type, equals(TransactionType.expense));
        expect(results[4].amount, isNot(equals(500)));

        // 6. M S SATYAM SERVICE STA
        expect(results[5].merchant, equals('M S SATYAM SERVICE STA'));
        expect(results[5].amount, equals(220000));
        expect(results[5].categoryId, equals('transport'));
        expect(results[5].date!.hour, equals(14));
        expect(results[5].date!.minute, equals(35));
      },
    );

    test('Section 30: Screenshot 2 Fixture (PhonePe Layout B timeline list)', () {
      const ocrLayoutB = '''
Payment to
ICCL Mutual Funds Autopay
₹1,500
8 hours ago
Debited from

Received from
PARIKSIT INCORPORATION INDIA ...
+ ₹8,000
1 day ago
Credited to

Received from
Baba
+ ₹1
1 day ago
Credited to

Paid to
RELIANCE JIO INFOCOMM
₹349
04 Sept
Debited from

Paid to
Baba
₹1
02 Sept
Debited from

Paid to
Baba
₹1
02 Sept
Debited from

August 2026 + ₹3,700.97
''';

      final doc = OcrDocument.fromText(
        ocrLayoutB,
        imagePath: 'phonepe_history.png',
      );
      final results = parser.parse(doc);

      // Total 6 transactions. "August 2026 + ₹3,700.97" footer summary MUST be filtered out!
      expect(results.length, equals(6));

      // 1. ICCL Mutual Funds
      expect(results[0].merchant, equals('ICCL Mutual Funds Autopay'));
      expect(results[0].amount, equals(150000));
      expect(results[0].type, equals(TransactionType.expense));
      expect(results[0].categoryId, equals('bills'));

      // 2. Pariksit Incorporation India (Income + ₹8,000)
      expect(results[1].merchant, equals('PARIKSIT INCORPORATION INDIA ...'));
      expect(results[1].amount, equals(800000));
      expect(results[1].type, equals(TransactionType.income));
      expect(results[1].categoryId, equals('income'));

      // 3. Baba (Income + ₹1)
      expect(results[2].merchant, equals('Baba'));
      expect(results[2].amount, equals(100));
      expect(results[2].type, equals(TransactionType.income));

      // 4. Reliance Jio Infocomm
      expect(results[3].merchant, equals('RELIANCE JIO INFOCOMM'));
      expect(results[3].amount, equals(34900));
      expect(results[3].type, equals(TransactionType.expense));
      expect(results[3].categoryId, equals('bills'));

      // 5. Baba (Paid to Baba ₹1)
      expect(results[4].merchant, equals('Baba'));
      expect(results[4].amount, equals(100));
      expect(results[4].type, equals(TransactionType.expense));

      // 6. Baba (Paid to Baba ₹1)
      expect(results[5].merchant, equals('Baba'));
      expect(results[5].amount, equals(100));
      expect(results[5].type, equals(TransactionType.expense));
    });

    test('Section 31: False Positives are rejected completely', () {
      const text = '''
Available Balance
₹24,580

Total
₹1,719

Transaction ID:
9283749283

August 2026 + ₹3,700.97
''';
      final results = parser.parse(OcrDocument.fromText(text));
      expect(results.isEmpty, isTrue);
    });
  });

  group('Phase 6 Debug: Target Screenshot & Staged Fallback Tests', () {
    test(
      'Section 8 & 21: Full Target Screenshot extraction with all 16 transactions (including ₹5,000)',
      () {
        const fullGPayOcr = '''
Search transactions
Status

A
ASHISH KUMAR NAYAK
7 September
₹40

J
JIO
6 September
₹349

B
Bishal BhanjDeo
5 September
₹2,500

O
OD07 SNACKS
5 September
₹80

S
SARITA KUMARI SAHU
5 September
₹20

K
KRISHNA STORE
4 September
₹50

H
Hemant Store
4 September
₹20

T
THE PRABHAT MISTANNA BHANDAR
4 September
₹205

A
ABHIJEET KUMAR SINGH
4 September
₹200

O
Om hotel sweet and snacks
3 September
₹75

S
SAPAN KUMAR MANDAL
3 September
₹110

S
SBI ATM CASH WITHDRAWAL THROUGH UPI
2 September
₹5,000

M
M S SATYAM SERVICE STA
2 September
₹2,200

P
POOJA
2 September
₹120

S
Sri Ram store
2 September
₹138

V
VIKASH MUNDHRA
1 September
₹425
''';

        final doc = OcrDocument.fromText(fullGPayOcr);
        final results = parser.parse(doc);

        expect(results.length, equals(16));

        // 1. ASHISH KUMAR NAYAK — ₹40
        expect(results[0].merchant, equals('ASHISH KUMAR NAYAK'));
        expect(results[0].amount, equals(4000));

        // 2. JIO — ₹349
        expect(results[1].merchant, equals('JIO'));
        expect(results[1].amount, equals(34900));

        // 3. Bishal BhanjDeo — ₹2,500
        expect(results[2].merchant, equals('Bishal BhanjDeo'));
        expect(results[2].amount, equals(250000));

        // 4. OD07 SNACKS — ₹80
        expect(results[3].merchant, equals('OD07 SNACKS'));
        expect(results[3].amount, equals(8000));

        // 5. SARITA KUMARI SAHU — ₹20
        expect(results[4].merchant, equals('SARITA KUMARI SAHU'));
        expect(results[4].amount, equals(2000));

        // 6. KRISHNA STORE — ₹50
        expect(results[5].merchant, equals('KRISHNA STORE'));
        expect(results[5].amount, equals(5000));

        // 7. Hemant Store — ₹20
        expect(results[6].merchant, equals('Hemant Store'));
        expect(results[6].amount, equals(2000));

        // 8. THE PRABHAT MISTANNA BHANDAR — ₹205
        expect(results[7].merchant, equals('THE PRABHAT MISTANNA BHANDAR'));
        expect(results[7].amount, equals(20500));

        // 9. ABHIJEET KUMAR SINGH — ₹200
        expect(results[8].merchant, equals('ABHIJEET KUMAR SINGH'));
        expect(results[8].amount, equals(20000));

        // 10. Om hotel sweet and snacks — ₹75
        expect(results[9].merchant, equals('Om hotel sweet and snacks'));
        expect(results[9].amount, equals(7500));

        // 11. SAPAN KUMAR MANDAL — ₹110
        expect(results[10].merchant, equals('SAPAN KUMAR MANDAL'));
        expect(results[10].amount, equals(11000));

        // 12. CRITICAL ₹5,000 TEST: MUST BE 500000, NOT 5, NOT 50, NOT 500
        expect(
          results[11].merchant,
          equals('SBI ATM CASH WITHDRAWAL THROUGH UPI'),
        );
        expect(results[11].amount, equals(500000));
        expect(results[11].amount, isNot(equals(5)));
        expect(results[11].amount, isNot(equals(50)));
        expect(results[11].amount, isNot(equals(500)));
        expect(results[11].amount, isNot(equals(5000)));

        // 13. M S SATYAM SERVICE STA — ₹2,200
        expect(results[12].merchant, equals('M S SATYAM SERVICE STA'));
        expect(results[12].amount, equals(220000));

        // 14. POOJA — ₹120
        expect(results[13].merchant, equals('POOJA'));
        expect(results[13].amount, equals(12000));

        // 15. Sri Ram store — ₹138
        expect(results[14].merchant, equals('Sri Ram store'));
        expect(results[14].amount, equals(13800));

        // 16. VIKASH MUNDHRA — ₹425
        expect(results[15].merchant, equals('VIKASH MUNDHRA'));
        expect(results[15].amount, equals(42500));
      },
    );

    test('Combined same-line OCR baseline text is parsed accurately', () {
      const combinedLines = '''
ASHISH KUMAR NAYAK ₹40
7 September
JIO ₹349
6 September
Bishal BhanjDeo ₹2,500
5 September
SBI ATM CASH WITHDRAWAL THROUGH UPI ₹5,000
2 September
''';
      final results = parser.parse(OcrDocument.fromText(combinedLines));
      expect(results.length, equals(4));

      expect(results[0].merchant, equals('ASHISH KUMAR NAYAK'));
      expect(results[0].amount, equals(4000));

      expect(results[1].merchant, equals('JIO'));
      expect(results[1].amount, equals(34900));

      expect(results[2].merchant, equals('Bishal BhanjDeo'));
      expect(results[2].amount, equals(250000));

      expect(
        results[3].merchant,
        equals('SBI ATM CASH WITHDRAWAL THROUGH UPI'),
      );
      expect(results[3].amount, equals(500000));
    });

    test(
      'Section 7: Staged parsing - Level 2 (Merchant + Amount without date) creates candidate',
      () {
        const textWithoutDate = '''
JIO
₹349
''';
        final results = parser.parse(OcrDocument.fromText(textWithoutDate));
        expect(results.length, equals(1));
        expect(results.first.merchant, equals('JIO'));
        expect(results.first.amount, equals(34900));
      },
    );

    test(
      'Section 7: Staged parsing - Level 3 (Amount + nearby text) creates candidate with review required',
      () {
        const textWithoutExplicitMerchant = '''
Unknown Payee Info
₹5,000
''';
        final results = parser.parse(
          OcrDocument.fromText(textWithoutExplicitMerchant),
        );
        expect(results.length, equals(1));
        expect(results.first.amount, equals(500000));
        expect(results.first.title, contains('Unknown Payee Info'));
      },
    );
  });
}
