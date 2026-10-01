import 'package:flutter_test/flutter_test.dart';
import 'package:expense_app/features/transactions/domain/entities/transaction_entity.dart';
import 'package:expense_app/features/transactions/domain/entities/transaction_filter.dart';
import 'package:expense_app/features/transactions/presentation/providers/transaction_providers.dart';
import 'package:expense_app/shared/enums/transaction_enums.dart';

void main() {
  group('Transaction Filtering & Search Logic', () {
    final now = DateTime(2026, 9, 11, 14, 30);
    final yesterday = DateTime(2026, 9, 10, 10, 0);
    final lastWeek = DateTime(2026, 9, 4, 12, 0);
    final lastMonth = DateTime(2026, 8, 15, 18, 0);

    final tx1 = Transaction(
      id: 'tx-1',
      title: 'Swiggy Dinner',
      merchant: 'Swiggy Instamart',
      amount: 42000, // ₹420.00
      type: TransactionType.expense,
      categoryId: 'food',
      date: now,
      note: 'Ordered biryani with friends',
      source: TransactionSource.manual,
      createdAt: now,
      updatedAt: now,
    );

    final tx2 = Transaction(
      id: 'tx-2',
      title: 'Uber to Office',
      merchant: 'Uber India',
      amount: 18000, // ₹180.00
      type: TransactionType.expense,
      categoryId: 'transport',
      date: yesterday,
      source: TransactionSource.screenshot,
      createdAt: yesterday,
      updatedAt: yesterday,
    );

    final tx3 = Transaction(
      id: 'tx-3',
      title: 'Monthly Salary',
      merchant: 'Google India',
      amount: 5000000, // ₹50,000.00
      type: TransactionType.income,
      categoryId: 'salary',
      date: yesterday,
      note: 'September payroll',
      source: TransactionSource.manual,
      createdAt: yesterday,
      updatedAt: yesterday,
    );

    final tx4 = Transaction(
      id: 'tx-4',
      title: 'Electronics Shopping',
      merchant: 'Amazon',
      amount: 250000, // ₹2,500.00
      type: TransactionType.expense,
      categoryId: 'shopping',
      date: lastWeek,
      source: TransactionSource.screenshot,
      createdAt: lastWeek,
      updatedAt: lastWeek,
    );

    final tx5 = Transaction(
      id: 'tx-5',
      title: 'Freelance Design',
      merchant: 'Upwork',
      amount: 1500000, // ₹15,000.00
      type: TransactionType.income,
      categoryId: 'freelance',
      date: lastMonth,
      source: TransactionSource.manual,
      createdAt: lastMonth,
      updatedAt: lastMonth,
    );

    final allList = [tx1, tx2, tx3, tx4, tx5];

    test('multi-field search matches title, merchant, note, and category name', () {
      // 1. Search title
      const filterTitle = TransactionFilter(searchQuery: 'dinner');
      final matchTitle = allList.where((t) => matchesTransactionFilter(t, filterTitle, now: now)).toList();
      expect(matchTitle.length, 1);
      expect(matchTitle.first.id, 'tx-1');

      // 2. Search merchant
      const filterMerchant = TransactionFilter(searchQuery: 'uber');
      final matchMerchant = allList.where((t) => matchesTransactionFilter(t, filterMerchant, now: now)).toList();
      expect(matchMerchant.length, 1);
      expect(matchMerchant.first.id, 'tx-2');

      // 3. Search note
      const filterNote = TransactionFilter(searchQuery: 'payroll');
      final matchNote = allList.where((t) => matchesTransactionFilter(t, filterNote, now: now)).toList();
      expect(matchNote.length, 1);
      expect(matchNote.first.id, 'tx-3');

      // 4. Search category name ("Transport")
      const filterCatName = TransactionFilter(searchQuery: 'transport');
      final matchCatName = allList.where((t) => matchesTransactionFilter(t, filterCatName, now: now)).toList();
      expect(matchCatName.any((t) => t.id == 'tx-2'), isTrue);
    });

    test('search is case-insensitive and whitespace-tolerant', () {
      final queries = ['SWIGGY', 'swiggy', '  Swiggy  ', 'SWIGGY '];
      for (final q in queries) {
        final filter = TransactionFilter(searchQuery: q);
        final match = allList.where((t) => matchesTransactionFilter(t, filter, now: now)).toList();
        expect(match.length, 1, reason: 'Failed for query: "$q"');
        expect(match.first.id, 'tx-1');
      }
    });

    test('type filtering returns only matching transaction types', () {
      const expenseFilter = TransactionFilter(type: TransactionType.expense);
      final expenses = allList.where((t) => matchesTransactionFilter(t, expenseFilter, now: now)).toList();
      expect(expenses.length, 3);
      expect(expenses.every((t) => t.type == TransactionType.expense), isTrue);

      const incomeFilter = TransactionFilter(type: TransactionType.income);
      final income = allList.where((t) => matchesTransactionFilter(t, incomeFilter, now: now)).toList();
      expect(income.length, 2);
      expect(income.every((t) => t.type == TransactionType.income), isTrue);
    });

    test('category filtering filters by exact category id', () {
      const foodFilter = TransactionFilter(categoryId: 'food');
      final foodList = allList.where((t) => matchesTransactionFilter(t, foodFilter, now: now)).toList();
      expect(foodList.length, 1);
      expect(foodList.first.id, 'tx-1');
    });

    test('date filtering correctly evaluates boundaries', () {
      // Today
      const todayFilter = TransactionFilter(datePreset: DateFilterPreset.today);
      final todayList = allList.where((t) => matchesTransactionFilter(t, todayFilter, now: now)).toList();
      expect(todayList.length, 1);
      expect(todayList.first.id, 'tx-1');

      // Yesterday
      const yesterdayFilter = TransactionFilter(datePreset: DateFilterPreset.yesterday);
      final yesterdayList = allList.where((t) => matchesTransactionFilter(t, yesterdayFilter, now: now)).toList();
      expect(yesterdayList.length, 2); // tx2 and tx3

      // Last Month
      const lastMonthFilter = TransactionFilter(datePreset: DateFilterPreset.lastMonth);
      final lastMonthList = allList.where((t) => matchesTransactionFilter(t, lastMonthFilter, now: now)).toList();
      expect(lastMonthList.length, 1);
      expect(lastMonthList.first.id, 'tx-5');
    });

    test('amount presets and custom amount range filter in paise accurately', () {
      // Under ₹500 (< 50,000 paise)
      const under500 = TransactionFilter(amountPreset: AmountFilterPreset.under500);
      final under500List = allList.where((t) => matchesTransactionFilter(t, under500, now: now)).toList();
      expect(under500List.length, 2); // tx1 (42000), tx2 (18000)

      // Between ₹1,000 and ₹5,000 (100,000 to 500,000 paise)
      const mid = TransactionFilter(amountPreset: AmountFilterPreset.between1000And5000);
      final midList = allList.where((t) => matchesTransactionFilter(t, mid, now: now)).toList();
      expect(midList.length, 1);
      expect(midList.first.id, 'tx-4'); // ₹2,500

      // Custom amount range: ₹500 to ₹3,000 (50,000 to 300,000 paise)
      const custom = TransactionFilter(
        amountPreset: AmountFilterPreset.custom,
        customMinAmountMinor: 50000,
        customMaxAmountMinor: 300000,
      );
      final customList = allList.where((t) => matchesTransactionFilter(t, custom, now: now)).toList();
      expect(customList.length, 1);
      expect(customList.first.id, 'tx-4');
    });

    test('sorting sorts newest, oldest, highest, lowest amount properly', () {
      final newest = sortTransactions(allList, TransactionSortOrder.newestFirst);
      expect(newest.first.id, 'tx-1');

      final oldest = sortTransactions(allList, TransactionSortOrder.oldestFirst);
      expect(oldest.first.id, 'tx-5');

      final highest = sortTransactions(allList, TransactionSortOrder.highestAmount);
      expect(highest.first.amount, 5000000); // ₹50,000

      final lowest = sortTransactions(allList, TransactionSortOrder.lowestAmount);
      expect(lowest.first.amount, 18000); // ₹180
    });

    test('combined filters match ALL conditions simultaneously', () {
      // Expenses + This Month + Under ₹500
      const combined = TransactionFilter(
        type: TransactionType.expense,
        datePreset: DateFilterPreset.thisMonth,
        amountPreset: AmountFilterPreset.under500,
      );
      final results = allList.where((t) => matchesTransactionFilter(t, combined, now: now)).toList();
      expect(results.length, 2); // tx1 (₹420) and tx2 (₹180)
      expect(results.every((t) => t.type == TransactionType.expense), isTrue);
      expect(results.every((t) => t.amount < 50000), isTrue);
    });

    test('clear filters resets all parameters', () {
      const filter = TransactionFilter(
        searchQuery: 'swiggy',
        type: TransactionType.expense,
        categoryId: 'food',
        datePreset: DateFilterPreset.today,
        amountPreset: AmountFilterPreset.under500,
      );
      expect(filter.hasActiveFilters, isTrue);
      expect(filter.activeFilterCount, greaterThanOrEqualTo(4));

      const cleared = TransactionFilter();
      expect(cleared.hasActiveFilters, isFalse);
      expect(cleared.activeFilterCount, 0);
    });
  });
}
