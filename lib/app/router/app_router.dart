import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/analysis/presentation/pages/analysis_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/import/presentation/pages/import_page.dart';
import '../../features/import/presentation/pages/pending_imports_page.dart';
import '../../features/onboarding/presentation/pages/onboarding_page.dart';
import '../../features/onboarding/presentation/pages/splash_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/transactions/presentation/pages/add_edit_transaction_page.dart';
import '../../features/transactions/presentation/pages/transaction_details_page.dart';
import '../../features/transactions/presentation/pages/transaction_history_page.dart';
import '../../shared/enums/transaction_enums.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// GoRouter configuration establishing shell navigation & feature routes.
final GoRouter appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      name: 'splash',
      builder: (context, state) => const SplashPage(),
    ),
    GoRoute(
      path: '/onboarding',
      name: 'onboarding',
      builder: (context, state) => const OnboardingPage(),
    ),
    ShellRoute(
      builder: (context, state, child) {
        return AppShellScaffold(location: state.uri.path, child: child);
      },
      routes: [
        GoRoute(
          path: '/home',
          name: 'home',
          builder: (context, state) => const DashboardPage(),
        ),
        GoRoute(
          path: '/dashboard',
          redirect: (context, state) => '/home',
        ),
        GoRoute(
          path: '/insights',
          name: 'insights',
          builder: (context, state) => const AnalysisPage(),
        ),
        GoRoute(
          path: '/transactions',
          name: 'transactions',
          builder: (context, state) => const TransactionHistoryPage(),
          routes: [
            GoRoute(
              path: ':id',
              name: 'transactionDetail',
              builder: (context, state) => TransactionDetailsPage(
                transactionId: state.pathParameters['id']!,
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/settings',
          name: 'settings',
          builder: (context, state) => const SettingsPage(),
        ),
        GoRoute(
          path: '/add',
          name: 'add',
          builder: (context, state) {
            final typeParam = state.uri.queryParameters['type'];
            final initialType = typeParam == 'income'
                ? TransactionType.income
                : typeParam == 'expense'
                ? TransactionType.expense
                : null;
            return AddEditTransactionPage(initialType: initialType);
          },
        ),
        GoRoute(
          path: '/import',
          name: 'import',
          builder: (context, state) => const ImportPage(),
        ),
        GoRoute(
          path: '/imports/pending',
          name: 'pendingImports',
          builder: (context, state) => const PendingImportsPage(),
        ),
      ],
    ),
  ],
);

/// Shell scaffold housing the application's floating pill-style bottom navigation bar.
class AppShellScaffold extends StatelessWidget {
  final String location;
  final Widget child;

  const AppShellScaffold({
    super.key,
    required this.location,
    required this.child,
  });

  int _getSelectedIndex() {
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/insights')) return 1;
    if (location.startsWith('/transactions')) return 3;
    if (location.startsWith('/settings')) return 4;
    return 0;
  }

  void _showAddActionSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: isDark ? AppColors.darkElevated : AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkBorder : AppColors.gray300,
                    borderRadius: AppSpacing.borderRadiusPill,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.errorRed.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_upward_rounded,
                      color: AppColors.errorRed,
                    ),
                  ),
                  title: Text(
                    'Add Expense',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/add?type=expense');
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.successGreen.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_downward_rounded,
                      color: AppColors.successGreen,
                    ),
                  ),
                  title: Text(
                    'Add Income',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/add?type=income');
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.document_scanner_rounded,
                      color: primaryColor,
                    ),
                  ),
                  title: Text(
                    'Scan Screenshot / Receipt',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/import');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final selectedIndex = _getSelectedIndex();
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      body: Stack(
        children: [
          // Main page content — fills entire screen
          Positioned.fill(child: child),

          // Floating navigation pill — optimized for 120fps hardware acceleration
          Positioned(
            left: 16,
            right: 16,
            bottom: bottomPadding + 12,
            child: Container(
              height: 74,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xF5161424)
                    : const Color(0xFAFFFFFF),
                borderRadius: BorderRadius.circular(
                  AppSpacing.radiusExtraLarge,
                ),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.black.withValues(alpha: 0.06),
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: isDark ? 0.35 : 0.08,
                    ),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                    children: [
                      // Home
                      Expanded(
                        child: _FloatingNavItem(
                          icon: Icons.grid_view_rounded,
                          label: 'Home',
                          isSelected: selectedIndex == 0,
                          primaryColor: primaryColor,
                          isDark: isDark,
                          onTap: () => context.go('/home'),
                        ),
                      ),

                      // Analytics
                      Expanded(
                        child: _FloatingNavItem(
                          icon: Icons.pie_chart_outline_rounded,
                          label: 'Analytics',
                          isSelected: selectedIndex == 1,
                          primaryColor: primaryColor,
                          isDark: isDark,
                          onTap: () => context.go('/insights'),
                        ),
                      ),

                      // Center FAB — Add / Scan
                      Expanded(
                        child: Center(
                          child: Semantics(
                            button: true,
                            label: 'Add transaction or scan receipt',
                            child: GestureDetector(
                              onTap: () => _showAddActionSheet(context),
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.brightViolet,
                                      primaryColor,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: primaryColor.withValues(
                                        alpha: 0.35,
                                      ),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.add_rounded,
                                  color: AppColors.white,
                                  size: 26,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Transactions
                      Expanded(
                        child: _FloatingNavItem(
                          icon: Icons.receipt_long_rounded,
                          label: 'History',
                          isSelected: selectedIndex == 3,
                          primaryColor: primaryColor,
                          isDark: isDark,
                          onTap: () => context.go('/transactions'),
                        ),
                      ),

                      // Settings
                      Expanded(
                        child: _FloatingNavItem(
                          icon: Icons.settings_outlined,
                          label: 'Settings',
                          isSelected: selectedIndex == 4,
                          primaryColor: primaryColor,
                          isDark: isDark,
                          onTap: () => context.go('/settings'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
    );
  }
}

/// Individual floating nav bar item with a selected-state indicator pill.
class _FloatingNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final Color primaryColor;
  final bool isDark;
  final VoidCallback onTap;

  const _FloatingNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.primaryColor,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = primaryColor;
    final inactiveColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.gray500;
    final color = isSelected ? activeColor : inactiveColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: primaryColor.withValues(alpha: 0.10),
        highlightColor: primaryColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Subtle selected indicator dot
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              width: isSelected ? 28 : 0,
              height: 3,
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: isSelected ? primaryColor : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: color,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
