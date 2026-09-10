import 'package:intl/intl.dart';

import '../../../../shared/enums/transaction_enums.dart';

/// Preset date filtering options.
enum DateFilterPreset {
  all('All Time'),
  today('Today'),
  yesterday('Yesterday'),
  thisWeek('This Week'),
  thisMonth('This Month'),
  lastMonth('Last Month'),
  custom('Custom Range');

  final String label;
  const DateFilterPreset(this.label);
}

/// Preset amount filtering options (amounts in major INR units).
enum AmountFilterPreset {
  all('Any Amount'),
  under500('Under ₹500'),
  between500And1000('₹500 – ₹1,000'),
  between1000And5000('₹1,000 – ₹5,000'),
  above5000('Above ₹5,000'),
  custom('Custom Amount');

  final String label;
  const AmountFilterPreset(this.label);
}

/// Available sorting modes for transaction history.
enum TransactionSortOrder {
  newestFirst('Newest First'),
  oldestFirst('Oldest First'),
  highestAmount('Highest Amount'),
  lowestAmount('Lowest Amount'),
  aToZ('A to Z (Title)'),
  zToA('Z to A (Title)');

  final String label;
  const TransactionSortOrder(this.label);
}

/// Representation of an active removable filter chip on the UI.
class ActiveFilterChipData {
  final String key;
  final String label;

  const ActiveFilterChipData({required this.key, required this.label});
}

/// Immutable domain model capturing all active transaction filter and sort parameters.
class TransactionFilter {
  final TransactionType? type;
  final DateFilterPreset datePreset;
  final DateTime? customStartDate;
  final DateTime? customEndDate;
  final String? categoryId;
  final AmountFilterPreset amountPreset;
  final int? customMinAmountMinor;
  final int? customMaxAmountMinor;
  final TransactionSource? source;
  final String searchQuery;
  final TransactionSortOrder sortOrder;

  const TransactionFilter({
    this.type,
    this.datePreset = DateFilterPreset.all,
    this.customStartDate,
    this.customEndDate,
    this.categoryId,
    this.amountPreset = AmountFilterPreset.all,
    this.customMinAmountMinor,
    this.customMaxAmountMinor,
    this.source,
    this.searchQuery = '',
    this.sortOrder = TransactionSortOrder.newestFirst,
  });

  /// Calculates the count of active filter constraints.
  int get activeFilterCount {
    int count = 0;
    if (type != null) count++;
    if (datePreset != DateFilterPreset.all) count++;
    if (categoryId != null && categoryId!.isNotEmpty) count++;
    if (amountPreset != AmountFilterPreset.all) count++;
    if (source != null) count++;
    if (sortOrder != TransactionSortOrder.newestFirst) count++;
    return count;
  }

  bool get isFiltered => activeFilterCount > 0 || searchQuery.trim().isNotEmpty;

  /// Returns list of active filter chips for display in the horizontal chip bar.
  List<ActiveFilterChipData> getActiveChips() {
    final chips = <ActiveFilterChipData>[];

    if (type != null) {
      chips.add(
        ActiveFilterChipData(
          key: 'type',
          label: type == TransactionType.expense ? 'Expenses' : 'Income',
        ),
      );
    }

    if (datePreset != DateFilterPreset.all) {
      if (datePreset == DateFilterPreset.custom &&
          customStartDate != null &&
          customEndDate != null) {
        final df = DateFormat('MMM d');
        chips.add(
          ActiveFilterChipData(
            key: 'date',
            label: '${df.format(customStartDate!)} - ${df.format(customEndDate!)}',
          ),
        );
      } else {
        chips.add(ActiveFilterChipData(key: 'date', label: datePreset.label));
      }
    }

    if (categoryId != null && categoryId!.isNotEmpty) {
      chips.add(ActiveFilterChipData(key: 'category', label: categoryId!));
    }

    if (amountPreset != AmountFilterPreset.all) {
      if (amountPreset == AmountFilterPreset.custom) {
        final minStr = customMinAmountMinor != null
            ? '₹${(customMinAmountMinor! / 100).toInt()}'
            : '₹0';
        final maxStr = customMaxAmountMinor != null
            ? '₹${(customMaxAmountMinor! / 100).toInt()}'
            : '∞';
        chips.add(ActiveFilterChipData(key: 'amount', label: '$minStr – $maxStr'));
      } else {
        chips.add(ActiveFilterChipData(key: 'amount', label: amountPreset.label));
      }
    }

    if (source != null) {
      chips.add(ActiveFilterChipData(key: 'source', label: 'Source: ${source!.value}'));
    }

    if (sortOrder != TransactionSortOrder.newestFirst) {
      chips.add(ActiveFilterChipData(key: 'sort', label: sortOrder.label));
    }

    return chips;
  }

  /// Removes a specific active filter by key.
  TransactionFilter removeFilterByKey(String key) {
    switch (key) {
      case 'type':
        return copyWith(clearType: true);
      case 'date':
        return copyWith(datePreset: DateFilterPreset.all, clearCustomDates: true);
      case 'category':
        return copyWith(clearCategory: true);
      case 'amount':
        return copyWith(amountPreset: AmountFilterPreset.all, clearCustomAmounts: true);
      case 'source':
        return copyWith(clearSource: true);
      case 'sort':
        return copyWith(sortOrder: TransactionSortOrder.newestFirst);
      default:
        return this;
    }
  }

  /// Clears all filters and resets to defaults while preserving current search text.
  TransactionFilter clearAll() {
    return TransactionFilter(searchQuery: searchQuery);
  }

  TransactionFilter copyWith({
    TransactionType? type,
    bool clearType = false,
    DateFilterPreset? datePreset,
    DateTime? customStartDate,
    DateTime? customEndDate,
    bool clearCustomDates = false,
    String? categoryId,
    bool clearCategory = false,
    AmountFilterPreset? amountPreset,
    int? customMinAmountMinor,
    int? customMaxAmountMinor,
    bool clearCustomAmounts = false,
    TransactionSource? source,
    bool clearSource = false,
    String? searchQuery,
    TransactionSortOrder? sortOrder,
  }) {
    return TransactionFilter(
      type: clearType ? null : (type ?? this.type),
      datePreset: datePreset ?? this.datePreset,
      customStartDate:
          clearCustomDates ? null : (customStartDate ?? this.customStartDate),
      customEndDate:
          clearCustomDates ? null : (customEndDate ?? this.customEndDate),
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      amountPreset: amountPreset ?? this.amountPreset,
      customMinAmountMinor: clearCustomAmounts
          ? null
          : (customMinAmountMinor ?? this.customMinAmountMinor),
      customMaxAmountMinor: clearCustomAmounts
          ? null
          : (customMaxAmountMinor ?? this.customMaxAmountMinor),
      source: clearSource ? null : (source ?? this.source),
      searchQuery: searchQuery ?? this.searchQuery,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}
