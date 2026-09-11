import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:expense_app/app/theme/app_colors.dart';
import 'package:expense_app/app/theme/app_spacing.dart';
import 'package:expense_app/core/utils/money_utils.dart';
import 'package:expense_app/features/analysis/domain/entities/analysis_data.dart';
import 'package:expense_app/features/transactions/domain/entities/transaction_entity.dart';
import 'package:expense_app/shared/widgets/app_button.dart';
import 'package:expense_app/shared/widgets/app_section_title.dart';

/// Clean, deterministic smart insights section on the dashboard.
///
/// Features rule-based financial insights derived from local SQLite transactions.
class DashboardInsightsSection extends StatelessWidget {
  final List<DeterministicInsight> insights;
  final Transaction? largestExpense;
  final int averageDailySpending;
  final int maxDisplayCount;

  const DashboardInsightsSection({
    super.key,
    required this.insights,
    this.largestExpense,
    this.averageDailySpending = 0,
    this.maxDisplayCount = 2,
  });

  @override
  Widget build(BuildContext context) {
    if (insights.isEmpty && largestExpense == null && averageDailySpending == 0) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondaryTextColor =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final cardBg = isDark ? AppColors.darkSurface : AppColors.white;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final displayInsights = insights.take(maxDisplayCount).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionTitle(
          title: 'Insights',
          trailing: AppButton.text(
            label: 'More',
            onPressed: () => context.push('/insights'),
          ),
        ),
        const SizedBox(height: 10),
        Column(
          children: [
            for (final insight in displayInsights) ...[
              _buildInsightCard(
                insight: insight,
                isDark: isDark,
                cardBg: cardBg,
                borderColor: borderColor,
                primaryTextColor: primaryTextColor,
                secondaryTextColor: secondaryTextColor,
              ),
              const SizedBox(height: 10),
            ],
            // Additional Quick Metric Chips (Average daily spending / Largest expense)
            if (averageDailySpending > 0 || largestExpense != null)
              Row(
                children: [
                  if (averageDailySpending > 0)
                    Expanded(
                      child: _buildMetricTile(
                        title: 'Daily Average',
                        value: MoneyUtils.formatMinorUnits(
                          averageDailySpending,
                          currency: 'INR',
                          symbol: '₹',
                        ),
                        icon: Icons.calendar_today_rounded,
                        isDark: isDark,
                        cardBg: cardBg,
                        borderColor: borderColor,
                        primaryTextColor: primaryTextColor,
                        secondaryTextColor: secondaryTextColor,
                      ),
                    ),
                  if (averageDailySpending > 0 && largestExpense != null)
                    const SizedBox(width: 10),
                  if (largestExpense != null)
                    Expanded(
                      child: _buildMetricTile(
                        title: 'Largest Expense',
                        value: MoneyUtils.formatMinorUnits(
                          largestExpense!.amount,
                          currency: 'INR',
                          symbol: '₹',
                        ),
                        subtitle: largestExpense!.merchant?.isNotEmpty == true
                            ? largestExpense!.merchant!
                            : largestExpense!.title,
                        icon: Icons.local_fire_department_rounded,
                        iconColor: AppColors.warningAmber,
                        isDark: isDark,
                        cardBg: cardBg,
                        borderColor: borderColor,
                        primaryTextColor: primaryTextColor,
                        secondaryTextColor: secondaryTextColor,
                      ),
                    ),
                ],
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildInsightCard({
    required DeterministicInsight insight,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color primaryTextColor,
    required Color secondaryTextColor,
  }) {
    IconData icon;
    Color accentColor;

    switch (insight.type) {
      case InsightType.positive:
        icon = Icons.trending_up_rounded;
        accentColor = AppColors.successGreen;
        break;
      case InsightType.warning:
        icon = Icons.info_outline_rounded;
        accentColor = AppColors.warningAmber;
        break;
      case InsightType.neutral:
        icon = Icons.insights_rounded;
        accentColor = AppColors.primaryPurple;
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: AppSpacing.borderRadiusLarge,
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accentColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: primaryTextColor,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  insight.message,
                  style: TextStyle(
                    fontSize: 12,
                    color: secondaryTextColor,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    String? subtitle,
    required IconData icon,
    Color? iconColor,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color primaryTextColor,
    required Color secondaryTextColor,
  }) {
    final color = iconColor ?? AppColors.primaryPurple;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: AppSpacing.borderRadiusLarge,
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: secondaryTextColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: primaryTextColor,
              letterSpacing: -0.2,
            ),
          ),
          if (subtitle != null && subtitle.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: secondaryTextColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
