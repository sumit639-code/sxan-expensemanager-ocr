import 'package:flutter_test/flutter_test.dart';
import 'package:expense_app/features/import/domain/entities/extracted_transaction.dart';
import 'package:expense_app/shared/enums/transaction_enums.dart';

void main() {
  group('ExtractedTransaction', () {
    final testDate = DateTime(2026, 9, 8);

    test('confidenceLabel returns correct tiers', () {
      const high = ExtractedTransaction(id: '1', confidence: 0.95);
      const medium = ExtractedTransaction(id: '2', confidence: 0.75);
      const low = ExtractedTransaction(id: '3', confidence: 0.50);

      expect(high.confidenceLabel, 'High confidence');
      expect(high.needsReview, isFalse);

      expect(medium.confidenceLabel, 'Medium confidence');
      expect(medium.needsReview, isFalse);

      expect(low.confidenceLabel, 'Needs review');
      expect(low.needsReview, isTrue);
    });

    test(
      'isValidForImport requires positive amount, date, and title or merchant',
      () {
        final validWithTitle = ExtractedTransaction(
          id: '1',
          amount: 42000,
          date: testDate,
          title: 'Swiggy',
        );
        expect(validWithTitle.isValidForImport, isTrue);

        final validWithMerchant = ExtractedTransaction(
          id: '2',
          amount: 25000,
          date: testDate,
          merchant: 'Uber',
        );
        expect(validWithMerchant.isValidForImport, isTrue);

        final noAmount = ExtractedTransaction(
          id: '3',
          amount: null,
          date: testDate,
          title: 'Dinner',
        );
        expect(noAmount.isValidForImport, isFalse);

        final zeroAmount = ExtractedTransaction(
          id: '4',
          amount: 0,
          date: testDate,
          title: 'Dinner',
        );
        expect(zeroAmount.isValidForImport, isFalse);

        const noDate = ExtractedTransaction(
          id: '5',
          amount: 1000,
          title: 'Dinner',
        );
        expect(noDate.isValidForImport, isFalse);

        final noTitleOrMerchant = ExtractedTransaction(
          id: '6',
          amount: 1000,
          date: testDate,
          title: '   ',
          merchant: '',
        );
        expect(noTitleOrMerchant.isValidForImport, isFalse);
      },
    );

    test('normalizedFingerprint normalizes case, whitespace, and date', () {
      final tx1 = ExtractedTransaction(
        id: '1',
        amount: 42000,
        date: DateTime(2026, 9, 8, 14, 30),
        merchant: 'SWIGGY',
      );

      final tx2 = ExtractedTransaction(
        id: '2',
        amount: 42000,
        date: DateTime(2026, 9, 8, 20, 15),
        merchant: '  swiggy  ',
      );

      expect(tx1.normalizedFingerprint, equals(tx2.normalizedFingerprint));
      expect(tx1.normalizedFingerprint, '2026-09-08|42000|expense|swiggy');
    });


    test(
      'toTransactionEntity converts successfully with source = screenshot',
      () {
        final extracted = ExtractedTransaction(
          id: 'ext-1',
          amount: 54000,
          currency: 'INR',
          date: testDate,
          merchant: 'Blinkit',
          title: 'Groceries',
          categoryId: 'groceries',
          type: TransactionType.expense,
          note: 'Weekly essentials',
        );

        final entity = extracted.toTransactionEntity();

        expect(entity.id, 'ext-1');
        expect(entity.amount, 54000);
        expect(entity.currency, 'INR');
        expect(entity.date, testDate);
        expect(entity.merchant, 'Blinkit');
        expect(entity.title, 'Groceries');
        expect(entity.categoryId, 'groceries');
        expect(entity.type, TransactionType.expense);
        expect(entity.note, 'Weekly essentials');
        expect(entity.source, TransactionSource.screenshot);
      },
    );

    test('toTransactionEntity throws StateError when invalid', () {
      const invalid = ExtractedTransaction(id: 'invalid-1');
      expect(() => invalid.toTransactionEntity(), throwsStateError);
    });
  });
}
