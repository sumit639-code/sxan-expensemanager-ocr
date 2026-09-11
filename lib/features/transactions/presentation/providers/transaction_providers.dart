import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_provider.dart';
import '../../../../shared/enums/transaction_enums.dart';
import '../../data/repositories/drift_transaction_repository.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/entities/transaction_filter.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../../domain/usecases/transaction_usecases.dart';

/// Provider exposing [TransactionRepository].
final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return DriftTransactionRepository(db);
});

// Use Case Providers
final addTransactionUseCaseProvider = Provider<AddTransactionUseCase>((ref) {
  return AddTransactionUseCase(ref.watch(transactionRepositoryProvider));
});

final updateTransactionUseCaseProvider = Provider<UpdateTransactionUseCase>((
  ref,
) {
  return UpdateTransactionUseCase(ref.watch(transactionRepositoryProvider));
});

final deleteTransactionUseCaseProvider = Provider<DeleteTransactionUseCase>((
  ref,
) {
  return DeleteTransactionUseCase(ref.watch(transactionRepositoryProvider));
});

final getTransactionUseCaseProvider = Provider<GetTransactionUseCase>((ref) {
  return GetTransactionUseCase(ref.watch(transactionRepositoryProvider));
});

/// Real-time stream provider of all transactions from Drift SQLite.
final watchAllTransactionsProvider = StreamProvider<List<Transaction>>((ref) {
  final repo = ref.watch(transactionRepositoryProvider);
  return repo.watchAllTransactions();
});

/// StateNotifier/StateProvider for active TransactionFilter.
final transactionFilterProvider = StateProvider<TransactionFilter>((ref) {
  return const TransactionFilter();
});

/// Backward-compatible Search Query state provider that syncs with TransactionFilter.
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Backward-compatible filter type provider that syncs with TransactionFilter.
final filterTypeProvider = StateProvider<TransactionType?>((ref) => null);

