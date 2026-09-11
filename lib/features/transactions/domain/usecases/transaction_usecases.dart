import 'package:expense_app/features/analysis/domain/entities/analysis_period.dart';
import 'package:expense_app/features/analysis/domain/services/analysis_calculator.dart';
import '../../../dashboard/domain/models/dashboard_summary.dart';
import '../entities/transaction_entity.dart';
import '../repositories/transaction_repository.dart';

class AddTransactionUseCase {
  final TransactionRepository _repository;
  AddTransactionUseCase(this._repository);

  Future<void> execute(Transaction transaction) async {
    if (transaction.amount <= 0) {
      throw ArgumentError('Transaction amount must be greater than zero');
    }
    if (transaction.title.trim().isEmpty) {
      throw ArgumentError('Transaction title cannot be empty');
    }
    await _repository.addTransaction(transaction);
  }
}

class UpdateTransactionUseCase {
  final TransactionRepository _repository;
  UpdateTransactionUseCase(this._repository);

  Future<void> execute(Transaction transaction) async {
    if (transaction.amount <= 0) {
      throw ArgumentError('Transaction amount must be greater than zero');
    }
    if (transaction.title.trim().isEmpty) {
      throw ArgumentError('Transaction title cannot be empty');
    }
    await _repository.updateTransaction(transaction);
  }
}

class DeleteTransactionUseCase {
  final TransactionRepository _repository;
  DeleteTransactionUseCase(this._repository);

  Future<void> execute(String id) async {
    await _repository.deleteTransaction(id);
  }
}

class GetTransactionUseCase {
  final TransactionRepository _repository;
  GetTransactionUseCase(this._repository);

  Future<Transaction?> execute(String id) async {
    return await _repository.getTransactionById(id);
  }
}

class GetTransactionsUseCase {
  final TransactionRepository _repository;
  GetTransactionsUseCase(this._repository);

  Future<List<Transaction>> execute() async {
    return await _repository.getAllTransactions();
  }
}

class GetMonthlySummaryUseCase {
  final TransactionRepository _repository;
  GetMonthlySummaryUseCase(this._repository);

  Future<DashboardSummary> execute({AnalysisPeriod? period}) async {
    final transactions = await _repository.getAllTransactions();
    return calculateSummary(transactions, period: period);
  }

  static DashboardSummary calculateSummary(
    List<Transaction> allTransactions, {
    AnalysisPeriod? period,
    DateTime? referenceDate,
  }) {
    final targetPeriod = period ??
        AnalysisPeriod.fromType(
          AnalysisPeriodType.thisMonth,
          referenceDate: referenceDate,
        );
    final now = referenceDate ?? DateTime.now();
    final isDatabaseEmpty = allTransactions.isEmpty;

    // Pure deterministic calculation from SQLite transactions
    final analysis = AnalysisCalculator.calculate(
      allTransactions: allTransactions,
      period: targetPeriod,
      referenceDate: now,
    );

    // Recent transactions sorted newest first, top 5
    final sortedAll = List<Transaction>.from(allTransactions)
      ..sort((a, b) => b.date.compareTo(a.date));
    final recent = sortedAll.take(5).toList();

    // Average daily spending (calendar days elapsed in period)
    int avgDailySpending = 0;
    final totalExpense = analysis.metrics.totalExpenseMinor;
    if (totalExpense > 0) {
      final totalCalendarDays =
          targetPeriod.endDate.difference(targetPeriod.startDate).inDays + 1;
      int daysElapsed = totalCalendarDays;
      if (!now.isBefore(targetPeriod.startDate) &&
          !now.isAfter(targetPeriod.endDate)) {
        daysElapsed = now.difference(targetPeriod.startDate).inDays + 1;
      }
      if (daysElapsed <= 0) daysElapsed = 1;
      avgDailySpending = (totalExpense / daysElapsed).round();
    }

    return DashboardSummary(
      period: targetPeriod,
      netCashFlow: analysis.metrics.netMinor,
      incomeTotal: analysis.metrics.totalIncomeMinor,
      expenseTotal: analysis.metrics.totalExpenseMinor,
      comparison: analysis.comparison,
      trendBuckets: analysis.trendBuckets,
      categoryBreakdown: analysis.categoryBreakdown,
      recentTransactions: recent,
      largestExpense: analysis.metrics.largestExpenseTransaction,
      averageDailySpending: avgDailySpending,
      insights: analysis.insights,
      isDatabaseEmpty: isDatabaseEmpty,
      isPeriodEmpty: analysis.periodTransactions.isEmpty,
    );
  }
}
