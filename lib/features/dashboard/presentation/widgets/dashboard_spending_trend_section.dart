import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../analysis/domain/entities/analysis_data.dart';
import '../../../analysis/domain/entities/analysis_period.dart';
import '../../../analysis/presentation/widgets/spending_trend_chart.dart';

/// Dashboard section displaying the adaptive spending trend chart for the selected period.
class DashboardSpendingTrendSection extends StatelessWidget {
  final AnalysisPeriod period;
  final List<TrendBucket> trendBuckets;

  const DashboardSpendingTrendSection({
    super.key,
    required this.period,
    required this.trendBuckets,
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
    final cardBg = isDark ? AppColors.darkSurface : AppColors.white;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final hasSpending = trendBuckets.any((b) => b.expenseMinor > 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Spending Trend',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: primaryTextColor,
                letterSpacing: -0.2,
              ),
            ),
            Text(
              period.displayLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: secondaryTextColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: AppSpacing.borderRadiusLarge,
            border: Border.all(color: borderColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.2)
                    : AppColors.primaryPurple.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: hasSpending
              ? SpendingTrendChart(buckets: trendBuckets)
              : SizedBox(
                  height: 140,
                  child: Center(
                    child: Text(
                      'No spending recorded in this period',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: secondaryTextColor,
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