/// Filter helper function to evaluate whether a transaction matches a given [TransactionFilter].
bool matchesTransactionFilter(Transaction tx, TransactionFilter filter, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final q = filter.searchQuery.trim().toLowerCase();

  // Search query (title, merchant, note)
  if (q.isNotEmpty) {
    final matchTitle = tx.title.toLowerCase().contains(q);
    final matchMerchant = tx.merchant != null && tx.merchant!.toLowerCase().contains(q);
    final matchNote = tx.note != null && tx.note!.toLowerCase().contains(q);
    if (!matchTitle && !matchMerchant && !matchNote) {
      return false;
    }
  }

  // Type filter
  if (filter.type != null && tx.type != filter.type) {
    return false;
  }

  // Category filter
  if (filter.categoryId != null && filter.categoryId!.isNotEmpty) {
    if (tx.categoryId?.toLowerCase() != filter.categoryId!.toLowerCase()) {
      return false;
    }
  }

  // Source filter
  if (filter.source != null && tx.source != filter.source) {
    return false;
  }

  // Amount filter
  switch (filter.amountPreset) {
    case AmountFilterPreset.all:
      break;
    case AmountFilterPreset.under500:
      if (tx.amount >= 50000) return false;
      break;
    case AmountFilterPreset.between500And1000:
      if (tx.amount < 50000 || tx.amount > 100000) return false;
      break;
    case AmountFilterPreset.between1000And5000:
      if (tx.amount < 100000 || tx.amount > 500000) return false;
      break;
    case AmountFilterPreset.above5000:
      if (tx.amount <= 500000) return false;
      break;
    case AmountFilterPreset.custom:
      if (filter.customMinAmountMinor != null &&
          tx.amount < filter.customMinAmountMinor!) {
        return false;
      }
      if (filter.customMaxAmountMinor != null &&
          tx.amount > filter.customMaxAmountMinor!) {
        return false;
      }
      break;
  }

  // Date filter
  final txDate = tx.date;
  switch (filter.datePreset) {
    case DateFilterPreset.all:
      break;
    case DateFilterPreset.today:
      final start = DateTime(current.year, current.month, current.day);
      final end = DateTime(current.year, current.month, current.day, 23, 59, 59, 999);
      if (txDate.isBefore(start) || txDate.isAfter(end)) return false;
      break;
    case DateFilterPreset.yesterday:
      final y = current.subtract(const Duration(days: 1));
      final start = DateTime(y.year, y.month, y.day);
      final end = DateTime(y.year, y.month, y.day, 23, 59, 59, 999);
      if (txDate.isBefore(start) || txDate.isAfter(end)) return false;
      break;
    case DateFilterPreset.thisWeek:
      final startOfWeek = current.subtract(Duration(days: current.weekday - 1));
      final start = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
      final end = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day + 6, 23, 59, 59, 999);
      if (txDate.isBefore(start) || txDate.isAfter(end)) return false;
      break;
    case DateFilterPreset.thisMonth:
      final start = DateTime(current.year, current.month, 1);
      final lastDay = DateTime(current.year, current.month + 1, 0).day;
      final end = DateTime(current.year, current.month, lastDay, 23, 59, 59, 999);
      if (txDate.isBefore(start) || txDate.isAfter(end)) return false;
      break;
    case DateFilterPreset.lastMonth:
      final prevMonthDate = DateTime(current.year, current.month - 1, 1);
      final start = DateTime(prevMonthDate.year, prevMonthDate.month, 1);
      final lastDay = DateTime(prevMonthDate.year, prevMonthDate.month + 1, 0).day;
      final end = DateTime(prevMonthDate.year, prevMonthDate.month, lastDay, 23, 59, 59, 999);
      if (txDate.isBefore(start) || txDate.isAfter(end)) return false;
      break;
    case DateFilterPreset.custom:
      if (filter.customStartDate != null) {
        final start = DateTime(
          filter.customStartDate!.year,
          filter.customStartDate!.month,
          filter.customStartDate!.day,
        );
        if (txDate.isBefore(start)) return false;
      }
      if (filter.customEndDate != null) {
        final end = DateTime(
          filter.customEndDate!.year,
          filter.customEndDate!.month,
          filter.customEndDate!.day,
          23,
          59,
          59,
          999,
        );
        if (txDate.isAfter(end)) return false;
      }
      break;
  }

  return true;
}

/// Helper function to sort transactions based on [TransactionSortOrder].
List<Transaction> sortTransactions(List<Transaction> transactions, TransactionSortOrder sortOrder) {
  final copy = List<Transaction>.from(transactions);
  switch (sortOrder) {
    case TransactionSortOrder.newestFirst:
      copy.sort((a, b) {
        final cmp = b.date.compareTo(a.date);
        return cmp != 0 ? cmp : b.createdAt.compareTo(a.createdAt);
      });
      break;
    case TransactionSortOrder.oldestFirst:
      copy.sort((a, b) {
        final cmp = a.date.compareTo(b.date);
        return cmp != 0 ? cmp : a.createdAt.compareTo(b.createdAt);
      });
      break;
    case TransactionSortOrder.highestAmount:
      copy.sort((a, b) => b.amount.compareTo(a.amount));
      break;
    case TransactionSortOrder.lowestAmount:
      copy.sort((a, b) => a.amount.compareTo(b.amount));
      break;
    case TransactionSortOrder.aToZ:
      copy.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      break;
    case TransactionSortOrder.zToA:
      copy.sort((a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()));
      break;
  }
  return copy;
}

/// Reactive provider delivering filtered & sorted transactions according to [TransactionFilter].
final filteredTransactionsProvider = Provider<AsyncValue<List<Transaction>>>((
  ref,
) {
  final asyncTransactions = ref.watch(watchAllTransactionsProvider);
  final filter = ref.watch(transactionFilterProvider);

  return asyncTransactions.whenData((transactions) {
    final filtered = transactions.where((tx) => matchesTransactionFilter(tx, filter)).toList();
    return sortTransactions(filtered, filter.sortOrder);
  });
});


