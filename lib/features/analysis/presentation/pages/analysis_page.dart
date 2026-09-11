import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:expense_app/app/theme/app_colors.dart';
import 'package:expense_app/app/theme/app_spacing.dart';
import 'package:expense_app/features/analysis/domain/entities/analysis_data.dart';
import 'package:expense_app/features/analysis/presentation/providers/analysis_providers.dart';
import 'package:expense_app/features/analysis/presentation/widgets/category_breakdown_section.dart';
import 'package:expense_app/features/analysis/presentation/widgets/period_selection_sheet.dart';
import 'package:expense_app/features/analysis/presentation/widgets/spending_trend_chart.dart';
import 'package:expense_app/features/dashboard/presentation/widgets/transaction_tile.dart';

/// Financial Analytics and Insights Dashboard.
class AnalysisPage extends ConsumerWidget {
  const AnalysisPage({super.key});

  Future<void> _openPeriodPicker(BuildContext context, WidgetRef ref) async {
    final currentPeriod = ref.read(selectedAnalysisPeriodProvider);
    final selected = await PeriodSelectionSheet.show(
      context,
      currentPeriod: currentPeriod,
    );
    if (selected != null) {
      ref.read(selectedAnalysisPeriodProvider.notifier).state = selected;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondaryTextColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final cardBg = isDark ? AppColors.darkSurface : AppColors.white;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final period = ref.watch(selectedAnalysisPeriodProvider);
    final asyncAnalysis = ref.watch(analysisDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analysis'),
        actions: [
          // Period Selector Dropdown Chip
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _openPeriodPicker(context, ref),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: primaryColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 13,
                      color: primaryColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      period.displayLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_drop_down_rounded,
                      size: 18,
                      color: primaryColor,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: asyncAnalysis.when(
          data: (data) {
            if (data.periodTransactions.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 32,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.insights_rounded,
                          size: 48,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Not enough data yet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add a few transactions in ${period.displayLabel} to see your spending insights and trends.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: secondaryTextColor,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => context.push('/add'),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Add Transaction'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            final metrics = data.metrics;
            final comp = data.comparison;
            final isNetPositive = metrics.netMinor >= 0;
            final netFormatted = (metrics.netMinor.abs() / 100).toStringAsFixed(0);
            final incomeFormatted = (metrics.totalIncomeMinor / 100).toStringAsFixed(0);
            final expenseFormatted = (metrics.totalExpenseMinor / 100).toStringAsFixed(0);

            return SingleChildScrollView(
              padding: const EdgeInsets.only(
                left: 16, right: 16, top: 8,
                bottom: AppSpacing.navPillClearance,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Hero Net Balance / Cash Flow Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [
                                AppColors.darkSurface,
                                AppColors.darkSurface.withValues(alpha: 0.8),
                              ]
                            : [
                                primaryColor.withValues(alpha: 0.08),
                                primaryColor.withValues(alpha: 0.02),
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : primaryColor.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'NET CASH FLOW',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: secondaryTextColor,
                              ),
                            ),
                            if (comp.hasPreviousData)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: comp.isExpenseHigher
                                      ? AppColors.errorRed.withValues(alpha: 0.12)
                                      : (comp.isRoughlyUnchanged
                                          ? secondaryTextColor.withValues(alpha: 0.12)
                                          : AppColors.successGreen.withValues(alpha: 0.12)),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  comp.expenseComparisonText,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: comp.isExpenseHigher
                                        ? AppColors.errorRed
                                        : (comp.isRoughlyUnchanged
                                            ? secondaryTextColor
                                            : AppColors.successGreen),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${isNetPositive ? '+' : '-'}₹$netFormatted',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: isNetPositive
                                ? AppColors.successGreen
                                : AppColors.errorRed,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Income vs Expenses Split Row
                        Row(
                          children: [
                            // Income
                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: AppColors.successGreen.withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.arrow_downward_rounded,
                                      size: 14,
                                      color: AppColors.successGreen,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Income',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: secondaryTextColor,
                                        ),
                                      ),
                                      Text(
                                        '₹$incomeFormatted',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: textColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Expense
                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: AppColors.errorRed.withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.arrow_upward_rounded,
                                      size: 14,
                                      color: AppColors.errorRed,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Expenses',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: secondaryTextColor,
                                        ),
                                      ),
                                      Text(
                                        '₹$expenseFormatted',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: textColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2. Secondary Metrics (Average Expense, Largest Expense, Counts)
                  Row(
                    children: [
                      Expanded(
                        child: _MetricCard(
                          title: 'AVG EXPENSE',
                          value: '₹${(metrics.avgExpenseMinor / 100).toStringAsFixed(0)}',
                          subtitle: '${metrics.expenseCount} expenses',
                          icon: Icons.analytics_outlined,
                          isDark: isDark,
                          cardBg: cardBg,
                          borderColor: borderColor,
                          textColor: textColor,
                          secondaryTextColor: secondaryTextColor,
                          primaryColor: primaryColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MetricCard(
                          title: 'LARGEST EXPENSE',
                          value: '₹${(metrics.largestExpenseMinor / 100).toStringAsFixed(0)}',
                          subtitle: metrics.largestExpenseTransaction?.merchant ??
                              metrics.largestExpenseTransaction?.title ??
                              'None',
                          icon: Icons.military_tech_outlined,
                          isDark: isDark,
                          cardBg: cardBg,
                          borderColor: borderColor,
                          textColor: textColor,
                          secondaryTextColor: secondaryTextColor,
                          primaryColor: primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 3. Spending Trend Chart
                  _buildSectionHeader('Spending Trend', textColor),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    child: SpendingTrendChart(buckets: data.trendBuckets),
                  ),
                  const SizedBox(height: 24),

                  // 4. Expense Breakdown by Category
                  _buildSectionHeader('Expense Breakdown', textColor),
                  const SizedBox(height: 10),
                  CategoryBreakdownSection(items: data.categoryBreakdown),
                  const SizedBox(height: 24),

                  // 5. Top Expenses List
                  if (data.topExpenses.isNotEmpty) ...[
                    _buildSectionHeader('Top Expenses', textColor),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        children: [
                          for (int i = 0; i < data.topExpenses.length; i++) ...[
                            TransactionTile(
                              transaction: data.topExpenses[i],
                              onTap: () => context.push(
                                '/transactions/${data.topExpenses[i].id}',
                              ),
                            ),
                            if (i < data.topExpenses.length - 1)
                              Divider(
                                height: 1,
                                thickness: 0.5,
                                color: borderColor,
                              ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // 6. Deterministic Insights
                  if (data.insights.isNotEmpty) ...[
                    _buildSectionHeader('Insights', textColor),
                    const SizedBox(height: 10),
                    for (final insight in data.insights)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: borderColor),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _getInsightColor(insight.type, primaryColor)
                                      .withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _getInsightIcon(insight.type),
                                  size: 18,
                                  color: _getInsightColor(insight.type, primaryColor),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      insight.title,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: textColor,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      insight.message,
                                      style: TextStyle(
                                        fontSize: 12,
                                        height: 1.4,
                                        color: secondaryTextColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            );
          },
          loading: () => Center(
            child: CircularProgressIndicator(color: primaryColor),
          ),
          error: (err, stack) => const Center(
            child: Text('Failed to calculate analysis. Please try again.'),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color textColor) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: textColor,
      ),
    );
  }

  Color _getInsightColor(InsightType type, Color primaryColor) {
    switch (type) {
      case InsightType.positive:
        return AppColors.successGreen;
      case InsightType.warning:
        return AppColors.errorRed;
      case InsightType.neutral:
        return primaryColor;
    }
  }

  IconData _getInsightIcon(InsightType type) {
    switch (type) {
      case InsightType.positive:
        return Icons.auto_awesome_rounded;
      case InsightType.warning:
        return Icons.warning_amber_rounded;
      case InsightType.neutral:
        return Icons.lightbulb_outline_rounded;
    }
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final bool isDark;
  final Color cardBg;
  final Color borderColor;
  final Color textColor;
  final Color secondaryTextColor;
  final Color primaryColor;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.isDark,
    required this.cardBg,
    required this.borderColor,
    required this.textColor,
    required this.secondaryTextColor,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: secondaryTextColor,
                ),
              ),
              Icon(icon, size: 16, color: primaryColor),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: secondaryTextColor,
            ),
          ),
        ],
      ),
    );
  }
}
