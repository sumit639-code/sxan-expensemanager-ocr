import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../../transactions/domain/repositories/transaction_repository.dart';
import '../entities/extracted_transaction.dart';

/// UseCase responsible for converting user-confirmed [ExtractedTransaction]s into
/// persistent [Transaction] entities with source=screenshot and saving them in SQLite.
class ConfirmImportUseCase {
  final TransactionRepository _repository;

  const ConfirmImportUseCase(this._repository);

  /// Validates and saves the selected [transactions].
  ///
  /// Returns the list of successfully saved [Transaction] entities.
  Future<List<Transaction>> execute(
    List<ExtractedTransaction> transactions,
  ) async {
    if (transactions.isEmpty) return const [];

    final now = DateTime.now();
    final entitiesToSave = <Transaction>[];

    for (final extracted in transactions) {
      if (!extracted.isValidForImport) {
        continue;
      }
      entitiesToSave.add(extracted.toTransactionEntity(now: now));
    }

    if (entitiesToSave.isNotEmpty) {
      await _repository.addTransactions(entitiesToSave);
    }

    return entitiesToSave;
  }
}
