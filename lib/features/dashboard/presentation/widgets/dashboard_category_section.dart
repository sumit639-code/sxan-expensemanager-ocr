import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:expense_app/app/theme/app_colors.dart';
import 'package:expense_app/app/theme/app_spacing.dart';
import 'package:expense_app/core/constants/category_constants.dart';
import 'package:expense_app/core/utils/money_utils.dart';
import 'package:expense_app/features/analysis/domain/entities/analysis_data.dart';
import 'package:expense_app/features/transactions/presentation/providers/transaction_providers.dart';
import 'package:expense_app/shared/enums/transaction_enums.dart';
import 'package:expense_app/shared/widgets/app_button.dart';
import 'package:expense_app/shared/widgets/app_section_title.dart';

/// Dashboard Category Spending Breakdown section presenting top expense categories
/// with proportional progress bars, formatted currency, and accessibility semantics.
class DashboardCategorySection extends ConsumerWidget {
  final List<CategoryBreakdownItem> items;
  final int maxDisplayCount;

  const DashboardCategorySection({
    super.key,
    required this.items,
    this.maxDisplayCount = 4,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondaryTextColor =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final cardBg = isDark ? AppColors.darkSurface : AppColors.white;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final displayItems = items.take(maxDisplayCount).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionTitle(
          title: 'Categories',
          trailing: items.length > maxDisplayCount
              ? AppButton.text(
                  label: 'View all',
                  onPressed: () => context.push('/insights'),
                )
              : null,
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: AppSpacing.borderRadiusLarge,
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Column(
            children: [
              for (int i = 0; i < displayItems.length; i++) ...[
                _buildCategoryRow(
                  context,
                  ref,
                  item: displayItems[i],
                  isDark: isDark,
                  primaryTextColor: primaryTextColor,
                  secondaryTextColor: secondaryTextColor,
                ),
                if (i < displayItems.length - 1)
                  Divider(
                    height: 16,
                    thickness: 0.5,
                    color: borderColor.withValues(alpha: 0.6),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryRow(
    BuildContext context,
    WidgetRef ref, {
    required CategoryBreakdownItem item,
    required bool isDark,
    required Color primaryTextColor,
    required Color secondaryTextColor,
  }) {
    final catObj = CategoryConstants.getCategoryById(
      item.categoryId,
      TransactionType.expense,
    );
    final formattedAmount = MoneyUtils.formatMinorUnits(
      item.totalMinor,
      currency: 'INR',
      symbol: '₹',
    );
    final pctString = item.percentage.toStringAsFixed(0);

    return Semantics(
      label: '${item.categoryName}: $formattedAmount, $pctString percent of expenses',
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          // Set filter and navigate to transactions
          final currentFilter = ref.read(transactionFilterProvider);
          ref.read(transactionFilterProvider.notifier).state =
              currentFilter.copyWith(
            categoryId: item.categoryId,
            type: TransactionType.expense,
          );
          context.push('/transactions');
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Category Icon
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

                  // Name & Transaction count
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.categoryName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: primaryTextColor,
                            letterSpacing: -0.1,
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

                  // Amount & Percentage
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formattedAmount,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: primaryTextColor,
                        ),
                      ),
                      Text(
                        '$pctString%',
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
      ),
    );
  }
}
