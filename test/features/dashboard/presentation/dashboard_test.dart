import 'package:expense_app/app/app.dart';
import 'package:expense_app/core/storage/app_preferences.dart';
import 'package:expense_app/core/storage/preferences_provider.dart';
import 'package:expense_app/features/analysis/domain/entities/analysis_data.dart';
import 'package:expense_app/features/analysis/domain/entities/analysis_period.dart';
import 'package:expense_app/features/dashboard/domain/models/dashboard_summary.dart';
import 'package:expense_app/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:expense_app/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:expense_app/features/transactions/domain/entities/transaction_entity.dart';
import 'package:expense_app/shared/enums/transaction_enums.dart';
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

DashboardSummary createTestSummary({
  bool isDatabaseEmpty = false,
  bool isPeriodEmpty = false,
  int netCashFlow = 1750000,
  int incomeTotal = 5000000,
  int expenseTotal = 3250000,
  List<Transaction> recentTransactions = const [],
}) {
  final period = AnalysisPeriod.fromType(AnalysisPeriodType.thisMonth);
  return DashboardSummary(
    period: period,
    netCashFlow: netCashFlow,
    incomeTotal: incomeTotal,
    expenseTotal: expenseTotal,
    comparison: const PeriodComparison(
      prevTotalIncomeMinor: 4000000,
      prevTotalExpenseMinor: 3000000,
      expensePercentageChange: 8.3,
      expenseComparisonText: '8.3% higher than last month',
      isExpenseHigher: true,
      isRoughlyUnchanged: false,
      hasPreviousData: true,
    ),
    trendBuckets: [
      TrendBucket(
        label: '1 Sep',
        date: DateTime(2026, 9, 1),
        expenseMinor: 100000,
        incomeMinor: 5000000,
      ),
    ],
    categoryBreakdown: const [
      CategoryBreakdownItem(
        categoryId: 'food',
        categoryName: 'Food & Dining',
        totalMinor: 1200000,
        percentage: 36.9,
        count: 5,
      ),
    ],
    recentTransactions: recentTransactions,
    largestExpense: recentTransactions.isNotEmpty ? recentTransactions.first : null,
    averageDailySpending: 125000,
    insights: const [
      DeterministicInsight(
        id: 'top_category',
        title: 'Top Category',
        message: 'Food & Dining is your largest expense category (37% of total spending).',
        type: InsightType.neutral,
      ),
    ],
    isDatabaseEmpty: isDatabaseEmpty,
    isPeriodEmpty: isPeriodEmpty,
  );
}

void main() {
  testWidgets(
    'DashboardPage renders onboarding empty state when database is empty',
    (tester) async {
      final period = AnalysisPeriod.fromType(AnalysisPeriodType.thisMonth);
      final emptySummary = DashboardSummary.empty(period, isDatabaseEmpty: true);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dashboardDataProvider.overrideWithValue(
              AsyncValue.data(emptySummary),
            ),
          ],
          child: const MaterialApp(home: DashboardPage()),
        ),
      );

      await tester.pump(const Duration(milliseconds: 600));

      // Header
      expect(find.textContaining('Alex'), findsOneWidget);

      // Onboarding Empty State
      expect(find.text('No transactions yet'), findsOneWidget);
      expect(
        find.text(
          'Start tracking your spending by adding your first expense or importing a payment screenshot.',
        ),
        findsOneWidget,
      );
      expect(find.text('Add Expense'), findsOneWidget);
      expect(find.text('Import Screenshot'), findsOneWidget);

      // Should NOT display balance card or 0.00 charts
      expect(find.text('Net Balance'), findsNothing);
    },
  );

  testWidgets(
    'DashboardPage renders populated dashboard with Balance, Quick Actions, Categories, and Trends',
    (tester) async {
      final sampleTx = Transaction(
        id: 'tx1',
        title: 'Swiggy',
        amount: 45000,
        type: TransactionType.expense,
        categoryId: 'food',
        source: TransactionSource.manual,
        date: DateTime(2026, 9, 5),
        createdAt: DateTime(2026, 9, 5),
        updatedAt: DateTime(2026, 9, 5),
        merchant: 'Swiggy',
      );

      final summary = createTestSummary(recentTransactions: [sampleTx]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dashboardDataProvider.overrideWithValue(
              AsyncValue.data(summary),
            ),
          ],
          child: const MaterialApp(home: DashboardPage()),
        ),
      );

      await tester.pump(const Duration(milliseconds: 600));

      // Net Balance Card
      expect(find.text('Net Balance'), findsOneWidget);
      expect(find.textContaining('17,500'), findsOneWidget);

      // Quick Actions
      expect(find.text('Expense'), findsOneWidget);
      expect(find.text('Income'), findsWidgets);
      expect(find.text('Import'), findsOneWidget);
      expect(find.text('Insights'), findsWidgets);

      // Category Section
      expect(find.text('Categories'), findsOneWidget);
      expect(find.text('Food & Dining'), findsWidgets);

      // Insights Section
      expect(find.text('Top Category'), findsOneWidget);

      // Recent Transactions
      expect(find.text('Recent Transactions'), findsOneWidget);
      expect(find.text('Swiggy'), findsWidgets);
    },
  );

  testWidgets(
    'ExpenseApp renders DashboardPage on /home route with bottom navigation',
    (tester) async {
      final fakePrefs = FakeAppPreferences();
      final summary = createTestSummary();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appPreferencesProvider.overrideWithValue(fakePrefs),
            dashboardDataProvider.overrideWithValue(
              AsyncValue.data(summary),
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
      expect(find.text('History'), findsOneWidget);
    },
  );
}
