import 'package:intl/intl.dart';

import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../../transactions/domain/repositories/transaction_repository.dart';
import '../entities/extracted_transaction.dart';

/// Domain service that detects duplicates between extracted transactions and
/// existing SQLite transactions, as well as duplicates within the current import batch.
class DuplicateDetector {
  final TransactionRepository _repository;

  const DuplicateDetector(this._repository);

  /// Analyzes the list of [extracted] transactions and marks any duplicates.
  ///
  /// - Duplicates with existing database entries receive [DuplicateSource.existingDb].
  /// - Duplicates within the same batch receive [DuplicateSource.intraBatch].
  ///
  /// Normalized comparisons: Lowercases and condenses whitespace for titles/merchants,
  /// compares ISO date strings (yyyy-MM-dd) and integer amounts.
  Future<List<ExtractedTransaction>> detectDuplicates(
    List<ExtractedTransaction> extracted,
  ) async {
    if (extracted.isEmpty) return const [];

    // 1. Fetch existing transactions from SQLite
    final existingTransactions = await _repository.getAllTransactions();

    // 2. Build set of fingerprints for existing transactions
    final existingFingerprints = <String>{};
    for (final tx in existingTransactions) {
      existingFingerprints.add(_generateTransactionFingerprint(tx));
    }

    // 3. Track seen fingerprints within this batch
    final seenBatchFingerprints = <String>{};
    final result = <ExtractedTransaction>[];

    for (final item in extracted) {
      final fp = item.normalizedFingerprint;

      if (existingFingerprints.contains(fp)) {
        // Matches existing database record
        result.add(
          item.copyWith(
            isDuplicate: true,
            duplicateSource: DuplicateSource.existingDb,
          ),
        );
      } else if (seenBatchFingerprints.contains(fp)) {
        // Matches a previous transaction in this import batch
        result.add(
          item.copyWith(
            isDuplicate: true,
            duplicateSource: DuplicateSource.intraBatch,
          ),
        );
      } else {
        // Unique so far
        result.add(item.copyWith(isDuplicate: false, duplicateSource: null));
      }

      seenBatchFingerprints.add(fp);
    }

    return result;
  }

  /// Generates a canonical normalized fingerprint for a database [Transaction].
  static String _generateTransactionFingerprint(Transaction tx) {
    final effectiveTitle =
        (tx.merchant?.trim().isNotEmpty == true
                ? tx.merchant!.trim()
                : tx.title.trim())
            .toLowerCase()
            .replaceAll(RegExp(r'\s+'), ' ');
    final dateKey = DateFormat('yyyy-MM-dd').format(tx.date);
    return '$dateKey|${tx.amount}|${tx.type.name}|$effectiveTitle';
  }

}
