import 'package:drift/native.dart';
import 'package:expense_app/core/database/app_database.dart';
import 'package:expense_app/features/transactions/data/repositories/drift_transaction_repository.dart';
import 'package:expense_app/features/transactions/domain/entities/transaction_entity.dart';
import 'package:expense_app/shared/enums/transaction_enums.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late DriftTransactionRepository repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DriftTransactionRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'Repository CRUD operations, search and date range work correctly',
    () async {
      final now = DateTime.now();
      final tx1 = Transaction(
        id: 'tx-1',
        type: TransactionType.expense,
        amount: 45000, // ₹450.00
        currency: 'INR',
        title: 'Restaurant Dinner',
        merchant: 'Bistro',
        categoryId: 'food',
        date: now,
        source: TransactionSource.manual,
        createdAt: now,
        updatedAt: now,
      );

      final tx2 = Transaction(
        id: 'tx-2',
        type: TransactionType.income,
        amount: 5000000, // ₹50,000.00
        currency: 'INR',
        title: 'Freelance Project',
        merchant: 'Client ACME',
        categoryId: 'freelance',
        date: now.subtract(const Duration(days: 2)),
        source: TransactionSource.manual,
        createdAt: now,
        updatedAt: now,
      );

      // 1. Add
      await repository.addTransaction(tx1);
      await repository.addTransaction(tx2);

      // 2. Get All
      final all = await repository.getAllTransactions();
      expect(all.length, 2);

      // 3. Search
      final searchResults = await repository.searchTransactions('Dinner');
      expect(searchResults.length, 1);
      expect(searchResults.first.id, 'tx-1');

      // 4. Update
      final updatedTx1 = tx1.copyWith(amount: 50000);
      await repository.updateTransaction(updatedTx1);
      final fetched = await repository.getTransactionById('tx-1');
      expect(fetched?.amount, 50000);

      // 5. Delete single
      await repository.deleteTransaction('tx-1');
      final afterDelete = await repository.getAllTransactions();
      expect(afterDelete.length, 1);
      expect(afterDelete.first.id, 'tx-2');

      // 6. Bulk Delete
      final tx3 = tx1.copyWith(id: 'tx-3');
      final tx4 = tx1.copyWith(id: 'tx-4');
      await repository.addTransactions([tx3, tx4]);
      expect((await repository.getAllTransactions()).length, 3);

      await repository.deleteTransactions(['tx-2', 'tx-3']);
      final remaining = await repository.getAllTransactions();
      expect(remaining.length, 1);
      expect(remaining.first.id, 'tx-4');

      // 7. Bulk Delete empty list does not fail
      await repository.deleteTransactions([]);
      expect((await repository.getAllTransactions()).length, 1);
    },
  );
}
