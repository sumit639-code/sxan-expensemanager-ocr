import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/money_utils.dart';
import '../../../../shared/widgets/app_card.dart';

/// Side-by-side compact cards for Income and Expenses totals.
class IncomeExpenseSummary extends StatelessWidget {
  final int incomeMinorUnits;
  final int expenseMinorUnits;

  const IncomeExpenseSummary({
    super.key,
    required this.incomeMinorUnits,
    required this.expenseMinorUnits,
  });

  @override
  Widget build(BuildContext context) {
    final formattedIncome = MoneyUtils.formatMinorUnits(
      incomeMinorUnits,
      currency: 'INR',
      symbol: '₹',
    );
    final formattedExpense = MoneyUtils.formatMinorUnits(
      expenseMinorUnits,
      currency: 'INR',
      symbol: '₹',
    );

    return Row(
      children: [
        // Income Card
        Expanded(
          child: _SummaryCard(
            title: 'Income',
            amount: formattedIncome,
            icon: Icons.south_west_rounded,
            iconColor: AppColors.successGreen,
          ),
        ),
        const SizedBox(width: 12),
        // Expense Card
        Expanded(
          child: _SummaryCard(
            title: 'Expenses',
            amount: formattedExpense,
            icon: Icons.north_east_rounded,
            iconColor: AppColors.errorRed,
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String amount;
  final IconData icon;
  final Color iconColor;

  const _SummaryCard({
    required this.title,
    required this.amount,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final secondaryTextColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: secondaryTextColor,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    amount,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: primaryTextColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
