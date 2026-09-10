import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:expense_app/features/analysis/domain/entities/analysis_data.dart';
import 'package:expense_app/features/analysis/domain/entities/analysis_period.dart';
import 'package:expense_app/features/analysis/domain/services/analysis_calculator.dart';
import 'package:expense_app/features/transactions/presentation/providers/transaction_providers.dart';

/// StateProvider holding the currently selected [AnalysisPeriod].
final selectedAnalysisPeriodProvider = StateProvider<AnalysisPeriod>((ref) {
  return AnalysisPeriod.fromType(AnalysisPeriodType.thisMonth);
});

/// Reactive provider calculating [AnalysisData] whenever SQLite transactions or selected period changes.
final analysisDataProvider = Provider<AsyncValue<AnalysisData>>((ref) {
  final asyncTransactions = ref.watch(watchAllTransactionsProvider);
  final period = ref.watch(selectedAnalysisPeriodProvider);

  return asyncTransactions.whenData((transactions) {
    return AnalysisCalculator.calculate(
      allTransactions: transactions,
      period: period,
    );
  });
});
