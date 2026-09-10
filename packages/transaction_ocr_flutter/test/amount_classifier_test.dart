import 'package:flutter_test/flutter_test.dart';
import 'package:transaction_ocr_flutter/transaction_ocr_flutter.dart';

void main() {
  group('AmountClassifier - Valid Amounts', () {
    final validRupeeAmounts = {
      '₹20': 20,
      '₹40': 40,
      '₹75': 75,
      '₹110': 110,
      '₹120': 120,
      '₹138': 138,
      '₹200': 200,
      '₹205': 205,
      '₹349': 349,
      '₹425': 425,
      '₹1,000': 1000,
      '₹2,200': 2200,
      '₹2,500': 2500,
      '₹5,000': 5000,
      '₹3,700.97': 3700.97,
    };

    for (final entry in validRupeeAmounts.entries) {
      test('explicit rupee amount "${entry.key}" -> ${entry.value}', () {
        final result = AmountClassifier.classify(entry.key);
        expect(result.isAmount, isTrue,
            reason: '${entry.key} should be classified as amount (reason: ${result.rejectionReason})');
        expect(result.parsedValue, equals(entry.value));
      });
    }

    final rPrefixAmounts = {
      'R40': 40,
      'R20': 20,
      'R2,500': 2500,
      'R200': 200,
      'R349': 349,
    };

    for (final entry in rPrefixAmounts.entries) {
      test('R-prefix amount "${entry.key}" -> ${entry.value}', () {
        final result = AmountClassifier.classify(entry.key);
        expect(result.isAmount, isTrue);
        expect(result.parsedValue, equals(entry.value));
      });
    }

    final signedAmounts = {
      '+1,000': 1000,
      '+150': 150,
      '+500': 500,
    };

    for (final entry in signedAmounts.entries) {
      test('signed amount "${entry.key}" -> ${entry.value}', () {
        final result = AmountClassifier.classify(entry.key);
        expect(result.isAmount, isTrue);
        expect(result.parsedValue, equals(entry.value));
      });
    }

    final plainCommaNumbers = {
      '5,000': 5000,
      '2,500': 2500,
      '2,200': 2200,
      '3,700.97': 3700.97,
      '1,000': 1000,
    };

    for (final entry in plainCommaNumbers.entries) {
      test('plain number with comma "${entry.key}" -> ${entry.value}', () {
        final result = AmountClassifier.classify(entry.key);
        expect(result.isAmount, isTrue);
        expect(result.parsedValue, equals(entry.value));
      });
    }

    final rightSidePlainNumbers = [
      {'text': '349', 'bbox': [[399.0, 299.0], [441.0, 299.0], [441.0, 319.0], [399.0, 319.0]], 'w': 462, 'exp': 349},
      {'text': '20', 'bbox': [[407.0, 527.0], [442.0, 529.0], [440.0, 550.0], [406.0, 548.0]], 'w': 462, 'exp': 20},
      {'text': '80', 'bbox': [[400.0, 460.0], [442.0, 460.0], [442.0, 480.0], [400.0, 480.0]], 'w': 462, 'exp': 80},
      {'text': '50', 'bbox': [[400.0, 600.0], [442.0, 600.0], [442.0, 620.0], [400.0, 620.0]], 'w': 462, 'exp': 50},
      {'text': '205', 'bbox': [[406.0, 755.0], [441.0, 755.0], [441.0, 775.0], [406.0, 775.0]], 'w': 462, 'exp': 205},
      {'text': '110', 'bbox': [[400.0, 965.0], [442.0, 965.0], [442.0, 985.0], [400.0, 985.0]], 'w': 462, 'exp': 110},
    ];

    for (final item in rightSidePlainNumbers) {
      test('right-aligned plain number "${item['text']}" -> ${item['exp']}', () {
        final bbox = BoundingBox.fromJson(item['bbox'] as List<dynamic>);
        final result = AmountClassifier.classify(
          item['text'] as String,
          bbox: bbox,
          imgWidth: item['w'] as int,
        );
        expect(result.isAmount, isTrue);
        expect(result.parsedValue, equals(item['exp']));
      });
    }
  });

  group('AmountClassifier - Invalid Non-Amount Rejections', () {
    const timeStrings = [
      '16:48',
      '08:56',
      '08:56?',
      '8:30 AM',
      '16:48 PM',
    ];

    for (final t in timeStrings) {
      test('rejects time string "$t"', () {
        final result = AmountClassifier.classify(t);
        expect(result.isAmount, isFalse, reason: 'Time "$t" should be rejected');
      });
    }

    const dateLabels = [
      '7September',
      '6September',
      '5September',
      '4September',
      '3September',
      '2September',
      '1September',
      '7 September',
      '6 September',
      '5 September',
      '04 Sept',
      '02 Sept',
      '04Sept',
      '2September2026at2:35pm',
      '7September2026',
    ];

    for (final d in dateLabels) {
      test('rejects date label "$d"', () {
        final result = AmountClassifier.classify(d);
        expect(result.isAmount, isFalse, reason: 'Date label "$d" should be rejected');
      });
    }

    const relativeTimeStrings = [
      '8 hours ago',
      '1 day ago',
      '2 days ago',
      '30 minutes ago',
      '1 hour ago',
    ];

    for (final r in relativeTimeStrings) {
      test('rejects relative time "$r"', () {
        final result = AmountClassifier.classify(r);
        expect(result.isAmount, isFalse);
      });
    }

    const noiseAndUiStrings = [
      '·三5G三374',
      'ODO7SNACKS',
      'KRISHNA STORE',
      'Searchtransactions',
      'Search transactions',
    ];

    for (final n in noiseAndUiStrings) {
      test('rejects noise/merchant "$n"', () {
        final result = AmountClassifier.classify(n);
        expect(result.isAmount, isFalse);
      });
    }

    test('rejects left-aligned single digits (date numbers)', () {
      final bbox = BoundingBox.fromJson([[78.0, 247.0], [168.0, 249.0], [167.0, 267.0], [78.0, 265.0]]);
      final result = AmountClassifier.classify('7', bbox: bbox, imgWidth: 462);
      expect(result.isAmount, isFalse);
    });
  });

  group('AmountClassifier - ₹5,000 vs ₹75,000 Regressions', () {
    test('75,000 on right side normalizes to ₹5,000 (5000)', () {
      final bbox = BoundingBox.fromJson([[384.0, 377.0], [440.0, 377.0], [440.0, 395.0], [384.0, 395.0]]);
      final result = AmountClassifier.classify('75,000', bbox: bbox, imgWidth: 462);
      expect(result.isAmount, isTrue);
      expect(result.parsedValue, equals(5000));
      expect(result.normalizedText, equals('₹5,000'));
    });

    test('explicit ₹5,000 parses to 5000', () {
      final result = AmountClassifier.classify('₹5,000');
      expect(result.isAmount, isTrue);
      expect(result.parsedValue, equals(5000));
    });

    test('R5,000 parses to 5000', () {
      final result = AmountClassifier.classify('R5,000');
      expect(result.isAmount, isTrue);
      expect(result.parsedValue, equals(5000));
    });

    test('legitimate ₹75 is NOT stripped to 5', () {
      final result = AmountClassifier.classify('₹75');
      expect(result.isAmount, isTrue);
      expect(result.parsedValue, equals(75));
    });

    test('legitimate ₹750 is NOT stripped', () {
      final result = AmountClassifier.classify('₹750');
      expect(result.isAmount, isTrue);
      expect(result.parsedValue, equals(750));
    });

    test('7205 on right side normalizes to ₹205 (205)', () {
      final bbox = BoundingBox.fromJson([[384.0, 377.0], [440.0, 377.0], [440.0, 395.0], [384.0, 395.0]]);
      final result = AmountClassifier.classify('7205', bbox: bbox, imgWidth: 462);
      expect(result.isAmount, isTrue);
      expect(result.parsedValue, equals(205));
    });
  });
}
