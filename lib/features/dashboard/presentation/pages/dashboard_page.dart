import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../analysis/domain/entities/analysis_period.dart';
import '../../../analysis/presentation/widgets/period_selection_sheet.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../providers/dashboard_providers.dart';
import '../widgets/balance_card.dart';
import '../widgets/dashboard_category_section.dart';
import '../widgets/dashboard_empty_state.dart';
import '../widgets/dashboard_header.dart';
import '../widgets/dashboard_insights_section.dart';
import '../widgets/dashboard_spending_trend_section.dart';
import '../widgets/quick_actions.dart';
import '../widgets/recent_transactions.dart';

/// Main Dashboard Page presenting real-time user balance, period filtering,
/// spending trends, category breakdown, smart insights, and recent activity from SQLite.
class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {

  Future<void> _selectPeriod(AnalysisPeriod currentPeriod) async {
    final newPeriod = await PeriodSelectionSheet.show(
      context,
      currentPeriod: currentPeriod,
    );
    if (newPeriod != null && mounted) {
      ref.read(dashboardPeriodProvider.notifier).state = newPeriod;
    }
  }

  @override
  Widget build(BuildContext context) {
    final userName = ref.watch(userNameProvider);
    final selectedPeriod = ref.watch(dashboardPeriodProvider);
    final asyncSummary = ref.watch(dashboardDataProvider);
    final dashPrefs = ref.watch(dashboardPreferencesProvider);

    final bodyWidget = asyncSummary.when(
      data: (summary) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: AppSpacing.navPillClearance,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DashboardHeader(
                userName: userName,
                selectedPeriod: selectedPeriod,
                onAvatarPressed: () => context.push('/settings'),
                onPeriodPressed: () => _selectPeriod(selectedPeriod),
              ),

              // Full Database Empty State (Onboarding)
              if (summary.isDatabaseEmpty) ...[
                const SizedBox(height: 24),
                DashboardEmptyState(
                  isPeriodFiltered: false,
                  onAddFirstPressed: () =>
                      context.push('/add?type=expense'),
                ),
              ] else ...[
                // Balance / Net Cash Flow Card
                if (dashPrefs.showBalance) ...[
                  const SizedBox(height: 18),
                  BalanceCard(
                    netCashFlowMinor: summary.netCashFlow,
                    incomeMinor: summary.incomeTotal,
                    expenseMinor: summary.expenseTotal,
                    comparison: summary.comparison,
                  ),
                ],

                // Quick Actions
                if (dashPrefs.showQuickActions) ...[
                  const SizedBox(height: 20),
                  const QuickActions(),
                ],

                // Period Empty Notice
                if (summary.isPeriodEmpty) ...[
                  const SizedBox(height: 20),
                  DashboardEmptyState(
                    isPeriodFiltered: true,
                    periodName: selectedPeriod.displayLabel,
                    onResetPeriodPressed: () {
                      ref.read(dashboardPeriodProvider.notifier).state =
                          AnalysisPeriod.fromType(AnalysisPeriodType.thisMonth);
                    },
                    onAddFirstPressed: () =>
                        context.push('/add?type=expense'),
                  ),
                ] else ...[
                  // Spending Trend Section
                  const SizedBox(height: 24),
                  DashboardSpendingTrendSection(
                    trendBuckets: summary.trendBuckets,
                    period: selectedPeriod,
                  ),

                  // Categories Breakdown Section
                  if (summary.categoryBreakdown.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    DashboardCategorySection(
                      items: summary.categoryBreakdown,
                      maxDisplayCount: 4,
                    ),
                  ],

                  // Smart Deterministic Insights
                  if (summary.insights.isNotEmpty ||
                      summary.largestExpense != null ||
                      summary.averageDailySpending > 0) ...[
                    const SizedBox(height: 24),
                    DashboardInsightsSection(
                      insights: summary.insights,
                      largestExpense: summary.largestExpense,
                      averageDailySpending: summary.averageDailySpending,
                      maxDisplayCount: 2,
                    ),
                  ],
                ],

                // Recent Transactions
                if (dashPrefs.showRecentTransactions &&
                    summary.recentTransactions.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  RecentTransactions(
                    transactions: summary.recentTransactions,
                    onAddFirstPressed: () =>
                        context.push('/add?type=expense'),
                  ),
                ],
              ],
              const SizedBox(height: 24),
            ],
          ),
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primaryPurple),
      ),
      error: (err, stack) =>
          const Center(child: Text('Something went wrong. Please try again.')),
    );

    return Scaffold(
      body: SafeArea(
        child: bodyWidget,
      ),
    );
  }
}
