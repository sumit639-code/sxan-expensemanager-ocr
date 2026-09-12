import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/money_utils.dart';
import '../../../../shared/enums/transaction_enums.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';

/// Reusable transaction item tile displaying category icon, title, date metadata, and amount.
class TransactionTile extends StatelessWidget {
  final Transaction transaction;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool selectionMode;
  final bool isSelected;

  const TransactionTile({
    super.key,
    required this.transaction,
    this.onTap,
    this.onLongPress,
    this.selectionMode = false,
    this.isSelected = false,
  });

  IconData _getCategoryIcon(String? categoryId) {
    switch (categoryId?.toLowerCase()) {
      case 'food':
        return Icons.restaurant_rounded;
      case 'transport':
        return Icons.directions_car_rounded;
      case 'shopping':
        return Icons.shopping_bag_rounded;
      case 'income':
        return Icons.account_balance_wallet_rounded;
      default:
        return Icons.receipt_long_rounded;
    }
  }

  String _formatDateSubtitle(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final txDate = DateTime(date.year, date.month, date.day);

    if (txDate == today) {
      return 'Today';
    } else if (txDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else {
      return DateFormat('MMM d').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isIncome = transaction.type == TransactionType.income;

    final primaryTextColor = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final secondaryTextColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    final formattedAmount = MoneyUtils.formatMinorUnits(
      transaction.amount,
      currency: transaction.currency,
      symbol: '₹',
    );

    final sign = isIncome ? '+' : '−';
    final amountColor = isIncome ? AppColors.successGreen : primaryTextColor;

    final categoryLabel =
        transaction.merchant ?? transaction.categoryId ?? 'General';
    final subtitleText =
        '${_formatDateSubtitle(transaction.date)} · $categoryLabel';

    final primaryColor = Theme.of(context).colorScheme.primary;

    return Material(
      color: isSelected
          ? primaryColor.withValues(alpha: 0.08)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          child: Row(
            children: [
              // Selection Indicator (when in selection mode)
              if (selectionMode) ...[
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 22,
                  height: 22,
                  margin: const EdgeInsets.only(left: 4, right: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? primaryColor : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? primaryColor
                          : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: Colors.white,
                        )
                      : null,
                ),
                const SizedBox(width: 6),
              ],

              // Category Icon Badge
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isIncome
                      ? AppColors.successGreen.withValues(alpha: 0.12)
                      : AppColors.primaryPurple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _getCategoryIcon(transaction.categoryId),
                  size: 22,
                  color: isIncome
                      ? AppColors.successGreen
                      : AppColors.primaryPurple,
                ),
              ),
              const SizedBox(width: 14),

              // Title and Subtitle Metadata
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: primaryTextColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitleText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: secondaryTextColor,
                      ),
                    ),
                  ],
                ),
              ),

              // Formatted Amount
              Text(
                '$sign $formattedAmount',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: amountColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
