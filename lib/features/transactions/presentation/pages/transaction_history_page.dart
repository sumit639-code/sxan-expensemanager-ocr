import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/utils/money_utils.dart';
import '../../../../shared/enums/transaction_enums.dart';
import '../../../dashboard/presentation/widgets/dashboard_empty_state.dart';
import '../../../dashboard/presentation/widgets/transaction_tile.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/entities/transaction_filter.dart';
import '../providers/transaction_providers.dart';
import '../widgets/transaction_filter_sheet.dart';

/// Transaction History Screen featuring reactive search, filter button with count badge,
/// removable active filter chips, quick type selector, result summary, multi-select bulk actions,
/// and date-grouped list with distinct empty states.
class TransactionHistoryPage extends ConsumerStatefulWidget {
  const TransactionHistoryPage({super.key});

  @override
  ConsumerState<TransactionHistoryPage> createState() =>
      _TransactionHistoryPageState();
}

class _TransactionHistoryPageState
    extends ConsumerState<TransactionHistoryPage> {
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Map<String, List<Transaction>> _groupTransactionsByDate(
    List<Transaction> transactions,
  ) {
    final Map<String, List<Transaction>> groups = {};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (final tx in transactions) {
      final txDate = DateTime(tx.date.year, tx.date.month, tx.date.day);
      String dateHeader;
      if (txDate == today) {
        dateHeader = 'Today';
      } else if (txDate == yesterday) {
        dateHeader = 'Yesterday';
      } else {
        dateHeader = DateFormat('MMMM d, yyyy').format(tx.date);
      }

      groups.putIfAbsent(dateHeader, () => []).add(tx);
    }
    return groups;
  }

  Future<void> _openFilterSheet() async {
    HapticFeedback.selectionClick();
    final currentFilter = ref.read(transactionFilterProvider);
    final updated = await TransactionFilterSheet.show(
      context,
      currentFilter: currentFilter,
    );
    if (updated != null) {
      ref.read(transactionFilterProvider.notifier).state = updated;
    }
  }

  void _clearAllFilters() {
    HapticFeedback.selectionClick();
    _searchController.clear();
    ref.read(transactionFilterProvider.notifier).state =
        const TransactionFilter();
  }

  Future<void> _confirmBulkDelete(
    Set<String> selectedIds,
    int selectedTotalPaise,
  ) async {
    HapticFeedback.heavyImpact();
    final count = selectedIds.length;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryTextColor =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete $count transaction${count == 1 ? '' : 's'}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              MoneyUtils.formatMinorUnits(selectedTotalPaise, symbol: '₹'),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$count selected transaction${count == 1 ? '' : 's'} will be permanently removed. This cannot be undone.',
              style: TextStyle(color: secondaryTextColor, fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.errorRed),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final idsList = selectedIds.toList();
      await ref.read(deleteTransactionsUseCaseProvider).execute(idsList);
      ref.read(selectedTransactionIdsProvider.notifier).state = {};
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$count transaction${count == 1 ? '' : 's'} deleted',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final primaryTextColor = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final secondaryTextColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.white;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final asyncAllTransactions = ref.watch(watchAllTransactionsProvider);
    final asyncFilteredTransactions = ref.watch(filteredTransactionsProvider);
    final currentFilter = ref.watch(transactionFilterProvider);
    final filteredSummary = ref.watch(filteredSummaryProvider);
    final selectedIds = ref.watch(selectedTransactionIdsProvider);
    final isSelectionMode = selectedIds.isNotEmpty;

    final currentList = asyncFilteredTransactions.valueOrNull ?? [];
    final selectedTxList =
        currentList.where((tx) => selectedIds.contains(tx.id)).toList();
    final selectedTotalPaise =
        selectedTxList.fold<int>(0, (sum, tx) => sum + tx.amount);

    final activeChips = currentFilter.getActiveChips();

    return Scaffold(
      appBar: isSelectionMode
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Cancel selection',
                onPressed: () {
                  ref.read(selectedTransactionIdsProvider.notifier).state = {};
                },
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${selectedIds.length} selected',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    MoneyUtils.formatMinorUnits(
                      selectedTotalPaise,
                      symbol: '₹',
                    ),
                    style: TextStyle(
                      fontSize: 12,
                      color: secondaryTextColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: Icon(
                    selectedIds.length == currentList.length &&
                            currentList.isNotEmpty
                        ? Icons.deselect_rounded
                        : Icons.select_all_rounded,
                  ),
                  tooltip:
                      selectedIds.length == currentList.length &&
                              currentList.isNotEmpty
                          ? 'Deselect All'
                          : 'Select All',
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    if (selectedIds.length == currentList.length) {
                      ref.read(selectedTransactionIdsProvider.notifier).state =
                          {};
                    } else {
                      ref.read(selectedTransactionIdsProvider.notifier).state =
                          currentList.map((tx) => tx.id).toSet();
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.errorRed,
                  ),
                  tooltip: 'Delete Selected',
                  onPressed: () => _confirmBulkDelete(
                    selectedIds,
                    selectedTotalPaise,
                  ),
                ),
              ],
            )
          : AppBar(
              title: const Text('Transactions'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.tune_rounded),
                  tooltip: 'Filter',
                  onPressed: _openFilterSheet,
                ),
              ],
            ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar & Filter Header (hide in selection mode to give full focus to list)
            if (!isSelectionMode)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search Bar + Filter Button
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: (val) {
                              ref
                                  .read(transactionFilterProvider.notifier)
                                  .state =
                                  currentFilter.copyWith(searchQuery: val);
                            },
                            style: TextStyle(
                              color: primaryTextColor,
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Search title, merchant, note, category...',
                              hintStyle: TextStyle(
                                color: secondaryTextColor,
                                fontSize: 13,
                              ),
                              prefixIcon: Icon(
                                Icons.search_rounded,
                                size: 20,
                                color: primaryColor,
                              ),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(
                                        Icons.clear_rounded,
                                        size: 18,
                                      ),
                                      onPressed: () {
                                        _searchController.clear();
                                        ref
                                            .read(
                                              transactionFilterProvider
                                                  .notifier,
                                            )
                                            .state = currentFilter.copyWith(
                                          searchQuery: '',
                                        );
                                      },
                                    )
                                  : null,
                              filled: true,
                              fillColor: surfaceColor,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: AppSpacing.borderRadiusPill,
                                borderSide: BorderSide(
                                  color: borderColor,
                                  width: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Filter Button with Badge
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Material(
                              color: currentFilter.activeFilterCount > 0
                                  ? primaryColor.withValues(alpha: 0.12)
                                  : surfaceColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: currentFilter.activeFilterCount > 0
                                      ? primaryColor
                                      : borderColor,
                                ),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: _openFilterSheet,
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Icon(
                                    Icons.tune_rounded,
                                    size: 20,
                                    color: currentFilter.activeFilterCount > 0
                                        ? primaryColor
                                        : secondaryTextColor,
                                  ),
                                ),
                              ),
                            ),
                            if (currentFilter.activeFilterCount > 0)
                              Positioned(
                                top: -4,
                                right: -4,
                                child: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: primaryColor,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 18,
                                    minHeight: 18,
                                  ),
                                  child: Text(
                                    '${currentFilter.activeFilterCount}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Quick Type Selector (All | Expenses | Income)
                    Row(
                      children: [
                        _FilterChipItem(
                          label: 'All',
                          isSelected: currentFilter.type == null,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            ref
                                .read(transactionFilterProvider.notifier)
                                .state = currentFilter.copyWith(clearType: true);
                          },
                        ),
                        const SizedBox(width: 8),
                        _FilterChipItem(
                          label: 'Expenses',
                          isSelected:
                              currentFilter.type == TransactionType.expense,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            ref
                                .read(transactionFilterProvider.notifier)
                                .state = currentFilter.copyWith(
                              type: TransactionType.expense,
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        _FilterChipItem(
                          label: 'Income',
                          isSelected:
                              currentFilter.type == TransactionType.income,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            ref
                                .read(transactionFilterProvider.notifier)
                                .state = currentFilter.copyWith(
                              type: TransactionType.income,
                            );
                          },
                        ),
                      ],
                    ),

                    // Active Filter Chips Bar
                    if (activeChips.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final chip in activeChips)
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: Chip(
                                  label: Text(
                                    chip.label,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: primaryTextColor,
                                    ),
                                  ),
                                  deleteIcon: const Icon(
                                    Icons.close_rounded,
                                    size: 14,
                                  ),
                                  onDeleted: () {
                                    HapticFeedback.selectionClick();
                                    ref
                                        .read(
                                          transactionFilterProvider.notifier,
                                        )
                                        .state =
                                        currentFilter.removeFilterByKey(
                                      chip.key,
                                    );
                                  },
                                  backgroundColor: primaryColor.withValues(
                                    alpha: 0.1,
                                  ),
                                  side: BorderSide(
                                    color: primaryColor.withValues(alpha: 0.3),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 0,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            TextButton(
                              onPressed: _clearAllFilters,
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                              ),
                              child: Text(
                                'Clear All',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: primaryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

            // Result Summary Bar (shows count and totals matching current filter)
            if (currentList.isNotEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatResultSummaryCount(
                        filteredSummary.count,
                        currentFilter.type,
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: secondaryTextColor,
                      ),
                    ),
                    Text(
                      _formatResultSummaryTotal(
                        filteredSummary,
                        currentFilter.type,
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: currentFilter.type == TransactionType.income
                            ? AppColors.successGreen
                            : primaryTextColor,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 4),

            // Real-time Grouped Transaction List
            Expanded(
              child: asyncFilteredTransactions.when(
                data: (transactions) {
                  final allTx = asyncAllTransactions.valueOrNull ?? [];
                  if (allTx.isEmpty) {
                    return DashboardEmptyState(
                      onAddFirstPressed: () => context.push('/add'),
                    );
                  }

                  if (transactions.isEmpty) {
                    if (currentFilter.searchQuery.trim().isNotEmpty) {
                      return _buildSearchEmptyState(
                        context,
                        isDark,
                        primaryColor,
                        currentFilter.searchQuery.trim(),
                        () {
                          _searchController.clear();
                          ref
                              .read(transactionFilterProvider.notifier)
                              .state = currentFilter.copyWith(searchQuery: '');
                        },
                      );
                    }
                    return _buildFilterEmptyState(
                      context,
                      isDark,
                      primaryColor,
                      _clearAllFilters,
                    );
                  }

                  final grouped = _groupTransactionsByDate(transactions);
                  final groupKeys = grouped.keys.toList();

                  return ListView.builder(
                    padding: const EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 4,
                      bottom: AppSpacing.navPillClearance,
                    ),
                    itemCount: groupKeys.length,
                    itemBuilder: (context, groupIndex) {
                      final header = groupKeys[groupIndex];
                      final items = grouped[header]!;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 4,
                            ),
                            child: Text(
                              header,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: secondaryTextColor,
                              ),
                            ),
                          ),
                          ...items.map((tx) {
                            final isSelected = selectedIds.contains(tx.id);
                            return TransactionTile(
                              transaction: tx,
                              selectionMode: isSelectionMode,
                              isSelected: isSelected,
                              onTap: () {
                                if (isSelectionMode) {
                                  HapticFeedback.selectionClick();
                                  final next = Set<String>.from(selectedIds);
                                  if (next.contains(tx.id)) {
                                    next.remove(tx.id);
                                  } else {
                                    next.add(tx.id);
                                  }
                                  ref
                                      .read(
                                        selectedTransactionIdsProvider.notifier,
                                      )
                                      .state = next;
                                } else {
                                  context.push('/transactions/${tx.id}');
                                }
                              },
                              onLongPress: () {
                                HapticFeedback.mediumImpact();
                                final next = Set<String>.from(selectedIds);
                                if (next.contains(tx.id)) {
                                  next.remove(tx.id);
                                } else {
                                  next.add(tx.id);
                                }
                                ref
                                    .read(
                                      selectedTransactionIdsProvider.notifier,
                                    )
                                    .state = next;
                              },
                            );
                          }),
                          const SizedBox(height: 8),
                        ],
                      );
                    },
                  );
                },
                loading: () => Center(
                  child: CircularProgressIndicator(color: primaryColor),
                ),
                error: (err, stack) => const Center(
                  child: Text('Something went wrong. Please try again.'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatResultSummaryCount(int count, TransactionType? type) {
    if (type == TransactionType.expense) {
      return '$count expense${count == 1 ? '' : 's'}';
    } else if (type == TransactionType.income) {
      return '$count income';
    }
    return '$count transaction${count == 1 ? '' : 's'}';
  }

  String _formatResultSummaryTotal(
    FilteredTransactionsSummary summary,
    TransactionType? type,
  ) {
    if (type == TransactionType.expense) {
      return MoneyUtils.formatMinorUnits(
        summary.totalExpenseMinor,
        symbol: '₹',
      );
    } else if (type == TransactionType.income) {
      return '+${MoneyUtils.formatMinorUnits(summary.totalIncomeMinor, symbol: '₹')}';
    } else {
      if (summary.totalIncomeMinor > 0 && summary.totalExpenseMinor > 0) {
        final netSign = summary.netMinor >= 0 ? '+' : '−';
        return 'Net: $netSign${MoneyUtils.formatMinorUnits(summary.netMinor.abs(), symbol: '₹')}';
      } else if (summary.totalIncomeMinor > 0) {
        return '+${MoneyUtils.formatMinorUnits(summary.totalIncomeMinor, symbol: '₹')}';
      } else {
        return MoneyUtils.formatMinorUnits(
          summary.totalExpenseMinor,
          symbol: '₹',
        );
      }
    }
  }

  Widget _buildSearchEmptyState(
    BuildContext context,
    bool isDark,
    Color primaryColor,
    String query,
    VoidCallback onClearSearch,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_off_rounded,
                size: 44,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No transactions match "$query"',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Check your spelling or try searching with different keywords.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onClearSearch,
              icon: const Icon(Icons.clear_rounded, size: 18),
              label: const Text('Clear Search'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: const RoundedRectangleBorder(
                  borderRadius: AppSpacing.borderRadiusPill,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterEmptyState(
    BuildContext context,
    bool isDark,
    Color primaryColor,
    VoidCallback onClear,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.filter_list_off_rounded,
                size: 44,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No transactions match these filters',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Try changing your category, date, or amount filters to view more records.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.clear_all_rounded, size: 18),
              label: const Text('Clear Filters'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: const RoundedRectangleBorder(
                  borderRadius: AppSpacing.borderRadiusPill,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChipItem extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChipItem({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final primaryTextColor = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor
              : (isDark ? AppColors.darkSurface : AppColors.white),
          borderRadius: AppSpacing.borderRadiusPill,
          border: Border.all(
            color: isSelected
                ? primaryColor
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? AppColors.white : primaryTextColor,
          ),
        ),
      ),
    );
  }
}
