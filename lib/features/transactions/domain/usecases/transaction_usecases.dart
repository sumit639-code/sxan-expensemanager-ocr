import '../../../../shared/enums/transaction_enums.dart';
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

  Future<DashboardSummary> execute() async {
    final transactions = await _repository.getAllTransactions();
    return calculateSummary(transactions);
  }

  static DashboardSummary calculateSummary(List<Transaction> transactions) {
    int totalIncome = 0;
    int totalExpense = 0;

    for (final tx in transactions) {
      if (tx.type == TransactionType.income) {
        totalIncome += tx.amount;
      } else {
        totalExpense += tx.amount;
      }
    }

    final totalBalance = totalIncome - totalExpense;
    final recent = transactions.take(4).toList();

    return DashboardSummary(
      totalBalance: totalBalance,
      incomeTotal: totalIncome,
      expenseTotal: totalExpense,
      monthlyChangePercentage: 12.0,
      recentTransactions: recent,
    );
  }
}
