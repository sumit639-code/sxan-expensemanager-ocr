import 'package:expense_app/features/dashboard/presentation/widgets/quick_actions.dart';
import 'package:expense_app/features/transactions/domain/entities/transaction_entity.dart';
import 'package:expense_app/features/transactions/domain/entities/transaction_filter.dart';
import 'package:expense_app/features/transactions/presentation/pages/add_edit_transaction_page.dart';
import 'package:expense_app/features/transactions/presentation/pages/transaction_history_page.dart';
import 'package:expense_app/features/transactions/presentation/providers/transaction_providers.dart';
import 'package:expense_app/shared/enums/transaction_enums.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final testTheme = ThemeData(splashFactory: InkRipple.splashFactory);

  testWidgets(
    'AddEditTransactionPage renders amount, title, and submit button',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: testTheme,
            home: const AddEditTransactionPage(),
          ),
        ),
      );

      expect(find.text('Add Transaction'), findsOneWidget);
      expect(find.text('Expense'), findsOneWidget);
      expect(find.text('Income'), findsOneWidget);
      expect(find.text('Amount'), findsOneWidget);
      expect(find.text('Add Expense'), findsOneWidget);
    },
  );

  testWidgets(
    'AddEditTransactionPage validates empty amount and title',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: testTheme,
            home: const AddEditTransactionPage(),
          ),
        ),
      );

      // Scroll to and tap submit with empty form
      await tester.ensureVisible(find.text('Add Expense'));
      await tester.tap(find.text('Add Expense'));
      await tester.pumpAndSettle();

      expect(find.text('Enter an amount'), findsOneWidget);
      expect(find.text('Enter a title'), findsOneWidget);
    },
  );

  testWidgets(
    'AddEditTransactionPage validates zero amount',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: testTheme,
            home: const AddEditTransactionPage(),
          ),
        ),
      );

      // Enter '0' as amount
      await tester.enterText(find.byType(TextField).first, '0');
      await tester.ensureVisible(find.text('Add Expense'));
      await tester.tap(find.text('Add Expense'));
      await tester.pumpAndSettle();

      expect(find.text('Amount must be greater than ₹0'), findsOneWidget);
    },
  );

  testWidgets('TransactionHistoryPage renders search bar and filter chips', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: testTheme,
          home: const TransactionHistoryPage(),
        ),
      ),
    );

    expect(find.text('Transactions'), findsOneWidget);
    expect(find.text('Search transactions or merchants...'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Expenses'), findsOneWidget);
    expect(find.text('Income'), findsOneWidget);
  });

  testWidgets(
    'TransactionHistoryPage displays filter empty state with Clear Filters button',
    (tester) async {
      final sampleTx = Transaction(
        id: 'tx-1',
        type: TransactionType.expense,
        amount: 50000,
        title: 'Dinner',
        date: DateTime.now(),
        source: TransactionSource.manual,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            watchAllTransactionsProvider.overrideWith(
              (ref) => Stream.value([sampleTx]),
            ),
            filteredTransactionsProvider.overrideWith(
              (ref) => const AsyncValue.data(<Transaction>[]),
            ),
            transactionFilterProvider.overrideWith(
              (ref) => const TransactionFilter(searchQuery: 'NonExistentItem'),
            ),
          ],
          child: MaterialApp(
            theme: testTheme,
            home: const TransactionHistoryPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No transactions found'), findsOneWidget);
      expect(find.text('Clear Filters'), findsWidgets);
    },
  );

  testWidgets(
    'QuickActions renders buttons for Add, Scan, Analytics, and More',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: testTheme,
          home: const Scaffold(body: QuickActions()),
        ),
      );

      expect(find.text('Add'), findsOneWidget);
      expect(find.text('Scan'), findsOneWidget);
      expect(find.text('Analytics'), findsOneWidget);
      expect(find.text('More'), findsOneWidget);
    },
  );
}
