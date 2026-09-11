import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expense_app/features/import/domain/entities/extracted_transaction.dart';
import 'package:expense_app/features/import/presentation/views/review_transactions_view.dart';
import 'package:expense_app/shared/enums/transaction_enums.dart';

void main() {
  group('ReviewTransactionsView Widget Tests', () {
    final t1 = ExtractedTransaction(
      id: 'tx-1',
      merchant: 'Hemant Store',
      title: 'Hemant Store',
      amount: 2000, // ₹20.00
      date: DateTime(2026, 9, 4),
      type: TransactionType.expense,
      confidence: 0.95,
    );

    final t2 = ExtractedTransaction(
      id: 'tx-2',
      merchant: 'THE PRABHAT MISTANNA BHANDAR',
      title: 'THE PRABHAT MISTANNA BHANDAR',
      amount: 20500, // ₹205.00
      date: DateTime(2026, 9, 3),
      type: TransactionType.expense,
      confidence: 0.90,
    );

    final t3 = ExtractedTransaction(
      id: 'tx-3',
      merchant: 'SBI ATM CASH WITHDRAWAL',
      title: 'ATM Cash',
      amount: 500000, // ₹5,000.00
      date: DateTime(2026, 9, 2),
      type: TransactionType.expense,
      confidence: 0.50, // Needs review
    );

    final sampleTransactions = [t1, t2, t3];

    testWidgets('renders header, transactions, and selected total accurately', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: Scaffold(
            body: ReviewTransactionsView(
              transactions: sampleTransactions,
              selectedIds: const {'tx-1', 'tx-2', 'tx-3'},
              failedImages: const [],
              errors: const [],
              onToggleTransaction: (_) {},
              onToggleSelectAll: () {},
              onUpdateTransaction: (_) {},
              onDeleteTransaction: (_) {},
              onKeepDuplicate: (_) {},
              onSkipDuplicate: (_) {},
              onConfirmImport: () {},
              onRetry: () {},
              onChooseDifferentScreenshots: () {},
            ),
          ),
        ),
      );

      expect(find.text('Review transactions'), findsOneWidget);
      expect(find.text('3 transactions · 3 selected'), findsOneWidget);
      expect(find.text('Deselect all'), findsOneWidget);

      // Selected total should be 20.00 + 205.00 + 5000.00 = ₹5,225.00
      expect(find.text('Selected total'), findsOneWidget);
      expect(find.text('₹5,225.00'), findsWidgets);

      // Primary import action
      expect(find.text('Import 3 transactions'), findsOneWidget);

      // Contextual warning for t3 (ConfidenceLevel.low)
      expect(find.text('1 transaction needs review'), findsOneWidget);
    });

    testWidgets('disables import button when zero transactions are selected', (tester) async {
      bool confirmTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: Scaffold(
            body: ReviewTransactionsView(
              transactions: sampleTransactions,
              selectedIds: const {}, // Nothing selected
              failedImages: const [],
              errors: const [],
              onToggleTransaction: (_) {},
              onToggleSelectAll: () {},
              onUpdateTransaction: (_) {},
              onDeleteTransaction: (_) {},
              onKeepDuplicate: (_) {},
              onSkipDuplicate: (_) {},
              onConfirmImport: () => confirmTapped = true,
              onRetry: () {},
              onChooseDifferentScreenshots: () {},
            ),
          ),
        ),
      );

      expect(find.text('3 transactions · 0 selected'), findsOneWidget);
      expect(find.text('Select all'), findsOneWidget);
      expect(find.text('₹0.00'), findsWidgets);
      expect(find.text('Import 0 transactions'), findsOneWidget);

      // Try tapping disabled button
      await tester.tap(find.text('Import 0 transactions'));
      expect(confirmTapped, isFalse);
    });

    testWidgets('swipe-to-delete invokes onDeleteTransaction callback', (tester) async {
      String? deletedId;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: Scaffold(
            body: ReviewTransactionsView(
              transactions: sampleTransactions,
              selectedIds: const {'tx-1', 'tx-2'},
              failedImages: const [],
              errors: const [],
              onToggleTransaction: (_) {},
              onToggleSelectAll: () {},
              onUpdateTransaction: (_) {},
              onDeleteTransaction: (id) => deletedId = id,
              onKeepDuplicate: (_) {},
              onSkipDuplicate: (_) {},
              onConfirmImport: () {},
              onRetry: () {},
              onChooseDifferentScreenshots: () {},
            ),
          ),
        ),
      );

      expect(find.text('Hemant Store'), findsOneWidget);

      // Swipe the first transaction item right-to-left
      await tester.drag(find.text('Hemant Store'), const Offset(-500, 0));
      await tester.pumpAndSettle();

      expect(deletedId, 'tx-1');
    });

    testWidgets('displays duplicate warning and action buttons for duplicate items', (tester) async {
      final duplicateTx = ExtractedTransaction(
        id: 'tx-dup',
        merchant: 'Swiggy',
        title: 'Swiggy',
        amount: 25000,
        date: DateTime(2026, 9, 4),
        isDuplicate: true,
      );

      bool kept = false;
      bool skipped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: Scaffold(
            body: ReviewTransactionsView(
              transactions: [duplicateTx],
              selectedIds: const {},
              failedImages: const [],
              errors: const [],
              onToggleTransaction: (_) {},
              onToggleSelectAll: () {},
              onUpdateTransaction: (_) {},
              onDeleteTransaction: (_) {},
              onKeepDuplicate: (_) => kept = true,
              onSkipDuplicate: (_) => skipped = true,
              onConfirmImport: () {},
              onRetry: () {},
              onChooseDifferentScreenshots: () {},
            ),
          ),
        ),
      );

      expect(find.text('Possible duplicate'), findsOneWidget);
      expect(find.text('Import anyway'), findsOneWidget);

      await tester.tap(find.text('Import anyway'));
      expect(kept, isTrue);

      // Now pump when the transaction is selected to verify the Skip action
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: Scaffold(
            body: ReviewTransactionsView(
              transactions: [duplicateTx],
              selectedIds: const {'tx-dup'},
              failedImages: const [],
              errors: const [],
              onToggleTransaction: (_) {},
              onToggleSelectAll: () {},
              onUpdateTransaction: (_) {},
              onDeleteTransaction: (_) {},
              onKeepDuplicate: (_) {},
              onSkipDuplicate: (_) => skipped = true,
              onConfirmImport: () {},
              onRetry: () {},
              onChooseDifferentScreenshots: () {},
            ),
          ),
        ),
      );

      expect(find.text('Skip'), findsOneWidget);
      await tester.tap(find.text('Skip'));
      expect(skipped, isTrue);
    });

    testWidgets('renders cleanly in dark mode without overflowing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: ReviewTransactionsView(
              transactions: sampleTransactions,
              selectedIds: const {'tx-1', 'tx-2'},
              failedImages: const ['corrupt_image.png'],
              errors: const [],
              onToggleTransaction: (_) {},
              onToggleSelectAll: () {},
              onUpdateTransaction: (_) {},
              onDeleteTransaction: (_) {},
              onKeepDuplicate: (_) {},
              onSkipDuplicate: (_) {},
              onConfirmImport: () {},
              onRetry: () {},
              onChooseDifferentScreenshots: () {},
            ),
          ),
        ),
      );

      // Verify partial failure banner
      expect(find.text('1 screenshot could not be processed.'), findsOneWidget);
      expect(find.text('Selected total'), findsOneWidget);
      // Selected: tx-1 (20) + tx-2 (205) = ₹225.00
      expect(find.text('₹225.00'), findsWidgets);
    });
  });
}
