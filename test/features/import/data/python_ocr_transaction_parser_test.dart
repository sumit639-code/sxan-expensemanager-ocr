import 'package:flutter_test/flutter_test.dart';

import 'package:expense_app/features/import/data/models/python_ocr_response.dart';
import 'package:expense_app/features/import/data/parser/python_ocr_transaction_parser.dart';
import 'package:expense_app/shared/enums/transaction_enums.dart';

void main() {
  late PythonOcrTransactionParser parser;

  setUp(() {
    parser = PythonOcrTransactionParser();
  });

  group('PythonOcrTransactionParser Unit Tests', () {
    test('1. Parses Google Pay list fixture with 2D spatial bounding boxes', () {
      final jsonResponse = {
        'success': true,
        'filename': 'gpay_screenshot.png',
        'items': [
          // UI Chrome (Status, Search)
          {
            'reading_index': 1,
            'text': 'Search transactions',
            'bbox': [[100, 50], [400, 50], [400, 80], [100, 80]],
          },
          // Row 1: Ashish Kumar Nayak, 7 September, ₹40
          {
            'reading_index': 2,
            'text': 'A',
            'bbox': [[40, 150], [70, 150], [70, 180], [40, 180]],
          },
          {
            'reading_index': 3,
            'text': 'ASHISH KUMAR NAYAK',
            'text_normalized': 'ASHISH KUMAR NAYAK',
            'composite_score': 0.98,
            'bbox': [[90, 145], [380, 145], [380, 170], [90, 170]],
          },
          {
            'reading_index': 4,
            'text': '₹40',
            'text_normalized': '₹40',
            'composite_score': 0.95,
            'bbox': [[550, 145], [620, 145], [620, 170], [550, 170]],
            'is_numeric_amount': true,
            'parsed_integer_amount': 40,
          },
          {
            'reading_index': 5,
            'text': '7 September',
            'text_normalized': '7 September',
            'composite_score': 0.92,
            'bbox': [[90, 175], [230, 175], [230, 195], [90, 195]],
          },

          // Row 2: JIO, 6 September, ₹349
          {
            'reading_index': 6,
            'text': 'J',
            'bbox': [[40, 220], [70, 220], [70, 250], [40, 250]],
          },
          {
            'reading_index': 7,
            'text': 'JIO',
            'text_normalized': 'JIO',
            'composite_score': 0.99,
            'bbox': [[90, 215], [160, 215], [160, 240], [90, 240]],
          },
          {
            'reading_index': 8,
            'text': '₹349',
            'text_normalized': '₹349',
            'composite_score': 0.96,
            'bbox': [[550, 215], [630, 215], [630, 240], [550, 240]],
            'is_numeric_amount': true,
            'parsed_integer_amount': 349,
          },
          {
            'reading_index': 9,
            'text': '6 September',
            'text_normalized': '6 September',
            'bbox': [[90, 245], [230, 245], [230, 265], [90, 265]],
          },

          // Row 3: Bishal BhanjDeo, 5 September, ₹2,500
          {
            'reading_index': 10,
            'text': 'Bishal BhanjDeo',
            'composite_score': 0.97,
            'bbox': [[90, 285], [300, 285], [300, 310], [90, 310]],
          },
          {
            'reading_index': 11,
            'text': '₹2,500',
            'composite_score': 0.98,
            'bbox': [[550, 285], [640, 285], [640, 310], [550, 310]],
            'is_numeric_amount': true,
            'parsed_integer_amount': 2500,
          },
          {
            'reading_index': 12,
            'text': '5 September',
            'bbox': [[90, 315], [230, 315], [230, 335], [90, 335]],
          },

          // Row 4: THE PRABHAT MISTANNA BHANDAR, 3 September, ₹205
          {
            'reading_index': 13,
            'text': 'THE PRABHAT MISTANNA BHANDAR',
            'composite_score': 0.95,
            'bbox': [[90, 355], [450, 355], [450, 380], [90, 380]],
          },
          {
            'reading_index': 14,
            'text': '₹205',
            'composite_score': 0.96,
            'bbox': [[550, 355], [630, 355], [630, 380], [550, 380]],
            'is_numeric_amount': true,
            'parsed_integer_amount': 205,
          },
          {
            'reading_index': 15,
            'text': '3 September',
            'bbox': [[90, 385], [230, 385], [230, 405], [90, 405]],
          },
        ]
      };

      final response = PythonOcrResponse.fromJson(jsonResponse);
      final results = parser.parseResponse(response);

      expect(results.length, equals(4));

      // 1. Ashish Kumar Nayak: ₹40 = 4000 paise (NOT 740!)
      expect(results[0].merchant, equals('ASHISH KUMAR NAYAK'));
      expect(results[0].amount, equals(4000));
      expect(results[0].type, equals(TransactionType.expense));
      expect(results[0].date?.day, equals(7));
      expect(results[0].date?.month, equals(9));

      // 2. Jio: ₹349 = 34900 paise (NOT 7349!)
      expect(results[1].merchant, equals('JIO'));
      expect(results[1].amount, equals(34900));
      expect(results[1].categoryId, equals('bills'));
      expect(results[1].date?.day, equals(6));

      // 3. Bishal: ₹2,500 = 250000 paise (NOT 22500!)
      expect(results[2].merchant, equals('Bishal BhanjDeo'));
      expect(results[2].amount, equals(250000));
      expect(results[2].date?.day, equals(5));

      // 4. Prabhat: ₹205 = 20500 paise (NOT 7205!)
      expect(results[3].merchant, equals('THE PRABHAT MISTANNA BHANDAR'));
      expect(results[3].amount, equals(20500));
      expect(results[3].date?.day, equals(3));
    });

    test('2. Preserves exact decimal amounts in minor units (paise)', () {
      final jsonResponse = {
        'success': true,
        'filename': 'decimals.png',
        'items': [
          {
            'reading_index': 1,
            'text': 'Swiggy',
            'bbox': [[90, 100], [250, 100], [250, 130], [90, 130]],
          },
          {
            'reading_index': 2,
            'text': '₹200.90',
            'bbox': [[550, 100], [650, 100], [650, 130], [550, 130]],
          },
          {
            'reading_index': 3,
            'text': '18 May',
            'bbox': [[90, 135], [200, 135], [200, 155], [90, 155]],
          },
          {
            'reading_index': 4,
            'text': 'Amazon Pay',
            'bbox': [[90, 200], [280, 200], [280, 230], [90, 230]],
          },
          {
            'reading_index': 5,
            'text': '+ ₹3,700.97',
            'bbox': [[550, 200], [680, 200], [680, 230], [550, 230]],
          },
          {
            'reading_index': 6,
            'text': '17 May',
            'bbox': [[90, 235], [200, 235], [200, 255], [90, 255]],
          },
        ]
      };

      final response = PythonOcrResponse.fromJson(jsonResponse);
      final results = parser.parseResponse(response);

      expect(results.length, equals(2));

      // ₹200.90 -> 20090 paise
      expect(results[0].merchant, equals('Swiggy'));
      expect(results[0].amount, equals(20090));
      expect(results[0].type, equals(TransactionType.expense));

      // + ₹3,700.97 -> 370097 paise (Income)
      expect(results[1].merchant, equals('Amazon Pay'));
      expect(results[1].amount, equals(370097));
      expect(results[1].type, equals(TransactionType.income));
    });

    test('3. Filters timestamps (16:48, 08:56), date numbers, and totals from being amounts', () {
      final jsonResponse = {
        'success': true,
        'filename': 'status_bar.png',
        'items': [
          {
            'reading_index': 1,
            'text': '08:56',
            'bbox': [[20, 20], [80, 20], [80, 40], [20, 40]],
            'is_numeric_amount': true,
            'parsed_integer_amount': 856,
          },
          {
            'reading_index': 2,
            'text': 'Available Balance',
            'bbox': [[100, 100], [300, 100], [300, 130], [100, 130]],
          },
          {
            'reading_index': 3,
            'text': '₹24,580',
            'bbox': [[550, 100], [650, 100], [650, 130], [550, 130]],
          },
          {
            'reading_index': 4,
            'text': 'Total Spent: ₹1,719',
            'bbox': [[100, 150], [400, 150], [400, 180], [100, 180]],
          },
          {
            'reading_index': 5,
            'text': 'SAPAN KUMAR MANDAL',
            'bbox': [[90, 250], [380, 250], [380, 280], [90, 280]],
          },
          {
            'reading_index': 6,
            'text': '₹110',
            'bbox': [[550, 250], [620, 250], [620, 280], [550, 280]],
          },
          {
            'reading_index': 7,
            'text': '2 September',
            'bbox': [[90, 285], [230, 285], [230, 305], [90, 305]],
          },
        ]
      };

      final response = PythonOcrResponse.fromJson(jsonResponse);
      final results = parser.parseResponse(response);

      // Only SAPAN KUMAR MANDAL should be extracted. Balance, Total, and 08:56 are rejected!
      expect(results.length, equals(1));
      expect(results[0].merchant, equals('SAPAN KUMAR MANDAL'));
      expect(results[0].amount, equals(11000));
    });

    test('4. Parses PhonePe Layout B timeline correctly with income/expense indicators', () {
      final jsonResponse = {
        'success': true,
        'filename': 'phonepe.png',
        'items': [
          {
            'reading_index': 1,
            'text': 'Payment to',
            'bbox': [[40, 100], [150, 100], [150, 120], [40, 120]],
          },
          {
            'reading_index': 2,
            'text': 'ICCL Mutual Funds Autopay',
            'bbox': [[40, 125], [350, 125], [350, 150], [40, 150]],
          },
          {
            'reading_index': 3,
            'text': '₹1,500',
            'bbox': [[550, 125], [640, 125], [640, 150], [550, 150]],
          },
          {
            'reading_index': 4,
            'text': '8 hours ago',
            'bbox': [[40, 155], [160, 155], [160, 175], [40, 175]],
          },
          {
            'reading_index': 5,
            'text': 'Debited from',
            'bbox': [[40, 180], [160, 180], [160, 200], [40, 200]],
          },

          {
            'reading_index': 6,
            'text': 'Received from',
            'bbox': [[40, 230], [170, 230], [170, 250], [40, 250]],
          },
          {
            'reading_index': 7,
            'text': 'PARIKSIT INCORPORATION INDIA ...',
            'bbox': [[40, 255], [420, 255], [420, 280], [40, 280]],
          },
          {
            'reading_index': 8,
            'text': '+ ₹8,000',
            'bbox': [[550, 255], [660, 255], [660, 280], [550, 280]],
          },
          {
            'reading_index': 9,
            'text': '1 day ago',
            'bbox': [[40, 285], [150, 285], [150, 305], [40, 305]],
          },
          {
            'reading_index': 10,
            'text': 'Credited to',
            'bbox': [[40, 310], [160, 310], [160, 330], [40, 330]],
          },
        ]
      };

      final response = PythonOcrResponse.fromJson(jsonResponse);
      final results = parser.parseResponse(response);

      expect(results.length, equals(2));

      // 1. ICCL Mutual Funds: Expense ₹1,500
      expect(results[0].merchant, equals('ICCL Mutual Funds Autopay'));
      expect(results[0].amount, equals(150000));
      expect(results[0].type, equals(TransactionType.expense));
      expect(results[0].categoryId, equals('bills'));

      // 2. Pariksit: Income +₹8,000
      expect(results[1].merchant, equals('PARIKSIT INCORPORATION INDIA ...'));
      expect(results[1].amount, equals(800000));
      expect(results[1].type, equals(TransactionType.income));
    });

    test('5. Handles empty or unsuccessful response gracefully', () {
      const emptyResponse = PythonOcrResponse(success: false, items: []);
      final results = parser.parseResponse(emptyResponse);
      expect(results, isEmpty);
    });
  });
}
