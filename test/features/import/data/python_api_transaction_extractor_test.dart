import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:expense_app/features/import/data/datasources/ocr_api_config.dart';
import 'package:expense_app/features/import/data/datasources/python_ocr_api.dart';
import 'package:expense_app/features/import/data/parser/python_ocr_transaction_parser.dart';
import 'package:expense_app/features/import/data/services/python_api_transaction_extractor.dart';

void main() {
  group('PythonApiTransactionExtractor Integration Tests', () {
    late Directory tempDir;
    late File file1;
    late File file2;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('scanex_extractor_test_');
      file1 = File('${tempDir.path}/screenshot_1.png');
      file2 = File('${tempDir.path}/screenshot_2.png');
      await file1.writeAsBytes([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
      await file2.writeAsBytes([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('1. Multi-screenshot sequential batch extraction succeeds', () async {
      int requestCount = 0;

      final mockClient = MockClient((request) async {
        requestCount++;
        final isFirst = requestCount == 1;

        final items = isFirst
            ? [
                {
                  'reading_index': 1,
                  'text': 'ASHISH KUMAR NAYAK',
                  'bbox': [[90, 100], [350, 100], [350, 125], [90, 125]],
                },
                {
                  'reading_index': 2,
                  'text': '₹40',
                  'bbox': [[550, 100], [620, 100], [620, 125], [550, 125]],
                },
                {
                  'reading_index': 3,
                  'text': '7 September',
                  'bbox': [[90, 130], [230, 130], [230, 150], [90, 150]],
                },
              ]
            : [
                {
                  'reading_index': 1,
                  'text': 'JIO',
                  'bbox': [[90, 100], [160, 100], [160, 125], [90, 125]],
                },
                {
                  'reading_index': 2,
                  'text': '₹349',
                  'bbox': [[550, 100], [630, 100], [630, 125], [550, 125]],
                },
                {
                  'reading_index': 3,
                  'text': '6 September',
                  'bbox': [[90, 130], [230, 130], [230, 150], [90, 150]],
                },
              ];

        return http.Response(
          jsonEncode({
            'success': true,
            'filename': isFirst ? 'screenshot_1.png' : 'screenshot_2.png',
            'items': items,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final api = PythonOcrApi(
        config: const OcrApiConfig(baseUrl: 'http://127.0.0.1:8000'),
        client: mockClient,
      );

      final extractor = PythonApiTransactionExtractor(
        api: api,
        parser: PythonOcrTransactionParser(),
      );

      final progressSteps = <String>[];
      final result = await extractor.extractTransactions(
        [file1.path, file2.path],
        onProgress: (step, progress) => progressSteps.add(step),
      );

      expect(result.successfulImages.length, equals(2));
      expect(result.failedImages, isEmpty);
      expect(result.transactions.length, equals(2));
      expect(result.transactions[0].merchant, equals('ASHISH KUMAR NAYAK'));
      expect(result.transactions[0].amount, equals(4000));
      expect(result.transactions[1].merchant, equals('JIO'));
      expect(result.transactions[1].amount, equals(34900));
      expect(progressSteps.isNotEmpty, isTrue);
    });

    test('2. Handles connection failure with user-friendly error', () async {
      final mockClient = MockClient((request) async {
        throw const SocketException('Connection refused');
      });

      final api = PythonOcrApi(
        config: const OcrApiConfig(baseUrl: 'http://127.0.0.1:8000'),
        client: mockClient,
      );

      final extractor = PythonApiTransactionExtractor(api: api);

      final result = await extractor.extractTransactions([file1.path]);

      expect(result.successfulImages, isEmpty);
      expect(result.failedImages.length, equals(1));
      expect(result.transactions, isEmpty);
      expect(result.errors.first, contains('Couldn\'t connect to the OCR service'));
    });

    test('3. Returns empty result when imagePaths is empty', () async {
      final api = PythonOcrApi();
      final extractor = PythonApiTransactionExtractor(api: api);

      final result = await extractor.extractTransactions([]);
      expect(result.transactions, isEmpty);
      expect(result.errors.first, contains('No screenshot images selected'));
    });
  });
}
