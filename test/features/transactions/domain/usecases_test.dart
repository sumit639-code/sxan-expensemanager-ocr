import 'package:expense_app/features/transactions/domain/entities/transaction_entity.dart';
import 'package:expense_app/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:expense_app/features/transactions/domain/usecases/transaction_usecases.dart';
import 'package:expense_app/shared/enums/transaction_enums.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeTransactionRepository implements TransactionRepository {
  final List<Transaction> _items = [];

  @override
  Future<void> addTransaction(Transaction transaction) async {
    _items.add(transaction);
  }

  @override
  Future<void> addTransactions(List<Transaction> transactions) async {
    _items.addAll(transactions);
  }

  @override
  Future<void> deleteTransaction(String id) async {
    _items.removeWhere((item) => item.id == id);
  }

  @override
  Future<void> deleteTransactions(List<String> ids) async {
    final set = ids.toSet();
    _items.removeWhere((item) => set.contains(item.id));
  }

  @override
  Future<List<Transaction>> getAllTransactions() async => _items;

  @override
  Future<Transaction?> getTransactionById(String id) async {
    try {
      return _items.firstWhere((item) => item.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Transaction>> getTransactionsByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    return _items
        .where((item) => item.date.isAfter(start) && item.date.isBefore(end))
        .toList();
  }

  @override
  Future<List<Transaction>> searchTransactions(
    String query, {
    TransactionType? filterType,
  }) async {
    return _items.where((item) => item.title.contains(query)).toList();
  }

  @override
  Future<void> updateTransaction(Transaction transaction) async {
    final index = _items.indexWhere((item) => item.id == transaction.id);
    if (index != -1) {
      _items[index] = transaction;
    }
  }

  @override
  Future<void> clearAllTransactions() async {
    _items.clear();
  }

  @override
  Stream<List<Transaction>> watchAllTransactions() async* {
    yield _items;
  }
}

void main() {
  late FakeTransactionRepository repo;
  late AddTransactionUseCase addUseCase;
  late GetMonthlySummaryUseCase summaryUseCase;

  setUp(() {
    repo = FakeTransactionRepository();
    addUseCase = AddTransactionUseCase(repo);
    summaryUseCase = GetMonthlySummaryUseCase(repo);
  });

  test(
    'AddTransactionUseCase validates amount > 0 and title non-empty',
    () async {
      final now = DateTime.now();
      final invalidTx = Transaction(
        id: 'tx-1',
        type: TransactionType.expense,
        amount: 0,
        title: 'Invalid',
        date: now,
        source: TransactionSource.manual,
        createdAt: now,
        updatedAt: now,
      );

      expect(() => addUseCase.execute(invalidTx), throwsArgumentError);
    },
  );

  test(
    'GetMonthlySummaryUseCase calculates balance, income, and expense totals accurately',
    () async {
      final now = DateTime.now();
      final incomeTx = Transaction(
        id: 'tx-inc',
        type: TransactionType.income,
        amount: 100000, // ₹1,000.00
        title: 'Salary',
        date: now,
        source: TransactionSource.manual,
        createdAt: now,
        updatedAt: now,
      );
      final expenseTx = Transaction(
        id: 'tx-exp',
        type: TransactionType.expense,
        amount: 30000, // ₹300.00
        title: 'Lunch',
        date: now,
        source: TransactionSource.manual,
        createdAt: now,
        updatedAt: now,
      );

      await addUseCase.execute(incomeTx);
      await addUseCase.execute(expenseTx);

      final summary = await summaryUseCase.execute();
      expect(summary.incomeTotal, 100000);
      expect(summary.expenseTotal, 30000);
      expect(summary.totalBalance, 70000); // 100000 - 30000
    },
  );
}
