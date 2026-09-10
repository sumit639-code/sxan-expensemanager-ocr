import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:expense_app/features/import/data/datasources/ocr_api_config.dart';
import 'package:expense_app/features/import/data/datasources/python_ocr_api.dart';
import 'package:expense_app/features/settings/domain/entities/app_settings.dart';

void main() {
  group('PythonOcrApi Unit Tests', () {
    const config = OcrApiConfig(baseUrl: 'http://127.0.0.1:8000');

    test('1. Health check returns true on {"status": "ok"}', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.toString(), equals('http://127.0.0.1:8000/health'));
        expect(request.method, equals('GET'));
        return http.Response(
          jsonEncode({'status': 'ok', 'service': 'expense-ocr'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final api = PythonOcrApi(config: config, client: mockClient);
      final isHealthy = await api.checkHealth();
      expect(isHealthy, isTrue);
    });

    test('2. Health check returns false on non-200 or failure status', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'status': 'degraded'}),
          503,
        );
      });

      final api = PythonOcrApi(config: config, client: mockClient);
      final isHealthy = await api.checkHealth();
      expect(isHealthy, isFalse);
    });

    test('3. Extract V1 from image sends multipart POST to /extract and parses response', () async {
      // Create a temporary dummy image file
      final tempDir = await Directory.systemTemp.createTemp('scanex_test_');
      final tempFile = File('${tempDir.path}/test_screenshot.png');
      await tempFile.writeAsBytes([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);

      const v1Config = OcrApiConfig(
        baseUrl: 'http://127.0.0.1:8000',
        apiVersion: PythonApiVersion.v1,
      );

      final mockClient = MockClient((request) async {
        expect(request.url.toString(), equals('http://127.0.0.1:8000/extract'));
        expect(request.method, equals('POST'));

        final jsonResponse = {
          'success': true,
          'filename': 'test_screenshot.png',
          'items': [
            {
              'reading_index': 1,
              'text': 'ASHISH KUMAR NAYAK',
              'text_normalized': 'ASHISH KUMAR NAYAK',
              'composite_score': 0.98,
              'bbox': [
                [90, 150],
                [350, 150],
                [350, 175],
                [90, 175]
              ],
              'is_numeric_amount': false,
            },
            {
              'reading_index': 2,
              'text': '₹40',
              'text_normalized': '₹40',
              'composite_score': 0.95,
              'bbox': [
                [550, 150],
                [620, 150],
                [620, 175],
                [550, 175]
              ],
              'is_numeric_amount': true,
              'parsed_integer_amount': 40,
              'currency': 'INR',
            },
            {
              'reading_index': 3,
              'text': '7 September',
              'text_normalized': '7 September',
              'composite_score': 0.92,
              'bbox': [
                [90, 180],
                [230, 180],
                [230, 200],
                [90, 200]
              ],
              'is_numeric_amount': false,
            }
          ]
        };

        return http.Response(
          jsonEncode(jsonResponse),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final api = PythonOcrApi(config: v1Config, client: mockClient);
      final response = await api.extractFromImage(tempFile.path);

      expect(response.success, isTrue);
      expect(response.filename, equals('test_screenshot.png'));
      expect(response.items.length, equals(3));
      expect(response.items[0].text, equals('ASHISH KUMAR NAYAK'));
      expect(response.items[1].isNumericAmount, isTrue);
      expect(response.items[1].parsedIntegerAmount, equals(40));
      expect(response.items[1].boundingBox, isNotNull);
      expect(response.items[1].boundingBox!.left, equals(550));

      await tempDir.delete(recursive: true);
    });

    test('4. Extract V2 from image sends multipart POST to /extract/v2 with candidates', () async {
      final tempDir = await Directory.systemTemp.createTemp('scanex_test_v2_');
      final tempFile = File('${tempDir.path}/test_screenshot.png');
      await tempFile.writeAsBytes([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);

      const v2Config = OcrApiConfig(
        baseUrl: 'http://127.0.0.1:8000',
        apiVersion: PythonApiVersion.v2,
      );

      final mockClient = MockClient((request) async {
        expect(request.url.toString(), equals('http://127.0.0.1:8000/extract/v2'));
        expect(request.method, equals('POST'));

        final jsonResponse = {
          'success': true,
          'filename': 'test_screenshot.png',
          'transaction_candidates': [
            {
              'id': 'cand_1',
              'amount': 4000,
              'currency': 'INR',
              'merchant': 'ASHISH KUMAR NAYAK',
              'title': 'Paid to Ashish',
              'date': '2026-09-07T10:30:00.000Z',
              'type': 'expense',
              'confidence': 0.96,
              'category': 'food',
            }
          ],
          'tokens': [
            {
              'reading_index': 1,
              'text': 'ASHISH KUMAR NAYAK',
              'token_type': 'MERCHANT',
              'composite_score': 0.98,
            },
            {
              'reading_index': 2,
              'text': '₹40.00',
              'token_type': 'AMOUNT',
              'composite_score': 0.95,
              'is_numeric_amount': true,
              'parsed_integer_amount': 4000,
            }
          ]
        };

        return http.Response(
          jsonEncode(jsonResponse),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final api = PythonOcrApi(config: v2Config, client: mockClient);
      final response = await api.extractFromImage(tempFile.path);

      expect(response.success, isTrue);
      expect(response.transactionCandidates.length, equals(1));
      expect(response.transactionCandidates.first.merchant, equals('ASHISH KUMAR NAYAK'));
      expect(response.transactionCandidates.first.amount, equals(4000));
      expect(response.items.length, equals(2));
      expect(response.items[0].tokenType, equals('MERCHANT'));

      await tempDir.delete(recursive: true);
    });

    test('5. testEndpoint returns latency and status', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'status': 'ok', 'version': '2.0.0'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final api = PythonOcrApi(config: config, client: mockClient);
      final result = await api.testEndpoint();

      expect(result.success, isTrue);
      expect(result.statusCode, equals(200));
      expect(result.latencyMs, isNonNegative);
    });

    test('6. Extract throws PythonOcrApiException on HTTP 500 error', () async {
      final tempDir = await Directory.systemTemp.createTemp('scanex_test_');
      final tempFile = File('${tempDir.path}/test_screenshot.png');
      await tempFile.writeAsBytes([1, 2, 3]);

      final mockClient = MockClient((request) async {
        return http.Response('Internal Server Error in OCR model', 500);
      });

      final api = PythonOcrApi(config: config, client: mockClient);
      expect(
        () => api.extractFromImage(tempFile.path),
        throwsA(isA<PythonOcrApiException>()),
      );

      await tempDir.delete(recursive: true);
    });

    test('7. Extract throws PythonOcrApiException when file does not exist', () async {
      final api = PythonOcrApi(config: config);
      expect(
        () => api.extractFromImage('non_existent_path.png'),
        throwsA(isA<PythonOcrApiException>()),
      );
    });
  });
}
