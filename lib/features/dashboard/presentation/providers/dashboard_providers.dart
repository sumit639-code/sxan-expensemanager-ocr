import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:expense_app/features/analysis/domain/entities/analysis_period.dart';
import 'package:expense_app/features/dashboard/domain/models/dashboard_summary.dart';
import 'package:expense_app/features/transactions/domain/usecases/transaction_usecases.dart';
import 'package:expense_app/features/transactions/presentation/providers/transaction_providers.dart';

/// StateProvider holding the currently selected period for the Dashboard.
///
/// Controls the Net Balance, Income/Expense totals, Spending Trend,
/// Category Breakdown, and Insights from one single source of truth.
final dashboardPeriodProvider = StateProvider<AnalysisPeriod>((ref) {
  return AnalysisPeriod.fromType(AnalysisPeriodType.thisMonth);
});

/// Reactive provider calculating [DashboardSummary] directly from SQLite Drift Stream.
///
/// Reactively updates whenever transactions are created, edited, deleted, or imported.
final dashboardDataProvider = Provider<AsyncValue<DashboardSummary>>((ref) {
  final asyncTransactions = ref.watch(watchAllTransactionsProvider);
  final period = ref.watch(dashboardPeriodProvider);

  return asyncTransactions.whenData((transactions) {
    return GetMonthlySummaryUseCase.calculateSummary(
      transactions,
      period: period,
    );
  });
});

/// Backward-compatible synchronous-access provider for [DashboardSummary].
final dashboardSummaryProvider = Provider<DashboardSummary>((ref) {
  final period = ref.watch(dashboardPeriodProvider);
  return ref.watch(dashboardDataProvider).valueOrNull ??
      DashboardSummary.empty(period, isDatabaseEmpty: true);
});
