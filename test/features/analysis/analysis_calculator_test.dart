import 'package:flutter_test/flutter_test.dart';
import 'package:expense_app/features/analysis/domain/entities/analysis_period.dart';
import 'package:expense_app/features/analysis/domain/services/analysis_calculator.dart';
import 'package:expense_app/features/transactions/domain/entities/transaction_entity.dart';
import 'package:expense_app/shared/enums/transaction_enums.dart';

void main() {
  group('AnalysisCalculator', () {
    Transaction makeTx({
      required String id,
      required TransactionType type,
      required int amount,
      required DateTime date,
      String? categoryId,
      String? merchant,
      String title = 'Test Transaction',
    }) {
      return Transaction(
        id: id,
        type: type,
        amount: amount,
        title: title,
        merchant: merchant,
        categoryId: categoryId,
        date: date,
        source: TransactionSource.manual,
        createdAt: date,
        updatedAt: date,
      );
    }

    test('calculates key metrics accurately for current period', () {
      final period = AnalysisPeriod(
        type: AnalysisPeriodType.thisMonth,
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 30, 23, 59, 59),
      );

      final transactions = [
        makeTx(
          id: 'tx-1',
          type: TransactionType.income,
          amount: 10000000, // ₹100,000
          date: DateTime(2026, 9, 5),
          categoryId: 'salary',
        ),
        makeTx(
          id: 'tx-2',
          type: TransactionType.expense,
          amount: 3000000, // ₹30,000
          date: DateTime(2026, 9, 10),
          categoryId: 'food',
          merchant: 'Supermarket',
        ),
        makeTx(
          id: 'tx-3',
          type: TransactionType.expense,
          amount: 1000000, // ₹10,000
          date: DateTime(2026, 9, 12),
          categoryId: 'transport',
        ),
        // Outside period (August)
        makeTx(
          id: 'tx-4',
          type: TransactionType.expense,
          amount: 5000000,
          date: DateTime(2026, 8, 20),
          categoryId: 'bills',
        ),
      ];

      final data = AnalysisCalculator.calculate(
        allTransactions: transactions,
        period: period,
      );

      expect(data.metrics.totalIncomeMinor, 10000000);
      expect(data.metrics.totalExpenseMinor, 4000000);
      expect(data.metrics.netMinor, 6000000); // 100k - 40k = 60k
      expect(data.metrics.incomeCount, 1);
      expect(data.metrics.expenseCount, 2);
      expect(data.metrics.avgExpenseMinor, 2000000); // 40k / 2 = 20k
      expect(data.metrics.largestExpenseMinor, 3000000);
      expect(data.metrics.largestExpenseTransaction?.id, 'tx-2');
    });

    test('handles zero data state gracefully without errors or divisions by zero', () {
      final period = AnalysisPeriod(
        type: AnalysisPeriodType.thisMonth,
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 30, 23, 59, 59),
      );

      final data = AnalysisCalculator.calculate(
        allTransactions: [],
        period: period,
      );

      expect(data.isEmpty, isTrue);
      expect(data.metrics.totalIncomeMinor, 0);
      expect(data.metrics.totalExpenseMinor, 0);
      expect(data.metrics.netMinor, 0);
      expect(data.metrics.avgExpenseMinor, 0);
      expect(data.categoryBreakdown, isEmpty);
      expect(data.topExpenses, isEmpty);
    });

    test('computes category breakdown percentages and orders descending', () {
      final period = AnalysisPeriod(
        type: AnalysisPeriodType.thisMonth,
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 30, 23, 59, 59),
      );

      final transactions = [
        makeTx(
          id: 'tx-1',
          type: TransactionType.expense,
          amount: 600000, // ₹6,000 (60%)
          date: DateTime(2026, 9, 2),
          categoryId: 'food',
        ),
        makeTx(
          id: 'tx-2',
          type: TransactionType.expense,
          amount: 400000, // ₹4,000 (40%)
          date: DateTime(2026, 9, 3),
          categoryId: 'transport',
        ),
      ];

      final data = AnalysisCalculator.calculate(
        allTransactions: transactions,
        period: period,
      );

      expect(data.categoryBreakdown.length, 2);
      expect(data.categoryBreakdown[0].categoryId, 'food');
      expect(data.categoryBreakdown[0].percentage, 60.0);
      expect(data.categoryBreakdown[1].categoryId, 'transport');
      expect(data.categoryBreakdown[1].percentage, 40.0);
    });

    test('handles period comparison correctly when previous period has zero spending', () {
      final period = AnalysisPeriod(
        type: AnalysisPeriodType.thisMonth,
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 30, 23, 59, 59),
      );

      final currentOnly = [
        makeTx(
          id: 'tx-1',
          type: TransactionType.expense,
          amount: 100000, // ₹1,000
          date: DateTime(2026, 9, 5),
          categoryId: 'food',
        ),
      ];

      final data = AnalysisCalculator.calculate(
        allTransactions: currentOnly,
        period: period,
      );

      // Should not produce misleading 100% or infinity increase
      expect(data.comparison.expensePercentageChange, isNull);
      expect(data.comparison.expenseComparisonText, contains('₹1000 more than last month'));
    });

    test('calculates correct percentage change when previous period data exists', () {
      final period = AnalysisPeriod(
        type: AnalysisPeriodType.thisMonth,
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 30, 23, 59, 59),
      );

      final transactions = [
        // Previous month (August)
        makeTx(
          id: 'prev-1',
          type: TransactionType.expense,
          amount: 100000, // ₹1,000
          date: DateTime(2026, 8, 15),
          categoryId: 'food',
        ),
        // Current month (September): ₹1,200 = 20% higher
        makeTx(
          id: 'curr-1',
          type: TransactionType.expense,
          amount: 120000, // ₹1,200
          date: DateTime(2026, 9, 15),
          categoryId: 'food',
        ),
      ];

      final data = AnalysisCalculator.calculate(
        allTransactions: transactions,
        period: period,
      );

      expect(data.comparison.expensePercentageChange, closeTo(20.0, 0.1));
      expect(data.comparison.isExpenseHigher, isTrue);
      expect(data.comparison.expenseComparisonText, contains('20.0% higher than last month'));
    });
  });
}
