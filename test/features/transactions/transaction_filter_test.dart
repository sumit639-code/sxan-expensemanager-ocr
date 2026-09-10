import 'package:flutter_test/flutter_test.dart';
import 'package:expense_app/features/transactions/domain/entities/transaction_entity.dart';
import 'package:expense_app/features/transactions/domain/entities/transaction_filter.dart';
import 'package:expense_app/features/transactions/presentation/providers/transaction_providers.dart';
import 'package:expense_app/shared/enums/transaction_enums.dart';

void main() {
  group('TransactionFilter & matchesTransactionFilter', () {
    final now = DateTime(2026, 9, 15, 12, 0);

    final txList = [
      Transaction(
        id: '1',
        title: 'Swiggy Dinner',
        merchant: 'Swiggy',
        amount: 45000, // ₹450
        type: TransactionType.expense,
        categoryId: 'food',
        date: DateTime(2026, 9, 15, 10, 0), // Today
        source: TransactionSource.screenshot,
        createdAt: now,
        updatedAt: now,
      ),
      Transaction(
        id: '2',
        title: 'Monthly Salary',
        merchant: 'Google India',
        amount: 25000000, // ₹250,000
        type: TransactionType.income,
        categoryId: 'salary',
        date: DateTime(2026, 9, 1), // This Month
        source: TransactionSource.manual,
        createdAt: now,
        updatedAt: now,
      ),
      Transaction(
        id: '3',
        title: 'Uber Ride',
        merchant: 'Uber',
        amount: 85000, // ₹850 (between 500 and 1000)
        type: TransactionType.expense,
        categoryId: 'transport',
        date: DateTime(2026, 9, 14, 18, 0), // Yesterday
        source: TransactionSource.manual,
        createdAt: now,
        updatedAt: now,
      ),
      Transaction(
        id: '4',
        title: 'Amazon Shopping',
        merchant: 'Amazon',
        amount: 600000, // ₹6,000 (above 5000)
        type: TransactionType.expense,
        categoryId: 'shopping',
        date: DateTime(2026, 8, 20), // Last Month
        source: TransactionSource.import,
        createdAt: now,
        updatedAt: now,
      ),
    ];

    test('filters by transaction type (expense vs income)', () {
      const expenseFilter = TransactionFilter(type: TransactionType.expense);
      const incomeFilter = TransactionFilter(type: TransactionType.income);

      final expenses = txList.where((tx) => matchesTransactionFilter(tx, expenseFilter, now: now)).toList();
      final incomes = txList.where((tx) => matchesTransactionFilter(tx, incomeFilter, now: now)).toList();

      expect(expenses.length, 3);
      expect(incomes.length, 1);
      expect(incomes.first.id, '2');
    });

    test('filters by category', () {
      const foodFilter = TransactionFilter(categoryId: 'food');
      final results = txList.where((tx) => matchesTransactionFilter(tx, foodFilter, now: now)).toList();

      expect(results.length, 1);
      expect(results.first.title, 'Swiggy Dinner');
    });

    test('filters by amount presets', () {
      // Under ₹500 (under 50000 paise)
      const under500 = TransactionFilter(amountPreset: AmountFilterPreset.under500);
      final r1 = txList.where((tx) => matchesTransactionFilter(tx, under500, now: now)).toList();
      expect(r1.length, 1);
      expect(r1.first.id, '1');

      // ₹500 - ₹1000
      const between500And1000 = TransactionFilter(amountPreset: AmountFilterPreset.between500And1000);
      final r2 = txList.where((tx) => matchesTransactionFilter(tx, between500And1000, now: now)).toList();
      expect(r2.length, 1);
      expect(r2.first.id, '3');

      // Above ₹5000
      const above5000 = TransactionFilter(amountPreset: AmountFilterPreset.above5000);
      final r3 = txList.where((tx) => matchesTransactionFilter(tx, above5000, now: now)).toList();
      expect(r3.length, 2); // Amazon ₹6000, Salary ₹250,000
    });

    test('filters by search query', () {
      const searchFilter = TransactionFilter(searchQuery: 'uber');
      final results = txList.where((tx) => matchesTransactionFilter(tx, searchFilter, now: now)).toList();

      expect(results.length, 1);
      expect(results.first.merchant, 'Uber');
    });

    test('filters by source', () {
      const sourceFilter = TransactionFilter(source: TransactionSource.screenshot);
      final results = txList.where((tx) => matchesTransactionFilter(tx, sourceFilter, now: now)).toList();

      expect(results.length, 1);
      expect(results.first.id, '1');
    });

    test('sorts transactions correctly', () {
      // Highest amount first
      final highest = sortTransactions(txList, TransactionSortOrder.highestAmount);
      expect(highest.first.amount, 25000000);
      expect(highest.last.amount, 45000);

      // Lowest amount first
      final lowest = sortTransactions(txList, TransactionSortOrder.lowestAmount);
      expect(lowest.first.amount, 45000);
      expect(lowest.last.amount, 25000000);

      // A to Z
      final az = sortTransactions(txList, TransactionSortOrder.aToZ);
      expect(az.first.title, 'Amazon Shopping');
    });

    test('active chips generation and individual removal', () {
      const filter = TransactionFilter(
        type: TransactionType.expense,
        categoryId: 'food',
        amountPreset: AmountFilterPreset.under500,
      );

      final chips = filter.getActiveChips();
      expect(chips.length, 3);
      expect(chips.map((c) => c.key), containsAll(['type', 'category', 'amount']));

      final withoutType = filter.removeFilterByKey('type');
      expect(withoutType.type, isNull);
      expect(withoutType.categoryId, 'food');
      expect(withoutType.getActiveChips().length, 2);

      final cleared = filter.clearAll();
      expect(cleared.activeFilterCount, 0);
    });
  });
}
