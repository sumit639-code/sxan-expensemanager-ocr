import 'package:flutter_test/flutter_test.dart';
import 'package:expense_app/features/import/domain/entities/extracted_transaction.dart';
import 'package:expense_app/features/import/domain/usecases/confirm_import_usecase.dart';
import 'package:expense_app/shared/enums/transaction_enums.dart';

import 'duplicate_detector_test.dart';

void main() {
  group('ConfirmImportUseCase', () {
    final testDate = DateTime(2026, 9, 8);

    test(
      'converts valid extracted transactions to Transaction entities with source=screenshot',
      () async {
        final fakeRepo = FakeTransactionRepository();
        final useCase = ConfirmImportUseCase(fakeRepo);

        final toImport = [
          ExtractedTransaction(
            id: 'ext-1',
            merchant: 'Swiggy',
            amount: 42000,
            date: testDate,
            categoryId: 'food',
          ),
          ExtractedTransaction(
            id: 'ext-2',
            merchant: 'Uber',
            amount: 28000,
            date: testDate,
            categoryId: 'transport',
          ),
        ];

        final saved = await useCase.execute(toImport);

        expect(saved.length, 2);
        expect(saved[0].source, TransactionSource.screenshot);
        expect(saved[0].amount, 42000);
        expect(saved[1].source, TransactionSource.screenshot);
        expect(saved[1].amount, 28000);

        final inRepo = await fakeRepo.getAllTransactions();
        expect(inRepo.length, 2);
        expect(inRepo[0].source, TransactionSource.screenshot);
        expect(inRepo[1].source, TransactionSource.screenshot);
      },
    );

    test(
      'ignores incomplete/invalid extracted transactions during confirmation',
      () async {
        final fakeRepo = FakeTransactionRepository();
        final useCase = ConfirmImportUseCase(fakeRepo);

        final toImport = [
          ExtractedTransaction(
            id: 'valid-1',
            merchant: 'Zomato',
            amount: 50000,
            date: testDate,
          ),
          const ExtractedTransaction(
            id: 'invalid-no-amount',
            merchant: 'Unknown',
            amount: null,
          ),
        ];

        final saved = await useCase.execute(toImport);

        expect(saved.length, 1);
        expect(saved[0].id, 'valid-1');

        final inRepo = await fakeRepo.getAllTransactions();
        expect(inRepo.length, 1);
      },
    );
  });
}
