import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:expense_app/app/theme/app_colors.dart';
import 'package:expense_app/core/constants/category_constants.dart';
import 'package:expense_app/features/analysis/domain/entities/analysis_data.dart';
import 'package:expense_app/features/transactions/presentation/providers/transaction_providers.dart';
import 'package:expense_app/shared/enums/transaction_enums.dart';

/// Interactive Category Breakdown component showing distribution of expenses
/// with tap-to-filter navigation to the transactions history screen.
class CategoryBreakdownSection extends ConsumerWidget {
  final List<CategoryBreakdownItem> items;

  const CategoryBreakdownSection({super.key, required this.items});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondaryTextColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final cardBg = isDark ? AppColors.darkSurface : AppColors.white;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        alignment: Alignment.center,
        child: Text(
          'No expenses recorded in this period',
          style: TextStyle(color: secondaryTextColor, fontSize: 13),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            Builder(
              builder: (context) {
                final item = items[i];
                final catObj = CategoryConstants.getCategoryById(
                  item.categoryId,
                  TransactionType.expense,
                );
                final amountMajor = (item.totalMinor / 100).toStringAsFixed(0);

                return InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    // Update TransactionFilter with this category and navigate to /transactions
                    final currentFilter = ref.read(transactionFilterProvider);
                    ref.read(transactionFilterProvider.notifier).state =
                        currentFilter.copyWith(
                      categoryId: item.categoryId,
                      type: TransactionType.expense,
                    );
                    context.push('/transactions');
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            // Category Icon Container
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: catObj.color.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                catObj.icon,
                                size: 16,
                                color: catObj.color,
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Name & Transaction Count
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.categoryName,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: textColor,
                                    ),
                                  ),
                                  Text(
                                    '${item.count} ${item.count == 1 ? 'transaction' : 'transactions'}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: secondaryTextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Percentage & Amount
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '₹$amountMajor',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: textColor,
                                  ),
                                ),
                                Text(
                                  '${item.percentage.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: catObj.color,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Progress Bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (item.percentage / 100).clamp(0.0, 1.0),
                            backgroundColor: isDark
                                ? AppColors.darkBackground
                                : AppColors.lightBackground,
                            valueColor: AlwaysStoppedAnimation<Color>(catObj.color),
                            minHeight: 5,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            if (i < items.length - 1)
              Divider(
                height: 12,
                thickness: 0.5,
                color: borderColor.withValues(alpha: 0.5),
              ),
          ],
        ],
      ),
    );
  }
}
