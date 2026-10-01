import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:expense_app/features/import/data/parser/rule_based_transaction_parser.dart';
import 'package:expense_app/features/import/data/services/local_transaction_ocr_extractor.dart';
import 'package:expense_app/shared/enums/transaction_enums.dart';

import 'package:transaction_ocr_flutter/transaction_ocr_flutter.dart' as pkg;

class MockOcrEngine implements pkg.OcrEngine {
  final pkg.OcrResult Function(Uint8List bytes, String filename) onExtract;
  bool _initialized = false;
  bool _disposed = false;

  MockOcrEngine({required this.onExtract});

  @override
  String get engineName => 'MockOcrEngine';

  @override
  Future<void> initialize() async {
    _initialized = true;
  }

  @override
  bool get isInitialized => _initialized;

  bool get isDisposed => _disposed;

  @override
  Future<pkg.OcrResult> extractImage(
    Uint8List imageBytes, {
    String filename = 'screenshot.png',
    pkg.OcrProgressCallback? onProgress,
    int currentImage = 1,
    int totalImages = 1,
  }) async {
    onProgress?.call(currentImage, totalImages, 'Extracting', 1.0);
    return onExtract(imageBytes, filename);
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalTransactionOcrExtractor & transaction_ocr_flutter V2 Tests', () {
    test('1. Converts pkg.OcrItem list to OcrDocument preserving bounding boxes and scores', () {
      final items = [
        pkg.OcrItem(
          readingIndex: 1,
          text: 'Hemant Store',
          textNormalized: 'Hemant Store',
          compositeScore: 0.98,
          confidence: 0.98,
          bbox: pkg.BoundingBox.fromPoints([
            [90.0, 100.0],
            [300.0, 100.0],
            [300.0, 125.0],
            [90.0, 125.0],
          ]),
          isNumericAmount: false,
        ),
        pkg.OcrItem(
          readingIndex: 2,
          text: 'R20',
          textNormalized: '₹20',
          compositeScore: 0.99,
          confidence: 0.95,
          bbox: pkg.BoundingBox.fromPoints([
            [550.0, 100.0],
            [630.0, 100.0],
            [630.0, 125.0],
            [550.0, 125.0],
          ]),
          isNumericAmount: true,
          parsedIntegerAmount: 20,
          currency: 'INR',
        ),
      ];

      final doc = LocalTransactionOcrExtractor.convertToOcrDocument(
        items,
        imagePath: 'screenshot1.png',
        imageWidth: 720,
        imageHeight: 1600,
      );

      expect(doc.lines.length, equals(2));
      expect(doc.lines[0].text, equals('Hemant Store'));
      expect(doc.lines[0].boundingBox, equals(const Rect.fromLTRB(90, 100, 300, 125)));
      expect(doc.lines[1].text, equals('₹20'));
      expect(doc.lines[1].boundingBox, equals(const Rect.fromLTRB(550, 100, 630, 125)));
    });

    test('2. AmountClassifier and Grouper correctly normalize symbols and extract transactions', () {
      final amt1 = pkg.AmountClassifier.classify('₹5,000');
      expect(amt1.isAmount, isTrue);
      expect(amt1.parsedValue, equals(5000));

      final amt2 = pkg.AmountClassifier.classify('R20');
      expect(amt2.isAmount, isTrue);
      expect(amt2.parsedValue, equals(20));

      final amt3 = pkg.AmountClassifier.classify(
        '₹200.90',
        bbox: pkg.BoundingBox.fromPoints([
          [550.0, 100.0],
          [650.0, 100.0],
          [650.0, 125.0],
          [550.0, 125.0],
        ]),
        imgWidth: 720,
        imgHeight: 1600,
      );
      expect(amt3.isAmount, isTrue);
      expect(amt3.parsedValue, equals(200.90));

      // Indian numbering format (1.5 Lakhs)
      final amtIndian = pkg.AmountClassifier.classify('₹1,50,000');
      expect(amtIndian.isAmount, isTrue);
      expect(amtIndian.parsedValue, equals(150000));

      final amtIndianDecimal = pkg.AmountClassifier.classify('₹12,50,000.50');
      expect(amtIndianDecimal.isAmount, isTrue);
      expect(amtIndianDecimal.parsedValue, equals(1250000.50));

      // Misread symbols
      final amtMisread1 = pkg.AmountClassifier.classify('Rs. 500');
      expect(amtMisread1.isAmount, isTrue);
      expect(amtMisread1.parsedValue, equals(500));

      final amtMisread2 = pkg.AmountClassifier.classify('z5,000');
      expect(amtMisread2.isAmount, isTrue);
      expect(amtMisread2.parsedValue, equals(5000));

      final amtMisread3 = pkg.AmountClassifier.classify('?500');
      expect(amtMisread3.isAmount, isTrue);
      expect(amtMisread3.parsedValue, equals(500));

      final amtMisread4 = pkg.AmountClassifier.classify('7205');
      expect(amtMisread4.isAmount, isTrue);
      expect(amtMisread4.parsedValue, equals(205));

      final amtMisread5 = pkg.AmountClassifier.classify('F5,000');
      expect(amtMisread5.isAmount, isTrue);
      expect(amtMisread5.parsedValue, equals(5000));

      // Rejection of noise (time labels, date labels)
      final timeRes = pkg.AmountClassifier.classify('16:48');
      expect(timeRes.isAmount, isFalse);

      final dateLabelRes = pkg.AmountClassifier.classify('4 September');
      expect(dateLabelRes.isAmount, isFalse);

      // Direct Grouper test with detections
      final detections = [
        {
          'text': 'Hemant Store',
          'text_normalized': 'Hemant Store',
          'confidence': 0.98,
          'composite_score': 0.98,
          'bbox': [
            [90.0, 300.0],
            [300.0, 300.0],
            [300.0, 325.0],
            [90.0, 325.0],
          ],
        },
        {
          'text': '4 September',
          'text_normalized': '4 September',
          'confidence': 0.95,
          'composite_score': 0.95,
          'bbox': [
            [90.0, 330.0],
            [250.0, 330.0],
            [250.0, 350.0],
            [90.0, 350.0],
          ],
        },
        {
          'text': 'R20',
          'text_normalized': '₹20',
          'confidence': 0.97,
          'composite_score': 1.52,
          'bbox': [
            [550.0, 300.0],
            [630.0, 300.0],
            [630.0, 325.0],
            [550.0, 325.0],
          ],
        },
        {
          'text': 'SBI ATM CASH WITHDRAWAL',
          'text_normalized': 'SBI ATM CASH WITHDRAWAL',
          'confidence': 0.97,
          'composite_score': 0.97,
          'bbox': [
            [90.0, 400.0],
            [400.0, 400.0],
            [400.0, 425.0],
            [90.0, 425.0],
          ],
        },
        {
          'text': '2 September',
          'text_normalized': '2 September',
          'confidence': 0.95,
          'composite_score': 0.95,
          'bbox': [
            [90.0, 430.0],
            [250.0, 430.0],
            [250.0, 450.0],
            [90.0, 450.0],
          ],
        },
        {
          'text': '75,000',
          'text_normalized': '₹5,000',
          'confidence': 0.96,
          'composite_score': 1.66,
          'bbox': [
            [550.0, 400.0],
            [650.0, 400.0],
            [650.0, 425.0],
            [550.0, 425.0],
          ],
        },
      ];

      final groupResult = pkg.TransactionGrouper.group(
        detections: detections,
        imgWidth: 720,
        imgHeight: 1600,
      );

      expect(groupResult.transactionCandidates.length, equals(2));
      expect(groupResult.transactionCandidates[0].merchantText, equals('Hemant Store'));
      expect(groupResult.transactionCandidates[0].amountValue, equals(20));

      expect(groupResult.transactionCandidates[1].merchantText, contains('SBI ATM CASH WITHDRAWAL'));
      expect(groupResult.transactionCandidates[1].amountValue, equals(5000));
    });

    test('3. LocalTransactionOcrExtractor maps V2 transaction candidates to app entities with exact minor units (paise)', () async {
      final tempDir = Directory.systemTemp.createTempSync('ocr_test');
      final testFile = File('${tempDir.path}/gpay_test.png')..writeAsBytesSync([0x89, 0x50, 0x4E, 0x47]);

      final mockEngine = MockOcrEngine(
        onExtract: (bytes, filename) {
          return pkg.OcrResult(
            success: true,
            filename: filename,
            width: 720,
            height: 1600,
            engine: 'RapidOCR-ONNX-Mobile',
            itemsCount: 4,
            items: const [],
            pipelineVersion: 'V2',
            transactionCandidates: const [
              pkg.ExtractedTransaction(
                amountTextRaw: '₹200.90',
                amountTextNormalized: '₹200.90',
                amountValue: 200.90,
                amountConfidence: 0.98,
                merchantText: 'Swiggy',
                dateText: '1 September 2026',
                groupingConfidence: 0.95,
              ),
              pkg.ExtractedTransaction(
                amountTextRaw: '75,000',
                amountTextNormalized: '₹5,000',
                amountValue: 5000,
                amountConfidence: 0.96,
                merchantText: 'SBI ATM',
                dateText: '2 September 2026',
                groupingConfidence: 0.92,
              ),
            ],
            transactionCandidatesCount: 2,
          );
        },
      );

      final ocrService = pkg.TransactionOcr(engine: mockEngine);
      final extractor = LocalTransactionOcrExtractor(
        ocrService: ocrService,
        fallbackParser: RuleBasedTransactionParser(),
      );

      final result = await extractor.extractTransactions([testFile.path]);

      expect(result.successfulImages, contains(testFile.path));
      expect(result.failedImages, isEmpty);
      expect(result.transactions.length, equals(2));

      // Check transaction 1 (Decimal paise precision: 200.90 -> 20090 paise)
      final tx1 = result.transactions[0];
      expect(tx1.merchant, equals('Swiggy'));
      expect(tx1.amount, equals(20090)); // ₹200.90 -> 20090 paise
      expect(tx1.currency, equals('INR'));
      expect(tx1.type, equals(TransactionType.expense));
      expect(tx1.sourceReference, equals('gpay_test.png'));

      // Check transaction 2 (₹5,000 -> 500000 paise)
      final tx2 = result.transactions[1];
      expect(tx2.merchant, equals('SBI ATM'));
      expect(tx2.amount, equals(500000)); // ₹5,000 -> 500000 paise
      expect(tx2.currency, equals('INR'));

      tempDir.deleteSync(recursive: true);
    });

    test('4. LocalTransactionOcrExtractor handles empty OCR results gracefully', () async {
      final tempDir = Directory.systemTemp.createTempSync('ocr_test_empty');
      final testFile = File('${tempDir.path}/empty.png')..writeAsBytesSync([0x89, 0x50, 0x4E, 0x47]);

      final mockEngine = MockOcrEngine(
        onExtract: (bytes, filename) {
          return pkg.OcrResult(
            success: true,
            filename: filename,
            width: 720,
            height: 1600,
            engine: 'RapidOCR-ONNX-Mobile',
            itemsCount: 0,
            items: const [],
            pipelineVersion: 'V2',
            transactionCandidates: const [],
            transactionCandidatesCount: 0,
          );
        },
      );

      final ocrService = pkg.TransactionOcr(engine: mockEngine);
      final extractor = LocalTransactionOcrExtractor(
        ocrService: ocrService,
        fallbackParser: RuleBasedTransactionParser(),
      );

      final result = await extractor.extractTransactions([testFile.path]);
      expect(result.transactions, isEmpty);
      expect(result.failedImages, contains(testFile.path));
      expect(result.errors.first, contains('No recognizable transactions found'));

      tempDir.deleteSync(recursive: true);
    });

    test('5. Parses compact dates like "1August" and "3August" accurately without defaulting to today', () async {
      final tempDir = Directory.systemTemp.createTempSync('ocr_test_compact_dates');
      final testFile = File('${tempDir.path}/august_test.png')..writeAsBytesSync([0x89, 0x50, 0x4E, 0x47]);

      final mockEngine = MockOcrEngine(
        onExtract: (bytes, filename) {
          return pkg.OcrResult(
            success: true,
            filename: filename,
            width: 462,
            height: 1024,
            engine: 'RapidOCR-ONNX-Mobile',
            itemsCount: 6,
            items: const [],
            pipelineVersion: 'V2',
            transactionCandidates: const [
              pkg.ExtractedTransaction(
                amountTextRaw: '₹160',
                amountTextNormalized: '₹160',
                amountValue: 160,
                amountMinorUnits: 16000,
                amountConfidence: 0.95,
                merchantText: 'MsSatyam ServiceStatio',
                dateText: '3August',
                transactionType: 'expense',
                groupingConfidence: 0.95,
              ),
              pkg.ExtractedTransaction(
                amountTextRaw: '₹40',
                amountTextNormalized: '₹40',
                amountValue: 40,
                amountMinorUnits: 4000,
                amountConfidence: 0.95,
                merchantText: 'SAI HANUMANT FOODS',
                dateText: '1August',
                transactionType: 'expense',
                groupingConfidence: 0.95,
              ),
            ],
            transactionCandidatesCount: 2,
          );
        },
      );

      final ocrService = pkg.TransactionOcr(engine: mockEngine);
      final extractor = LocalTransactionOcrExtractor(ocrService: ocrService);

      final result = await extractor.extractTransactions([testFile.path]);
      expect(result.transactions.length, equals(2));

      final tx1 = result.transactions[0];
      expect(tx1.date?.month, equals(8));
      expect(tx1.date?.day, equals(3));

      final tx2 = result.transactions[1];
      expect(tx2.date?.month, equals(8));
      expect(tx2.date?.day, equals(1));

      tempDir.deleteSync(recursive: true);
    });

    test('6. Contextually inherits date from neighboring transaction when a transaction date is cut off', () async {
      final tempDir = Directory.systemTemp.createTempSync('ocr_test_cutoff_date');
      final testFile = File('${tempDir.path}/cutoff_test.png')..writeAsBytesSync([0x89, 0x50, 0x4E, 0x47]);

      final mockEngine = MockOcrEngine(
        onExtract: (bytes, filename) {
          return pkg.OcrResult(
            success: true,
            filename: filename,
            width: 462,
            height: 1024,
            engine: 'RapidOCR-ONNX-Mobile',
            itemsCount: 4,
            items: const [],
            pipelineVersion: 'V2',
            transactionCandidates: const [
              pkg.ExtractedTransaction(
                amountTextRaw: '₹50',
                amountTextNormalized: '₹50',
                amountValue: 50,
                amountMinorUnits: 5000,
                amountConfidence: 0.95,
                merchantText: 'RAJ DESHLAHRE',
                dateText: '1August',
                transactionType: 'expense',
                groupingConfidence: 0.95,
              ),
              pkg.ExtractedTransaction(
                amountTextRaw: '₹30',
                amountTextNormalized: '₹30',
                amountValue: 30,
                amountMinorUnits: 3000,
                amountConfidence: 0.90,
                merchantText: 'NEW BAL DHABA',
                dateText: null, // Cut off at screen edge
                warnings: ['Date not detected'],
                transactionType: 'expense',
                groupingConfidence: 0.85,
              ),
            ],
            transactionCandidatesCount: 2,
          );
        },
      );

      final ocrService = pkg.TransactionOcr(engine: mockEngine);
      final extractor = LocalTransactionOcrExtractor(ocrService: ocrService);

      final result = await extractor.extractTransactions([testFile.path]);
      expect(result.transactions.length, equals(2));

      final tx1 = result.transactions[0];
      expect(tx1.date?.month, equals(8));
      expect(tx1.date?.day, equals(1));

      final tx2 = result.transactions[1];
      // Inherited from preceding August transaction instead of defaulting to today!
      expect(tx2.date?.month, equals(8));
      expect(tx2.date?.day, equals(1));
      // 'Date not detected' warning should be cleared
      expect(tx2.note, isNull);

      tempDir.deleteSync(recursive: true);
    });
  });
}
