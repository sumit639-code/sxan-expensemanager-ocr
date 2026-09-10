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
    'Database inserts and queries transaction correctly with minor units',
    () async {
      final now = DateTime.now();
      final transaction = Transaction(
        id: 'tx-1',
        type: TransactionType.expense,
        amount: 32050, // ₹320.50 stored as minor units
        currency: 'INR',
        title: 'Grocery Shopping',
        merchant: 'Supermarket',
        date: now,
        source: TransactionSource.manual,
        createdAt: now,
        updatedAt: now,
      );

      await repository.addTransaction(transaction);

      final transactions = await repository.getAllTransactions();
      expect(transactions.length, 1);

      final fetched = transactions.first;
      expect(fetched.id, 'tx-1');
      expect(fetched.amount, 32050);
      expect(fetched.type, TransactionType.expense);
      expect(fetched.title, 'Grocery Shopping');
      expect(fetched.merchant, 'Supermarket');
    },
  );
}
