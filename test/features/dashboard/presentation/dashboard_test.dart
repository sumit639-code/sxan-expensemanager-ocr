import 'package:expense_app/app/app.dart';
import 'package:expense_app/core/storage/app_preferences.dart';
import 'package:expense_app/core/storage/preferences_provider.dart';
import 'package:expense_app/features/dashboard/domain/models/dashboard_summary.dart';
import 'package:expense_app/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:expense_app/features/transactions/presentation/providers/transaction_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAppPreferences implements AppPreferences {
  bool _completed = true;
  String _userName = 'Alex';

  @override
  Future<bool> hasCompletedOnboarding() async => _completed;

  @override
  Future<void> setOnboardingCompleted(bool completed) async {
    _completed = completed;
  }

  @override
  Future<String?> getUserName() async => _userName;

  @override
  Future<void> setUserName(String name) async {
    _userName = name;
  }
}

void main() {
  testWidgets(
    'DashboardPage renders header, balance, summary, quick actions, and transactions',
    (tester) async {
      const mockSummary = DashboardSummary(
        totalBalance: 4826000,
        incomeTotal: 7250000,
        expenseTotal: 2424000,
        monthlyChangePercentage: 12.0,
        recentTransactions: [],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dashboardRealtimeSummaryProvider.overrideWithValue(
              const AsyncValue.data(mockSummary),
            ),
          ],
          child: const MaterialApp(home: DashboardPage()),
        ),
      );

      await tester.pump(const Duration(milliseconds: 600));

      // Header Greeting
      expect(find.textContaining('Alex 👋'), findsOneWidget);
      expect(find.text('Small steps. Bigger freedom.'), findsOneWidget);

      // Balance Card
      expect(find.text('Total Balance'), findsOneWidget);

      // Income / Expense Summary
      expect(find.text('Income'), findsOneWidget);
      expect(find.text('Expenses'), findsOneWidget);

      // Quick Actions
      expect(find.text('Add'), findsOneWidget);
      expect(find.text('Scan'), findsOneWidget);
      expect(find.text('Analytics'), findsWidgets);
      expect(find.text('More'), findsOneWidget);

      // Empty State Card
      expect(find.text('Recent Transactions'), findsOneWidget);
      expect(find.text('No transactions yet'), findsOneWidget);
      expect(
        find.text('Add your first transaction to start tracking your spending.'),
        findsOneWidget,
      );
      expect(find.text('Add Transaction'), findsOneWidget);
    },
  );

  testWidgets(
    'ExpenseApp renders DashboardPage on /home route with bottom navigation',
    (tester) async {
      final fakePrefs = FakeAppPreferences();
      const mockSummary = DashboardSummary(
        totalBalance: 4826000,
        incomeTotal: 7250000,
        expenseTotal: 2424000,
        monthlyChangePercentage: 12.0,
        recentTransactions: [],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appPreferencesProvider.overrideWithValue(fakePrefs),
            dashboardRealtimeSummaryProvider.overrideWithValue(
              const AsyncValue.data(mockSummary),
            ),
          ],
          child: const ExpenseApp(),
        ),
      );

      // Pump past splash screen and route transition cleanly
      await tester.pump(const Duration(milliseconds: 1700));
      await tester.pumpAndSettle();

      // Verify Home shell navigation bar tabs are rendered
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Transactions'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    },
  );
}
