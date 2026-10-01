import '../../../../shared/enums/transaction_enums.dart';
import '../entities/transaction_entity.dart';

/// Contract interface for managing transaction persistence.
abstract class TransactionRepository {
  Stream<List<Transaction>> watchAllTransactions();
  Future<List<Transaction>> getAllTransactions();
  Future<Transaction?> getTransactionById(String id);
  Future<void> addTransaction(Transaction transaction);
  Future<void> addTransactions(List<Transaction> transactions);
  Future<void> updateTransaction(Transaction transaction);
  Future<void> deleteTransaction(String id);
  Future<void> deleteTransactions(List<String> ids);
  Future<List<Transaction>> getTransactionsByDateRange(
    DateTime start,
    DateTime end,
  );
  Future<List<Transaction>> searchTransactions(
    String query, {
    TransactionType? filterType,
  });
  Future<void> clearAllTransactions();
}

