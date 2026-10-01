import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:expense_app/core/utils/money_utils.dart';
import 'package:expense_app/features/import/data/parser/amount_reconstructor.dart';
import 'package:expense_app/features/import/data/parser/date_extractor.dart';
import 'package:expense_app/features/import/data/parser/rule_based_transaction_parser.dart';
import 'package:expense_app/features/import/data/services/local_transaction_ocr_extractor.dart';
import 'package:expense_app/features/import/domain/entities/extracted_transaction.dart';
import 'package:expense_app/features/import/domain/services/duplicate_detector.dart';
import 'package:expense_app/features/transactions/domain/entities/transaction_entity.dart';
import 'package:expense_app/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:expense_app/shared/enums/transaction_enums.dart';
import 'package:transaction_ocr_flutter/transaction_ocr_flutter.dart' as pkg;

class FakeTxRepo implements TransactionRepository {
  final List<Transaction> _list;
  FakeTxRepo([List<Transaction>? list]) : _list = list ?? [];

  @override
  Future<List<Transaction>> getAllTransactions() async => List.unmodifiable(_list);
  @override
  Future<void> addTransaction(Transaction tx) async => _list.add(tx);
  @override
  Future<void> addTransactions(List<Transaction> txs) async => _list.addAll(txs);
  @override
  Future<void> deleteTransaction(String id) async => _list.removeWhere((t) => t.id == id);
  @override
  Future<void> deleteTransactions(List<String> ids) async {
    final set = ids.toSet();
    _list.removeWhere((t) => set.contains(t.id));
  }
  @override
  Future<Transaction?> getTransactionById(String id) async =>
      _list.firstWhere((t) => t.id == id, orElse: () => throw StateError('Not found'));
  @override
  Future<List<Transaction>> getTransactionsByDateRange(DateTime start, DateTime end) async =>
      _list.where((t) => t.date.isAfter(start) && t.date.isBefore(end)).toList();
  @override
  Future<List<Transaction>> searchTransactions(String query, {TransactionType? filterType}) async => _list;
  @override
  Stream<List<Transaction>> watchAllTransactions() => Stream.value(_list);
  @override
  Future<void> updateTransaction(Transaction tx) async {
    final idx = _list.indexWhere((t) => t.id == tx.id);
    if (idx != -1) _list[idx] = tx;
  }
  @override
  Future<void> clearAllTransactions() async => _list.clear();
}

class FakeOcrEngine implements pkg.OcrEngine {
  final pkg.OcrResult Function(Uint8List bytes, String filename) handler;
  FakeOcrEngine({required this.handler});

  @override
  String get engineName => 'FakeOcrEngine';
  @override
  bool get isInitialized => true;
  @override
  Future<void> initialize() async {}
  @override
  Future<void> dispose() async {}
  @override
  Future<pkg.OcrResult> extractImage(
    Uint8List bytes, {
    String filename = 'test.png',
    pkg.OcrProgressCallback? onProgress,
    int currentImage = 1,
    int totalImages = 1,
  }) async {
    onProgress?.call(currentImage, totalImages, 'Done', 1.0);
    return handler(bytes, filename);
  }
}

