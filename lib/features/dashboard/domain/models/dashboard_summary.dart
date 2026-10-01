import 'package:expense_app/features/analysis/domain/entities/analysis_data.dart';
import 'package:expense_app/features/analysis/domain/entities/analysis_period.dart';
import 'package:expense_app/features/transactions/domain/entities/transaction_entity.dart';

/// Complete financial summary and analytics container for the Dashboard.
///
/// Holds aggregated figures strictly calculated in integer minor units (paise).
class DashboardSummary {
  final AnalysisPeriod period;
  final int netCashFlow; // Minor units (paise): totalIncome - totalExpense
  final int incomeTotal; // Minor units (paise)
  final int expenseTotal; // Minor units (paise)
  final PeriodComparison comparison;
  final List<TrendBucket> trendBuckets;
  final List<CategoryBreakdownItem> categoryBreakdown;
  final List<Transaction> recentTransactions;
  final Transaction? largestExpense;
  final int averageDailySpending; // Minor units (paise) per elapsed calendar day
  final List<DeterministicInsight> insights;
  final bool isDatabaseEmpty;
  final bool isPeriodEmpty;

  const DashboardSummary({
    required this.period,
    required this.netCashFlow,
    required this.incomeTotal,
    required this.expenseTotal,
    required this.comparison,
    required this.trendBuckets,
    required this.categoryBreakdown,
    required this.recentTransactions,
    this.largestExpense,
    required this.averageDailySpending,
    required this.insights,
    required this.isDatabaseEmpty,
    required this.isPeriodEmpty,
  });

  /// Alias for net cash flow for backward compatibility.
  int get totalBalance => netCashFlow;

  /// Alias for expense percentage change for backward compatibility.
  double get monthlyChangePercentage => comparison.expensePercentageChange ?? 0.0;

  /// Creates a clean empty dashboard summary for [period].
  factory DashboardSummary.empty(AnalysisPeriod period, {bool isDatabaseEmpty = true}) {
    return DashboardSummary(
      period: period,
      netCashFlow: 0,
      incomeTotal: 0,
      expenseTotal: 0,
      comparison: PeriodComparison.empty(),
      trendBuckets: const [],
      categoryBreakdown: const [],
      recentTransactions: const [],
      largestExpense: null,
      averageDailySpending: 0,
      insights: const [],
      isDatabaseEmpty: isDatabaseEmpty,
      isPeriodEmpty: true,
    );
  }
}
