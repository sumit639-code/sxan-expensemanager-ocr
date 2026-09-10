import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/enums/transaction_enums.dart';
import '../../../dashboard/presentation/widgets/dashboard_empty_state.dart';
import '../../../dashboard/presentation/widgets/transaction_tile.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/entities/transaction_filter.dart';
import '../providers/transaction_providers.dart';
import '../widgets/transaction_filter_sheet.dart';

/// Transaction History Screen featuring reactive search, filter button with count badge,
/// removable active filter chips, quick type selector, and date-grouped list.
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
    final activeChips = currentFilter.getActiveChips();

    return Scaffold(
      appBar: AppBar(
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
            // Search Bar & Filter Header
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
                                .state = currentFilter.copyWith(searchQuery: val);
                          },
                          style: TextStyle(
                            color: primaryTextColor,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search transactions or merchants...',
                            hintStyle: TextStyle(
                              color: secondaryTextColor,
                              fontSize: 14,
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
                                            transactionFilterProvider.notifier,
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
                                      .read(transactionFilterProvider.notifier)
                                      .state = currentFilter.removeFilterByKey(
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
                              padding: const EdgeInsets.symmetric(horizontal: 8),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
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
                            return TransactionTile(
                              transaction: tx,
                              onTap: () =>
                                  context.push('/transactions/${tx.id}'),
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
                Icons.search_off_rounded,
                size: 44,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No transactions found',
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
              'No transactions match your active search or filters. Try adjusting your criteria.',
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
