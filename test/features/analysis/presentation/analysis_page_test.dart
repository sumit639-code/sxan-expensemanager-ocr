import 'package:expense_app/features/analysis/presentation/pages/analysis_page.dart';
import 'package:expense_app/features/transactions/domain/entities/transaction_entity.dart';
import 'package:expense_app/features/transactions/presentation/providers/transaction_providers.dart';
import 'package:expense_app/shared/enums/transaction_enums.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final testTheme = ThemeData(splashFactory: InkRipple.splashFactory);

  testWidgets('AnalysisPage renders empty state when no transactions exist', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          watchAllTransactionsProvider.overrideWith(
            (ref) => Stream.value([]),
          ),
        ],
        child: MaterialApp(
          theme: testTheme,
          home: const AnalysisPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Analysis'), findsOneWidget);
    expect(find.text('Not enough data yet'), findsOneWidget);
    expect(find.text('Add Transaction'), findsOneWidget);
  });

  testWidgets(
    'AnalysisPage renders financial metrics when transactions are present',
    (tester) async {
      final now = DateTime.now();
      final sampleTx = Transaction(
        id: 'tx-1',
        type: TransactionType.expense,
        amount: 25000,
        title: 'Groceries',
        categoryId: 'groceries',
        date: now,
        source: TransactionSource.manual,
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            watchAllTransactionsProvider.overrideWith(
              (ref) => Stream.value([sampleTx]),
            ),
          ],
          child: MaterialApp(
            theme: testTheme,
            home: const AnalysisPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Analysis'), findsOneWidget);
      expect(find.text('NET CASH FLOW'), findsOneWidget);
      expect(find.text('AVG EXPENSE'), findsOneWidget);
      expect(find.text('Spending Trend'), findsOneWidget);
      expect(find.text('Expense Breakdown'), findsOneWidget);
    },
  );
}