File? _findFixture(String name) {
  final candidates = [
    File('test/fixtures/$name'),
    File('fixtures/$name'),
    File('../fixtures/$name'),
    File('packages/transaction_ocr_flutter/test/fixtures/$name'),
    File('data/outputs/$name'),
    File('../TransactionOcr/data/outputs/$name'),
    File('E:/Dev/TransactionOcr/data/outputs/$name'),
  ];
  for (final f in candidates) {
    if (f.existsSync()) return f;
  }
  return null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 8: Production-Grade OCR -> Transaction Extraction Tests', () {
    // -------------------------------------------------------------------------
    // 1. Centralized Decimal-Safe Amount Parsing Tests
    // -------------------------------------------------------------------------
    group('1. Centralized Decimal-Safe Amount Parsing', () {
      test('Parses standard integer amounts to exact minor units (paise)', () {
        expect(AmountReconstructor.parseAmount('₹20')?.amountMinor, equals(2000));
        expect(AmountReconstructor.parseAmount('R20')?.amountMinor, equals(2000));
        expect(AmountReconstructor.parseAmount('₹205')?.amountMinor, equals(20500));
        expect(AmountReconstructor.parseAmount('R205')?.amountMinor, equals(20500));
        expect(AmountReconstructor.parseAmount('₹2,200')?.amountMinor, equals(220000));
        expect(AmountReconstructor.parseAmount('R2,200')?.amountMinor, equals(220000));
        expect(AmountReconstructor.parseAmount('₹5,000')?.amountMinor, equals(500000));
      });

      test('Preserves decimals without precision loss into minor units (paise)', () {
        // ₹200.90 must be exactly 20090 paise (never truncated to 200 or 20000)
        final a1 = AmountReconstructor.parseAmount('₹200.90');
        expect(a1, isNotNull);
        expect(a1!.amountMinor, equals(20090));

        // +₹3,700.97 must be exactly 370097 paise
        final a2 = AmountReconstructor.parseAmount('+₹3,700.97');
        expect(a2, isNotNull);
        expect(a2!.amountMinor, equals(370097));
        expect(a2.isIncome, isTrue);

        // Small decimals
        expect(AmountReconstructor.parseAmount('₹0.50')?.amountMinor, equals(50));
        expect(AmountReconstructor.parseAmount('₹0.05')?.amountMinor, equals(5));

        // Plain numbers without currency symbols
        expect(AmountReconstructor.parseRightSideCandidate('2,200')?.amountMinor, equals(220000));
        expect(AmountReconstructor.parseRightSideCandidate('5,000')?.amountMinor, equals(500000));
        expect(AmountReconstructor.parseRightSideCandidate('200.90')?.amountMinor, equals(20090));
      });

      test('AmountClassifier in package produces matching minor units', () {
        expect(pkg.AmountClassifier.parseMinorUnits('20'), equals(2000));
        expect(pkg.AmountClassifier.parseMinorUnits('205'), equals(20500));
        expect(pkg.AmountClassifier.parseMinorUnits('2,200'), equals(220000));
        expect(pkg.AmountClassifier.parseMinorUnits('5,000'), equals(500000));
        expect(pkg.AmountClassifier.parseMinorUnits('200.90'), equals(20090));
        expect(pkg.AmountClassifier.parseMinorUnits('3,700.97'), equals(370097));
        expect(pkg.AmountClassifier.parseMinorUnits('0.50'), equals(50));
      });
    });

    // -------------------------------------------------------------------------
    // 2. Prevent ₹5,000 -> ₹75,000 Regressions
    // -------------------------------------------------------------------------
    group('2. Prevent ₹5,000 -> ₹75,000 Regressions', () {
      test('OCR misread 75,000 on right-side normalizes to ₹5,000 (500000 paise)', () {
        final amt = AmountReconstructor.parseAmount('75,000');
        expect(amt, isNotNull);
        expect(amt!.amountMinor, equals(500000));
        expect(amt.amountMinor, isNot(equals(7500000))); // NEVER ₹75,000
      });

      test('Explicit ₹75,000 with currency symbol is preserved as 7,500,000 paise', () {
        final amt = AmountReconstructor.parseAmount('₹75,000');
        expect(amt, isNotNull);
        expect(amt!.amountMinor, equals(7500000));
      });

      test('Legitimate ₹75 and ₹750 are never corrupted to 5 or 50', () {
        final amt75 = AmountReconstructor.parseAmount('₹75');
        expect(amt75, isNotNull);
        expect(amt75!.amountMinor, equals(7500));

        final amt750 = AmountReconstructor.parseAmount('₹750');
        expect(amt750, isNotNull);
        expect(amt750!.amountMinor, equals(75000));
      });
    });

    // -------------------------------------------------------------------------
    // 3. Date and Time Detection & Filtering
    // -------------------------------------------------------------------------
    group('3. Date and Time Filtering', () {
      test('Time strings and timestamps are rejected as amounts', () {
        expect(AmountReconstructor.parseAmount('16:48'), isNull);
        expect(AmountReconstructor.parseAmount('08:56'), isNull);
        expect(AmountReconstructor.parseRightSideCandidate('16:48'), isNull);
        expect(pkg.AmountClassifier.classify('16:48').isAmount, isFalse);
        expect(pkg.AmountClassifier.classify('08:56').isAmount, isFalse);
      });

      test('Date labels are rejected as amounts', () {
        expect(AmountReconstructor.parseAmount('4 September'), isNull);
        expect(AmountReconstructor.parseAmount('3 September'), isNull);
        expect(AmountReconstructor.parseAmount('2 September'), isNull);
        expect(AmountReconstructor.parseAmount('1 September'), isNull);
        expect(AmountReconstructor.parseAmount('2 September 2026 at 2:35 pm'), isNull);
        expect(AmountReconstructor.parseAmount('August 2026'), isNull);
        expect(AmountReconstructor.parseAmount('8 hours ago'), isNull);
        expect(AmountReconstructor.parseAmount('1 day ago'), isNull);
      });

      test('DateExtractor correctly parses relative and absolute dates', () {
        final now = DateTime(2026, 9, 11, 10, 0);

        final d1 = DateExtractor.parseDate('4 September', now: now);
        expect(d1, isNotNull);
        expect(d1!.date.month, equals(9));
        expect(d1.date.day, equals(4));

        final dFull = DateExtractor.parseDate('2 September 2026 at 2:35 pm');
        expect(dFull, isNotNull);
        expect(dFull!.date.year, equals(2026));
        expect(dFull.date.month, equals(9));
        expect(dFull.date.day, equals(2));
        expect(dFull.date.hour, equals(14));
        expect(dFull.date.minute, equals(35));

        final dRel = DateExtractor.parseDate('8 hours ago', now: now);
        expect(dRel, isNotNull);
        expect(dRel!.date.hour, equals(2));
      });
    });

    // -------------------------------------------------------------------------
    // 4. Multi-Line Merchant Grouping
    // -------------------------------------------------------------------------
    group('4. Multi-Line Merchant Grouping', () {
      test('Preserves multi-line merchant "SBI ATM CASH WITHDRAWAL THROUGH UPI"', () {
        final detections = [
          {
            'text': 'SBI ATM CASH WITHDRAWAL',
            'text_normalized': 'SBI ATM CASH WITHDRAWAL',
            'confidence': 0.98,
            'composite_score': 0.98,
            'bbox': [
              [79.0, 625.0],
              [400.0, 625.0],
              [400.0, 645.0],
              [79.0, 645.0],
            ],
          },
          {
            'text': '75,000',
            'text_normalized': '₹5,000',
            'confidence': 0.97,
            'composite_score': 1.66,
            'bbox': [
              [382.0, 624.0],
              [440.0, 624.0],
              [440.0, 642.0],
              [382.0, 642.0],
            ],
          },
          {
            'text': 'THROUGH UPI',
            'text_normalized': 'THROUGH UPI',
            'confidence': 0.96,
            'composite_score': 0.96,
            'bbox': [
              [79.0, 649.0],
              [250.0, 649.0],
              [250.0, 668.0],
              [79.0, 668.0],
            ],
          },
          {
            'text': '2 September',
            'text_normalized': '2 September',
            'confidence': 0.95,
            'composite_score': 0.95,
            'bbox': [
              [78.0, 672.0],
              [200.0, 672.0],
              [200.0, 692.0],
              [78.0, 692.0],
            ],
          },
        ];

        final result = pkg.TransactionGrouper.group(
          detections: detections,
          imgWidth: 462,
          imgHeight: 1024,
        );

        expect(result.transactionCandidates.length, equals(1));
        final tx = result.transactionCandidates.first;
        expect(tx.merchantText, equals('SBI ATM CASH WITHDRAWAL THROUGH UPI'));
        expect(tx.amountValue, equals(5000));
        expect(tx.amountMinorUnits, equals(500000));
        expect(tx.dateText, equals('2 September'));
      });

      test('Preserves long merchant "THE PRABHAT MISTANNA BHANDAR" without truncation', () {
        final detections = [
          {
            'text': 'THE PRABHAT MISTANNA BHANDAR',
            'text_normalized': 'THE PRABHAT MISTANNA BHANDAR',
            'confidence': 0.98,
            'composite_score': 0.98,
            'bbox': [
              [80.0, 321.0],
              [350.0, 321.0],
              [350.0, 340.0],
              [80.0, 340.0],
            ],
          },
          {
            'text': '7205',
            'text_normalized': '₹205',
            'confidence': 0.97,
            'composite_score': 1.18,
            'bbox': [
              [398.0, 319.0],
              [440.0, 319.0],
              [440.0, 337.0],
              [398.0, 337.0],
            ],
          },
          {
            'text': '3 September',
            'text_normalized': '3 September',
            'confidence': 0.95,
            'composite_score': 0.95,
            'bbox': [
              [78.0, 343.0],
              [200.0, 343.0],
              [200.0, 362.0],
              [78.0, 362.0],
            ],
          },
        ];

        final result = pkg.TransactionGrouper.group(
          detections: detections,
          imgWidth: 462,
          imgHeight: 1024,
        );

        expect(result.transactionCandidates.length, equals(1));
        final tx = result.transactionCandidates.first;
        expect(tx.merchantText, equals('THE PRABHAT MISTANNA BHANDAR'));
        expect(tx.amountValue, equals(205));
        expect(tx.amountMinorUnits, equals(20500));
      });
    });

    // -------------------------------------------------------------------------
    // 5. Transaction Type & Direction Detection
    // -------------------------------------------------------------------------
    group('5. Transaction Type & Direction Detection', () {
      test('Detects income signals from positive amount and keywords', () {
        final detIncome1 = [
          {
            'text': 'Received from John Doe',
            'text_normalized': 'Received from John Doe',
            'confidence': 0.98,
            'composite_score': 0.98,
            'bbox': [
              [80.0, 100.0],
              [300.0, 100.0],
              [300.0, 120.0],
              [80.0, 120.0],
            ],
          },
          {
            'text': '+₹1,000',
            'text_normalized': '+₹1,000',
            'confidence': 0.98,
            'composite_score': 1.5,
            'bbox': [
              [380.0, 100.0],
              [440.0, 100.0],
              [440.0, 120.0],
              [380.0, 120.0],
            ],
          },
        ];

        final res1 = pkg.TransactionGrouper.group(
          detections: detIncome1,
          imgWidth: 462,
          imgHeight: 1000,
        );
        expect(res1.transactionCandidates.length, equals(1));
        expect(res1.transactionCandidates.first.transactionType, equals('income'));
      });

      test('Detects expense for standard debit transfers', () {
        final detExpense = [
          {
            'text': 'Paid to Swiggy',
            'text_normalized': 'Paid to Swiggy',
            'confidence': 0.98,
            'composite_score': 0.98,
            'bbox': [
              [80.0, 100.0],
              [300.0, 100.0],
              [300.0, 120.0],
              [80.0, 120.0],
            ],
          },
          {
            'text': '₹349',
            'text_normalized': '₹349',
            'confidence': 0.98,
            'composite_score': 1.5,
            'bbox': [
              [380.0, 100.0],
              [440.0, 100.0],
              [440.0, 120.0],
              [380.0, 120.0],
            ],
          },
        ];

        final res = pkg.TransactionGrouper.group(
          detections: detExpense,
          imgWidth: 462,
          imgHeight: 1000,
        );
        expect(res.transactionCandidates.length, equals(1));
        expect(res.transactionCandidates.first.transactionType, equals('expense'));
      });
    });

    // -------------------------------------------------------------------------
    // 6. Duplicate Detection
    // -------------------------------------------------------------------------
    group('6. Duplicate Detection', () {
      test('Identifies duplicates only when merchant, date, amount, and type align', () async {
        final d = DateTime(2026, 9, 8);
        final existingDb = [
          Transaction(
            id: '1',
            title: 'Swiggy',
            merchant: 'Swiggy',
            amount: 25000,
            currency: 'INR',
            type: TransactionType.expense,
            date: d,
            source: TransactionSource.screenshot,
            createdAt: d,
            updatedAt: d,
          ),
        ];

        final detector = DuplicateDetector(FakeTxRepo(existingDb));

        final candidates = [
          ExtractedTransaction(
            id: 'c1',
            merchant: 'Swiggy',
            amount: 25000,
            date: d,
            type: TransactionType.expense,
          ),
          ExtractedTransaction(
            id: 'c2',
            merchant: 'Zomato', // Different merchant, same amount
            amount: 25000,
            date: d,
            type: TransactionType.expense,
          ),
          ExtractedTransaction(
            id: 'c3',
            merchant: 'Swiggy',
            amount: 25000,
            date: d,
            type: TransactionType.income, // Opposite type (refund/income)
          ),
        ];

        final detected = await detector.detectDuplicates(candidates);

        expect(detected[0].isDuplicate, isTrue);
        expect(detected[0].duplicateSource, equals(DuplicateSource.existingDb));

        expect(detected[1].isDuplicate, isFalse); // Different merchant
        expect(detected[2].isDuplicate, isFalse); // Opposite direction
      });
    });

    // -------------------------------------------------------------------------
    // 7. REAL SCREENSHOT 10-TRANSACTION EXTRACTION VALIDATION
    // -------------------------------------------------------------------------
    group('7. Real Google Pay Screenshot 10-Transaction Extraction Validation', () {
      test('Extracts all 10 transactions accurately with total sum = ₹8,493.00', () async {
        final fixtureFile = _findFixture('screenshot_003_consolidated_ocr.json');
        expect(fixtureFile, isNotNull, reason: 'screenshot_003_consolidated_ocr.json fixture must be present');

        final content = await fixtureFile!.readAsString();
        final fixtureData = jsonDecode(content) as Map<String, dynamic>;

        final rawDetections = (fixtureData['detections'] as List<dynamic>).cast<Map<String, dynamic>>();
        final imgW = fixtureData['width'] as int? ?? 462;
        final imgH = fixtureData['height'] as int? ?? 1024;

        final consolidated = pkg.OcrCandidateConsolidator.consolidate(rawDetections);
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

        final grouperResult = pkg.TransactionGrouper.group(
          detections: grouperInputDets,
          imgWidth: imgW,
          imgHeight: imgH,
        );

        // 1. MUST EXTRACT EXACTLY 10 TRANSACTIONS (Previously only extracted 4)
        expect(grouperResult.transactionCandidates.length, equals(10));

        // 2. VERIFY EACH OF THE 10 TRANSACTIONS IN EXACT ORDER:
        // Tx 1: Hemant Store — ₹20 — 4 September
        final tx1 = grouperResult.transactionCandidates[0];
        expect(tx1.merchantText, equals('HemantStore'));
        expect(tx1.amountMinorUnits, equals(2000));
        expect(tx1.amountValue, equals(20));
        expect(tx1.dateText, contains('September'));

        // Tx 2: THE PRABHAT MISTANNA BHANDAR — ₹205 — 3 September
        final tx2 = grouperResult.transactionCandidates[1];
        expect(tx2.merchantText, equals('THE PRABHAT MISTANNA BHANDAR'));
        expect(tx2.amountMinorUnits, equals(20500));
        expect(tx2.amountValue, equals(205));

        // Tx 3: ABHIJEET KUMAR SINGH — ₹200 — 3 September
        final tx3 = grouperResult.transactionCandidates[2];
        expect(tx3.merchantText, equals('ABHIJEET KUMAR SINGH'));
        expect(tx3.amountMinorUnits, equals(20000));
        expect(tx3.amountValue, equals(200));

        // Tx 4: Om hotel sweet and snacks — ₹75 — 3 September
        final tx4 = grouperResult.transactionCandidates[3];
        expect(tx4.merchantText, equals('Omhotelsweetandsnacks'));
        expect(tx4.amountMinorUnits, equals(7500));
        expect(tx4.amountValue, equals(75));

        // Tx 5: SAPAN KUMAR MANDAL — ₹110 — 2 September
        final tx5 = grouperResult.transactionCandidates[4];
        expect(tx5.merchantText, equals('SAPAN KUMAR MANDAL'));
        expect(tx5.amountMinorUnits, equals(11000));
        expect(tx5.amountValue, equals(110));

        // Tx 6: SBI ATM CASH WITHDRAWAL THROUGH UPI — ₹5,000 — 2 September
        // CRITICAL REGRESSION: Must be 500000 paise (₹5,000), NEVER 75000 or 50 or 5
        final tx6 = grouperResult.transactionCandidates[5];
        expect(tx6.merchantText, contains('SBIATM CASH WITHDRAWAL'));
        expect(tx6.merchantText, contains('THROUGH UPI'));
        expect(tx6.amountMinorUnits, equals(500000));
        expect(tx6.amountValue, equals(5000));
        expect(tx6.amountValue, isNot(equals(75000)));
        expect(tx6.amountMinorUnits, isNot(equals(7500000)));
        expect(tx6.dateText, contains('2September'));

        // Tx 7: M S SATYAM SERVICE STA — ₹2,200 — 2 September 2026 at 2:35 pm
        final tx7 = grouperResult.transactionCandidates[6];
        expect(tx7.merchantText, equals('MS SATYAM SERVICE STA'));
        expect(tx7.amountMinorUnits, equals(220000));
        expect(tx7.amountValue, equals(2200));
        expect(tx7.dateText, contains('2September2026at2:35pm'));

        // Tx 8: POOJA — ₹120 — 2 September
        final tx8 = grouperResult.transactionCandidates[7];
        expect(tx8.merchantText, equals('POOJA'));
        expect(tx8.amountMinorUnits, equals(12000));
        expect(tx8.amountValue, equals(120));

        // Tx 9: Sri Ram store — ₹138 — 1 September
        final tx9 = grouperResult.transactionCandidates[8];
        expect(tx9.merchantText, equals('Sri Ram store'));
        expect(tx9.amountMinorUnits, equals(13800));
        expect(tx9.amountValue, equals(138));

        // Tx 10: VIKASH MUNDHRA — ₹425 — 1 September
        final tx10 = grouperResult.transactionCandidates[9];
        expect(tx10.merchantText, equals('VIKASH MUNDHRA'));
        expect(tx10.amountMinorUnits, equals(42500));
        expect(tx10.amountValue, equals(425));

        // 3. VERIFY TOTAL SUM OF ALL 10 TRANSACTIONS: EXACTLY ₹8,493.00 (849,300 paise)
        final totalMinor = grouperResult.transactionCandidates
            .map((c) => c.amountMinorUnits ?? 0)
            .fold<int>(0, (sum, m) => sum + m);

        expect(totalMinor, equals(849300));
        expect(MoneyUtils.formatMinorUnits(totalMinor), equals('₹8,493.00'));
      });

      test('End-to-end LocalTransactionOcrExtractor with mock engine extracts all 10 domain entities', () async {
        final fixtureFile = _findFixture('screenshot_003_consolidated_ocr.json');
        expect(fixtureFile, isNotNull);

        final content = await fixtureFile!.readAsString();
        final fixtureData = jsonDecode(content) as Map<String, dynamic>;
        final rawDetections = (fixtureData['detections'] as List<dynamic>).cast<Map<String, dynamic>>();
        final imgW = fixtureData['width'] as int? ?? 462;
        final imgH = fixtureData['height'] as int? ?? 1024;

        final consolidated = pkg.OcrCandidateConsolidator.consolidate(rawDetections);
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

        final grouperResult = pkg.TransactionGrouper.group(
          detections: grouperInputDets,
          imgWidth: imgW,
          imgHeight: imgH,
        );

        final tempDir = Directory.systemTemp.createTempSync('e2e_test');
        final fakeFile = File('${tempDir.path}/gpay_10tx.png')..writeAsBytesSync([1, 2, 3, 4]);

        final mockEngine = FakeOcrEngine(handler: (bytes, filename) {
          return pkg.OcrResult(
            success: true,
            filename: filename,
            width: imgW,
            height: imgH,
            engine: 'RapidOCR-ONNX-Mobile',
            itemsCount: consolidated.length,
            items: const [],
            pipelineVersion: 'V2',
            transactionCandidates: grouperResult.transactionCandidates,
            transactionCandidatesCount: grouperResult.transactionCandidates.length,
          );
        });

        final ocrService = pkg.TransactionOcr(engine: mockEngine);
        final extractor = LocalTransactionOcrExtractor(
          ocrService: ocrService,
          fallbackParser: RuleBasedTransactionParser(),
        );

        final result = await extractor.extractTransactions([fakeFile.path]);

        expect(result.successfulImages, contains(fakeFile.path));
        expect(result.transactions.length, equals(10));

        final totalPaise = result.transactions.map((t) => t.amount ?? 0).fold<int>(0, (s, a) => s + a);
        expect(totalPaise, equals(849300));
        expect(MoneyUtils.formatMinorUnits(totalPaise), equals('₹8,493.00'));

        // Verify Debug Inspector payload is populated and structured
        expect(result.debugOcrText, isNotNull);
        expect(result.debugOcrText, contains('SCREENSHOT 1: gpay_10tx.png'));
        expect(result.debugOcrText, contains('CANDIDATE TRANSACTIONS (10)'));
        expect(result.debugOcrText, contains('SBIATM CASH WITHDRAWAL THROUGH UPI'));

        tempDir.deleteSync(recursive: true);
      });
    });
  });
}
