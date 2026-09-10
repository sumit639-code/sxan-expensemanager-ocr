import '../../../transactions/domain/entities/transaction_entity.dart';

/// Domain summary model representing current dashboard state.
class DashboardSummary {
  final int totalBalance; // Minor units (e.g. paise)
  final int incomeTotal;
  final int expenseTotal;
  final double monthlyChangePercentage;
  final List<Transaction> recentTransactions;

  const DashboardSummary({
    required this.totalBalance,
    required this.incomeTotal,
    required this.expenseTotal,
    required this.monthlyChangePercentage,
    required this.recentTransactions,
  });
}
