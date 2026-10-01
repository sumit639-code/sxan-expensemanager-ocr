import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:expense_app/features/analysis/domain/entities/analysis_period.dart';
import 'package:expense_app/features/dashboard/domain/models/dashboard_summary.dart';
import 'package:expense_app/features/settings/data/services/settings_service.dart';
import 'package:expense_app/features/settings/presentation/providers/settings_providers.dart';
import 'package:expense_app/features/transactions/domain/usecases/transaction_usecases.dart';
import 'package:expense_app/features/transactions/presentation/providers/transaction_providers.dart';

/// StateNotifier managing persistent [AnalysisPeriod].
class SelectedPeriodNotifier extends StateNotifier<AnalysisPeriod> {
  final SettingsService? _service;

  SelectedPeriodNotifier([this._service])
      : super(_service?.loadSelectedPeriod() ??
            AnalysisPeriod.fromType(AnalysisPeriodType.thisMonth));

  Future<void> setPeriod(AnalysisPeriod period) async {
    state = period;
    await _service?.saveSelectedPeriod(period);
  }

  set state(AnalysisPeriod value) {
    super.state = value;
    _service?.saveSelectedPeriod(value);
  }
}

/// StateNotifierProvider holding the currently selected period for Dashboard and Analysis.
///
/// Controls the Net Balance, Income/Expense totals, Spending Trend,
/// Category Breakdown, and Insights from one single source of truth,
/// permanently persisting choices to storage.
final dashboardPeriodProvider =
    StateNotifierProvider<SelectedPeriodNotifier, AnalysisPeriod>((ref) {
  try {
    final service = ref.watch(settingsServiceProvider);
    return SelectedPeriodNotifier(service);
  } catch (_) {
    return SelectedPeriodNotifier(null);
  }
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
