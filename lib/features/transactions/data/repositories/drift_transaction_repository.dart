import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../shared/enums/transaction_enums.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/repositories/transaction_repository.dart';

/// Local Drift SQLite implementation of [TransactionRepository].
class DriftTransactionRepository implements TransactionRepository {
  final AppDatabase _db;

  DriftTransactionRepository(this._db);

  @override
  Stream<List<Transaction>> watchAllTransactions() {
    return (_db.select(_db.transactions)..orderBy([
          (tbl) => OrderingTerm(expression: tbl.date, mode: OrderingMode.desc),
        ]))
        .watch()
        .map((rows) => rows.map(_mapToEntity).toList());
  }

  @override
  Future<List<Transaction>> getAllTransactions() async {
    final query = _db.select(_db.transactions)
      ..orderBy([
        (tbl) => OrderingTerm(expression: tbl.date, mode: OrderingMode.desc),
      ]);
    final rows = await query.get();
    return rows.map(_mapToEntity).toList();
  }

  @override
  Future<Transaction?> getTransactionById(String id) async {
    final query = _db.select(_db.transactions)
      ..where((tbl) => tbl.id.equals(id));
    final row = await query.getSingleOrNull();
    return row == null ? null : _mapToEntity(row);
  }

  @override
  Future<void> addTransaction(Transaction transaction) async {
    await _db.into(_db.transactions).insert(_mapToCompanion(transaction));
  }

  @override
  Future<void> addTransactions(List<Transaction> transactions) async {
    if (transactions.isEmpty) return;
    await _db.batch((batch) {
      batch.insertAll(
        _db.transactions,
        transactions.map(_mapToCompanion).toList(),
      );
    });
  }

  @override
  Future<void> updateTransaction(Transaction transaction) async {
    await _db.update(_db.transactions).replace(_mapToCompanion(transaction));
  }

  @override
  Future<void> deleteTransaction(String id) async {
    await (_db.delete(
      _db.transactions,
    )..where((tbl) => tbl.id.equals(id))).go();
  }

  @override
  Future<void> deleteTransactions(List<String> ids) async {
    if (ids.isEmpty) return;
    await (_db.delete(
      _db.transactions,
    )..where((tbl) => tbl.id.isIn(ids))).go();
  }

  @override
  Future<List<Transaction>> getTransactionsByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final query = _db.select(_db.transactions)
      ..where((tbl) => tbl.date.isBetweenValues(start, end))
      ..orderBy([
        (tbl) => OrderingTerm(expression: tbl.date, mode: OrderingMode.desc),
      ]);
    final rows = await query.get();
    return rows.map(_mapToEntity).toList();
  }

  @override
  Future<List<Transaction>> searchTransactions(
    String query, {
    TransactionType? filterType,
  }) async {
    final q = _db.select(_db.transactions);

    q.where((tbl) {
      Expression<bool> predicate =
          tbl.title.contains(query) | tbl.merchant.contains(query);
      if (filterType != null) {
        predicate = predicate & tbl.type.equals(filterType.value);
      }
      return predicate;
    });

    q.orderBy([
      (tbl) => OrderingTerm(expression: tbl.date, mode: OrderingMode.desc),
    ]);

    final rows = await q.get();
    return rows.map(_mapToEntity).toList();
  }

  @override
  Future<void> clearAllTransactions() async {
    await _db.delete(_db.transactions).go();
  }


  Transaction _mapToEntity(TransactionData row) {
    return Transaction(
      id: row.id,
      type: TransactionType.fromString(row.type),
      amount: row.amount,
      currency: row.currency,
      title: row.title,
      merchant: row.merchant,
      categoryId: row.categoryId,
      date: row.date,
      note: row.note,
      source: TransactionSource.fromString(row.source),
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  TransactionsCompanion _mapToCompanion(Transaction transaction) {
    return TransactionsCompanion(
      id: Value(transaction.id),
      type: Value(transaction.type.value),
      amount: Value(transaction.amount),
      currency: Value(transaction.currency),
      title: Value(transaction.title),
      merchant: Value(transaction.merchant),
      categoryId: Value(transaction.categoryId),
      date: Value(transaction.date),
      note: Value(transaction.note),
      source: Value(transaction.source.value),
      createdAt: Value(transaction.createdAt),
      updatedAt: Value(transaction.updatedAt),
    );
  }
}
