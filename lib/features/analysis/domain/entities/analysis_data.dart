import 'package:expense_app/features/transactions/domain/entities/transaction_entity.dart';
import 'analysis_period.dart';

/// Key financial metrics for a selected period.
class AnalysisMetrics {
  final int totalIncomeMinor;
  final int totalExpenseMinor;
  final int netMinor;
  final int expenseCount;
  final int incomeCount;
  final int avgExpenseMinor;
  final int largestExpenseMinor;
  final int largestIncomeMinor;
  final Transaction? largestExpenseTransaction;

  const AnalysisMetrics({
    required this.totalIncomeMinor,
    required this.totalExpenseMinor,
    required this.netMinor,
    required this.expenseCount,
    required this.incomeCount,
    required this.avgExpenseMinor,
    required this.largestExpenseMinor,
    required this.largestIncomeMinor,
    this.largestExpenseTransaction,
  });

  factory AnalysisMetrics.empty() {
    return const AnalysisMetrics(
      totalIncomeMinor: 0,
      totalExpenseMinor: 0,
      netMinor: 0,
      expenseCount: 0,
      incomeCount: 0,
      avgExpenseMinor: 0,
      largestExpenseMinor: 0,
      largestIncomeMinor: 0,
    );
  }
}

/// Comparison metrics against the previous equivalent time window.
class PeriodComparison {
  final int prevTotalIncomeMinor;
  final int prevTotalExpenseMinor;
  final double? expensePercentageChange;
  final String expenseComparisonText;
  final bool isExpenseHigher;
  final bool isRoughlyUnchanged;
  final bool hasPreviousData;

  const PeriodComparison({
    required this.prevTotalIncomeMinor,
    required this.prevTotalExpenseMinor,
    this.expensePercentageChange,
    required this.expenseComparisonText,
    required this.isExpenseHigher,
    required this.isRoughlyUnchanged,
    required this.hasPreviousData,
  });

  factory PeriodComparison.empty() {
    return const PeriodComparison(
      prevTotalIncomeMinor: 0,
      prevTotalExpenseMinor: 0,
      expensePercentageChange: null,
      expenseComparisonText: 'No previous period data',
      isExpenseHigher: false,
      isRoughlyUnchanged: true,
      hasPreviousData: false,
    );
  }
}

/// Single bucket in the spending trend timeline (e.g. daily, weekly, monthly).
class TrendBucket {
  final String label;
  final DateTime date;
  final int expenseMinor;
  final int incomeMinor;

  const TrendBucket({
    required this.label,
    required this.date,
    required this.expenseMinor,
    required this.incomeMinor,
  });
}

/// Category distribution item for expenses.
class CategoryBreakdownItem {
  final String categoryId;
  final String categoryName;
  final int totalMinor;
  final double percentage;
  final int count;

  const CategoryBreakdownItem({
    required this.categoryId,
    required this.categoryName,
    required this.totalMinor,
    required this.percentage,
    required this.count,
  });
}

/// Insight sentiment type for visual coloring.
enum InsightType {
  positive,
  warning,
  neutral,
}

/// Rule-based deterministic financial insight derived from SQLite transactions.
class DeterministicInsight {
  final String id;
  final String title;
  final String message;
  final InsightType type;

  const DeterministicInsight({
    required this.id,
    required this.title,
    required this.message,
    this.type = InsightType.neutral,
  });
}

/// Comprehensive analysis data container for the Analysis page.
class AnalysisData {
  final AnalysisPeriod period;
  final AnalysisMetrics metrics;
  final PeriodComparison comparison;
  final List<TrendBucket> trendBuckets;
  final List<CategoryBreakdownItem> categoryBreakdown;
  final List<Transaction> topExpenses;
  final List<DeterministicInsight> insights;
  final List<Transaction> periodTransactions;

  const AnalysisData({
    required this.period,
    required this.metrics,
    required this.comparison,
    required this.trendBuckets,
    required this.categoryBreakdown,
    required this.topExpenses,
    required this.insights,
    required this.periodTransactions,
  });

  bool get isEmpty => metrics.expenseCount == 0 && metrics.incomeCount == 0;
}
