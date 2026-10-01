import 'package:expense_app/features/analysis/domain/entities/analysis_period.dart';
import 'package:expense_app/features/transactions/domain/entities/transaction_entity.dart';
import 'package:expense_app/features/transactions/domain/usecases/transaction_usecases.dart';
import 'package:expense_app/shared/enums/transaction_enums.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Dashboard Analytics & Financial Calculation Layer', () {
    final refDate = DateTime(2026, 9, 15, 12, 0, 0);
    final thisMonthPeriod = AnalysisPeriod.fromType(
      AnalysisPeriodType.thisMonth,
      referenceDate: refDate,
    );

    test('Empty database produces valid empty DashboardSummary with correct flags', () {
      final summary = GetMonthlySummaryUseCase.calculateSummary(
        [],
        period: thisMonthPeriod,
        referenceDate: refDate,
      );

      expect(summary.isDatabaseEmpty, isTrue);
      expect(summary.isPeriodEmpty, isTrue);
      expect(summary.netCashFlow, equals(0));
      expect(summary.incomeTotal, equals(0));
      expect(summary.expenseTotal, equals(0));
      expect(summary.recentTransactions, isEmpty);
      expect(summary.categoryBreakdown, isEmpty);
      expect(summary.averageDailySpending, equals(0));
      expect(summary.largestExpense, isNull);
    });

    test('Single expense transaction calculation in paise', () {
      final tx = Transaction(
        id: '1',
        title: 'Groceries',
        amount: 10050, // ₹100.50
        type: TransactionType.expense,
        categoryId: 'food',
        source: TransactionSource.manual,
        date: DateTime(2026, 9, 5, 10, 0),
        createdAt: DateTime(2026, 9, 5),
        updatedAt: DateTime(2026, 9, 5),
      );

      final summary = GetMonthlySummaryUseCase.calculateSummary(
        [tx],
        period: thisMonthPeriod,
        referenceDate: refDate,
      );

      expect(summary.isDatabaseEmpty, isFalse);
      expect(summary.isPeriodEmpty, isFalse);
      expect(summary.incomeTotal, equals(0));
      expect(summary.expenseTotal, equals(10050));
      expect(summary.netCashFlow, equals(-10050));
      expect(summary.largestExpense?.id, equals('1'));
      expect(summary.categoryBreakdown.length, equals(1));
      expect(summary.categoryBreakdown.first.categoryId, equals('food'));
      expect(summary.categoryBreakdown.first.totalMinor, equals(10050));
      expect(summary.categoryBreakdown.first.percentage, equals(100.0));
    });

    test('Income-only period produces positive Net Cash Flow', () {
      final tx = Transaction(
        id: 'inc1',
        title: 'Salary',
        amount: 5000000, // ₹50,000.00
        type: TransactionType.income,
        categoryId: 'salary',
        source: TransactionSource.manual,
        date: DateTime(2026, 9, 1, 9, 0),
        createdAt: DateTime(2026, 9, 1),
        updatedAt: DateTime(2026, 9, 1),
      );

      final summary = GetMonthlySummaryUseCase.calculateSummary(
        [tx],
        period: thisMonthPeriod,
        referenceDate: refDate,
      );

      expect(summary.incomeTotal, equals(5000000));
      expect(summary.expenseTotal, equals(0));
      expect(summary.netCashFlow, equals(5000000));
      expect(summary.categoryBreakdown, isEmpty);
      expect(summary.largestExpense, isNull);
    });

    test('Mixed income and expense period calculates Net Cash Flow correctly', () {
      final transactions = [
        Transaction(
          id: 'inc1',
          title: 'Monthly Salary',
          amount: 6000000, // ₹60,000
          type: TransactionType.income,
          categoryId: 'salary',
          source: TransactionSource.manual,
          date: DateTime(2026, 9, 1),
          createdAt: DateTime(2026, 9, 1),
          updatedAt: DateTime(2026, 9, 1),
        ),
        Transaction(
          id: 'exp1',
          title: 'Rent',
          amount: 2500000, // ₹25,000
          type: TransactionType.expense,
          categoryId: 'housing',
          source: TransactionSource.manual,
          date: DateTime(2026, 9, 2),
          createdAt: DateTime(2026, 9, 2),
          updatedAt: DateTime(2026, 9, 2),
        ),
        Transaction(
          id: 'exp2',
          title: 'Dining Out',
          amount: 750000, // ₹7,500
          type: TransactionType.expense,
          categoryId: 'food',
          source: TransactionSource.manual,
          date: DateTime(2026, 9, 10),
          createdAt: DateTime(2026, 9, 10),
          updatedAt: DateTime(2026, 9, 10),
        ),
      ];

      final summary = GetMonthlySummaryUseCase.calculateSummary(
        transactions,
        period: thisMonthPeriod,
        referenceDate: refDate,
      );

      // Income = ₹60,000; Expense = ₹32,500; Net = ₹27,500
      expect(summary.incomeTotal, equals(6000000));
      expect(summary.expenseTotal, equals(3250000));
      expect(summary.netCashFlow, equals(2750000));
      expect(summary.largestExpense?.id, equals('exp1'));
      expect(summary.largestExpense?.amount, equals(2500000));
    });

    test('Category breakdown sorts descending and calculates percentage', () {
      final transactions = [
        Transaction(
          id: '1',
          title: 'Transport',
          amount: 200000, // ₹2,000 (20%)
          type: TransactionType.expense,
          categoryId: 'transport',
          source: TransactionSource.manual,
          date: DateTime(2026, 9, 3),
          createdAt: DateTime(2026, 9, 3),
          updatedAt: DateTime(2026, 9, 3),
        ),
        Transaction(
          id: '2',
          title: 'Groceries',
          amount: 500000, // ₹5,000 (50%)
          type: TransactionType.expense,
          categoryId: 'food',
          source: TransactionSource.manual,
          date: DateTime(2026, 9, 4),
          createdAt: DateTime(2026, 9, 4),
          updatedAt: DateTime(2026, 9, 4),
        ),
        Transaction(
          id: '3',
          title: 'Coffee',
          amount: 300000, // ₹3,000 (30%)
          type: TransactionType.expense,
          categoryId: 'food',
          source: TransactionSource.manual,
          date: DateTime(2026, 9, 5),
          createdAt: DateTime(2026, 9, 5),
          updatedAt: DateTime(2026, 9, 5),
        ),
      ];

      final summary = GetMonthlySummaryUseCase.calculateSummary(
        transactions,
        period: thisMonthPeriod,
        referenceDate: refDate,
      );

      // Total expense = ₹10,000. Food = ₹8,000 (80%), Transport = ₹2,000 (20%)
      expect(summary.categoryBreakdown.length, equals(2));
      expect(summary.categoryBreakdown[0].categoryId, equals('food'));
      expect(summary.categoryBreakdown[0].totalMinor, equals(800000));
      expect(summary.categoryBreakdown[0].percentage, equals(80.0));
      expect(summary.categoryBreakdown[0].count, equals(2));

      expect(summary.categoryBreakdown[1].categoryId, equals('transport'));
      expect(summary.categoryBreakdown[1].totalMinor, equals(200000));
      expect(summary.categoryBreakdown[1].percentage, equals(20.0));
      expect(summary.categoryBreakdown[1].count, equals(1));
    });

    test('Average daily spending calculates over elapsed calendar days', () {
      final transactions = [
        Transaction(
          id: '1',
          title: 'Meal',
          amount: 1500000, // ₹15,000 over 15 elapsed days = ₹1,000/day
          type: TransactionType.expense,
          categoryId: 'food',
          source: TransactionSource.manual,
          date: DateTime(2026, 9, 5),
          createdAt: DateTime(2026, 9, 5),
          updatedAt: DateTime(2026, 9, 5),
        ),
      ];

      final summary = GetMonthlySummaryUseCase.calculateSummary(
        transactions,
        period: thisMonthPeriod,
        referenceDate: refDate, // 15th September (15 days elapsed)
      );

      expect(summary.averageDailySpending, equals(100000)); // ₹1,000.00
    });

    test('Previous period comparison calculates percentage and handles zero previous data safely', () {
      // 1. Zero previous period data
      final currentTx = [
        Transaction(
          id: 'cur1',
          title: 'Lunch',
          amount: 50000,
          type: TransactionType.expense,
          categoryId: 'food',
          source: TransactionSource.manual,
          date: DateTime(2026, 9, 10),
          createdAt: DateTime(2026, 9, 10),
          updatedAt: DateTime(2026, 9, 10),
        ),
      ];

      final summaryNoPrev = GetMonthlySummaryUseCase.calculateSummary(
        currentTx,
        period: thisMonthPeriod,
        referenceDate: refDate,
      );

      expect(summaryNoPrev.comparison.expensePercentageChange, isNull);
      expect(summaryNoPrev.comparison.expenseComparisonText, contains('more than last month'));

      final summaryEmptyDb = GetMonthlySummaryUseCase.calculateSummary(
        [],
        period: thisMonthPeriod,
        referenceDate: refDate,
      );
      expect(summaryEmptyDb.comparison.hasPreviousData, isFalse);
      expect(summaryEmptyDb.comparison.expenseComparisonText, equals('No previous period data'));

      // 2. Populated previous period data
      final prevTx = [
        Transaction(
          id: 'prev1',
          title: 'August Shopping',
          amount: 40000,
          type: TransactionType.expense,
          categoryId: 'shopping',
          source: TransactionSource.manual,
          date: DateTime(2026, 8, 15),
          createdAt: DateTime(2026, 8, 15),
          updatedAt: DateTime(2026, 8, 15),
        ),
      ];

      final summaryWithPrev = GetMonthlySummaryUseCase.calculateSummary(
        [...currentTx, ...prevTx],
        period: thisMonthPeriod,
        referenceDate: refDate,
      );

      // Current 50,000 vs Prev 40,000 = +25%
      expect(summaryWithPrev.comparison.hasPreviousData, isTrue);
      expect(summaryWithPrev.comparison.expensePercentageChange, closeTo(25.0, 0.1));
      expect(summaryWithPrev.comparison.isExpenseHigher, isTrue);
    });

    test('Date boundaries: midnight, first day, last day, and month transition', () {
      final sep1Midnight = Transaction(
        id: 'sep1',
        title: 'Midnight 1st Sep',
        amount: 10000,
        type: TransactionType.expense,
        categoryId: 'food',
        source: TransactionSource.manual,
        date: DateTime(2026, 9, 1, 0, 0, 0),
        createdAt: DateTime(2026, 9, 1),
        updatedAt: DateTime(2026, 9, 1),
      );

      final sep30LastSecond = Transaction(
        id: 'sep30',
        title: 'End of 30th Sep',
        amount: 20000,
        type: TransactionType.expense,
        categoryId: 'food',
        source: TransactionSource.manual,
        date: DateTime(2026, 9, 30, 23, 59, 59),
        createdAt: DateTime(2026, 9, 30),
        updatedAt: DateTime(2026, 9, 30),
      );

      final oct1Midnight = Transaction(
        id: 'oct1',
        title: 'Start of 1st Oct',
        amount: 30000,
        type: TransactionType.expense,
        categoryId: 'food',
        source: TransactionSource.manual,
        date: DateTime(2026, 10, 1, 0, 0, 0),
        createdAt: DateTime(2026, 10, 1),
        updatedAt: DateTime(2026, 10, 1),
      );

      final aug31LastSecond = Transaction(
        id: 'aug31',
        title: 'End of 31st Aug',
        amount: 40000,
        type: TransactionType.expense,
        categoryId: 'food',
        source: TransactionSource.manual,
        date: DateTime(2026, 8, 31, 23, 59, 59),
        createdAt: DateTime(2026, 8, 31),
        updatedAt: DateTime(2026, 8, 31),
      );

      final allTx = [sep1Midnight, sep30LastSecond, oct1Midnight, aug31LastSecond];

      final summary = GetMonthlySummaryUseCase.calculateSummary(
        allTx,
        period: thisMonthPeriod,
        referenceDate: refDate,
      );

      // Only sep1Midnight (10,000) and sep30LastSecond (20,000) should be included in September
      expect(summary.expenseTotal, equals(30000));
      expect(summary.categoryBreakdown.first.count, equals(2));
    });

    test('Recent transactions limit to 5 sorted newest first', () {
      final transactions = List.generate(
        10,
        (i) => Transaction(
          id: 'tx_$i',
          title: 'Item $i',
          amount: (i + 1) * 1000,
          type: TransactionType.expense,
          categoryId: 'food',
          source: TransactionSource.manual,
          date: DateTime(2026, 9, i + 1),
          createdAt: DateTime(2026, 9, i + 1),
          updatedAt: DateTime(2026, 9, i + 1),
        ),
      );

      final summary = GetMonthlySummaryUseCase.calculateSummary(
        transactions,
        period: thisMonthPeriod,
        referenceDate: refDate,
      );

      expect(summary.recentTransactions.length, equals(5));
      expect(summary.recentTransactions.first.id, equals('tx_9'));
      expect(summary.recentTransactions.last.id, equals('tx_5'));
    });
  });
}
