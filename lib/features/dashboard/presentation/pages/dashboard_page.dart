import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../../transactions/presentation/providers/transaction_providers.dart';

import '../widgets/balance_card.dart';
import '../widgets/dashboard_header.dart';
import '../widgets/income_expense_summary.dart';
import '../widgets/quick_actions.dart';
import '../widgets/recent_transactions.dart';

/// Main Dashboard Page presenting real-time user balance, summary metrics, quick actions, and recent activity from SQLite.
class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userName = ref.watch(userNameProvider);
    final asyncSummary = ref.watch(dashboardRealtimeSummaryProvider);
    final dashPrefs = ref.watch(dashboardPreferencesProvider);
    final disableAnimations = MediaQuery.of(context).disableAnimations;

    final bodyWidget = asyncSummary.when(
      data: (summary) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(
            left: 20, right: 20, top: 16,
            bottom: AppSpacing.navPillClearance,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DashboardHeader(
                userName: userName,
                onAvatarPressed: () => context.push('/settings'),
              ),
              if (dashPrefs.showBalance) ...[
                const SizedBox(height: 20),
                BalanceCard(
                  totalBalanceMinorUnits: summary.totalBalance,
                  monthlyChangePercentage: summary.monthlyChangePercentage,
                ),
              ],
              if (dashPrefs.showSpendingSummary) ...[
                const SizedBox(height: 16),
                IncomeExpenseSummary(
                  incomeMinorUnits: summary.incomeTotal,
                  expenseMinorUnits: summary.expenseTotal,
                ),
              ],
              if (dashPrefs.showQuickActions) ...[
                const SizedBox(height: 24),
                const QuickActions(),
              ],
              if (dashPrefs.showRecentTransactions) ...[
                const SizedBox(height: 24),
                RecentTransactions(
                  transactions: summary.recentTransactions,
                  onAddFirstPressed: () => context.push('/add'),
                ),
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
        child: disableAnimations
            ? bodyWidget
            : FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: bodyWidget,
                ),
              ),
      ),
    );
  }
}
