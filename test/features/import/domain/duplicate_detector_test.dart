import 'package:flutter_test/flutter_test.dart';
import 'package:expense_app/features/import/domain/entities/extracted_transaction.dart';
import 'package:expense_app/features/import/domain/services/duplicate_detector.dart';
import 'package:expense_app/features/transactions/domain/entities/transaction_entity.dart';
import 'package:expense_app/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:expense_app/shared/enums/transaction_enums.dart';

class FakeTransactionRepository implements TransactionRepository {
  final List<Transaction> _storage;

  FakeTransactionRepository([List<Transaction>? initial])
    : _storage = initial ?? [];

  @override
  Future<List<Transaction>> getAllTransactions() async =>
      List.unmodifiable(_storage);

  @override
  Future<void> addTransaction(Transaction transaction) async =>
      _storage.add(transaction);

  @override
  Future<void> addTransactions(List<Transaction> transactions) async =>
      _storage.addAll(transactions);

  @override
  Future<void> deleteTransaction(String id) async =>
      _storage.removeWhere((t) => t.id == id);

  @override
  Future<Transaction?> getTransactionById(String id) async =>
      _storage.firstWhere(
        (t) => t.id == id,
        orElse: () => throw StateError('Not found'),
      );

  @override
  Future<List<Transaction>> getTransactionsByDateRange(
    DateTime start,
    DateTime end,
  ) async => _storage
      .where((t) => t.date.isAfter(start) && t.date.isBefore(end))
      .toList();

  @override
  Future<List<Transaction>> searchTransactions(
    String query, {
    TransactionType? filterType,
  }) async => _storage;

  @override
  Stream<List<Transaction>> watchAllTransactions() => Stream.value(_storage);

  @override
  Future<void> updateTransaction(Transaction transaction) async {
    final idx = _storage.indexWhere((t) => t.id == transaction.id);
    if (idx != -1) _storage[idx] = transaction;
  }

  @override
  Future<void> clearAllTransactions() async {
    _storage.clear();
  }
}

void main() {
  group('DuplicateDetector', () {
    final testDate = DateTime(2026, 9, 8);

    test('detects duplicates with existing database records', () async {
      final existing = Transaction(
        id: 'db-1',
        title: 'Swiggy Food',
        merchant: 'Swiggy',
        amount: 42000,
        currency: 'INR',
        type: TransactionType.expense,
        date: testDate,
        source: TransactionSource.manual,
        createdAt: testDate,
        updatedAt: testDate,
      );

      final repo = FakeTransactionRepository([existing]);
      final detector = DuplicateDetector(repo);

      final extracted = [
        ExtractedTransaction(
          id: 'ext-1',
          merchant: 'SWIGGY',
          amount: 42000,
          date: testDate,
        ),
        ExtractedTransaction(
          id: 'ext-2',
          merchant: 'Uber',
          amount: 28000,
          date: testDate,
        ),
      ];

      final results = await detector.detectDuplicates(extracted);

      expect(results[0].isDuplicate, isTrue);
      expect(results[0].duplicateSource, DuplicateSource.existingDb);

      expect(results[1].isDuplicate, isFalse);
      expect(results[1].duplicateSource, isNull);
    });

    test(
      'detects intra-batch duplicates between multiple screenshots',
      () async {
        final repo = FakeTransactionRepository([]);
        final detector = DuplicateDetector(repo);

        final extracted = [
          ExtractedTransaction(
            id: 'ext-1',
            merchant: 'Uber Ride',
            amount: 28000,
            date: testDate,
          ),
          ExtractedTransaction(
            id: 'ext-2',
            merchant: 'Uber Ride', // Second instance of the same transaction
            amount: 28000,
            date: testDate,
          ),
        ];

        final results = await detector.detectDuplicates(extracted);

        // First occurrence is treated as unique
        expect(results[0].isDuplicate, isFalse);
        expect(results[0].duplicateSource, isNull);

        // Second occurrence is flagged as intra-batch duplicate
        expect(results[1].isDuplicate, isTrue);
        expect(results[1].duplicateSource, DuplicateSource.intraBatch);
      },
    );
  });
}
