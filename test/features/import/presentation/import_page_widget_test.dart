import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expense_app/features/import/data/services/mock_transaction_extractor.dart';
import 'package:expense_app/features/import/domain/entities/extracted_transaction.dart';
import 'package:expense_app/features/import/presentation/pages/import_page.dart';
import 'package:expense_app/features/import/presentation/providers/import_providers.dart';
import 'package:expense_app/features/import/presentation/views/preview_screenshots_view.dart';
import 'package:expense_app/features/import/presentation/views/review_transactions_view.dart';
import 'package:expense_app/features/import/presentation/views/select_screenshots_view.dart';
import 'package:expense_app/features/transactions/presentation/providers/transaction_providers.dart';

import '../domain/duplicate_detector_test.dart';

void main() {
  group('Import Widgets', () {
    testWidgets(
      'SelectScreenshotsView renders Scan History hero and action button',
      (tester) async {
        bool buttonTapped = false;

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: ThemeData(splashFactory: InkRipple.splashFactory),
              home: Scaffold(
                body: SelectScreenshotsView(
                  onSelectScreenshots: () => buttonTapped = true,
                ),
              ),
            ),
          ),
        );

        expect(find.text('Scan History'), findsOneWidget);
        expect(find.text('Select Screenshots'), findsOneWidget);
        expect(find.text('Multiple Screenshots'), findsOneWidget);

        await tester.ensureVisible(find.text('Select Screenshots'));
        await tester.tap(find.text('Select Screenshots'));
        expect(buttonTapped, isTrue);
      },
    );

    testWidgets(
      'PreviewScreenshotsView renders grid, count chip, and continue button',
      (tester) async {
        bool continued = false;
        String? removedPath;

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(splashFactory: InkRipple.splashFactory),
            home: Scaffold(
              body: PreviewScreenshotsView(
                imagePaths: const ['receipt1.png', 'receipt2.jpg'],
                onRemoveImage: (p) => removedPath = p,
                onAddMore: () {},
                onContinue: () => continued = true,
              ),
            ),
          ),
        );

        expect(find.text('Selected Screenshots'), findsOneWidget);
        expect(find.text('2 total'), findsOneWidget);
        expect(find.text('2 screenshots selected'), findsOneWidget);
        expect(find.text('Continue'), findsOneWidget);
        expect(find.text('Add More'), findsOneWidget);

        // Tap remove on first card
        await tester.tap(find.byIcon(Icons.close_rounded).first);
        expect(removedPath, 'receipt1.png');

        await tester.tap(find.text('Continue'));
        expect(continued, isTrue);
      },
    );

    testWidgets(
      'ReviewTransactionsView renders transactions, select all, and Add button',
      (tester) async {
        final transactions = [
          ExtractedTransaction(
            id: '1',
            merchant: 'Swiggy',
            title: 'Food Delivery',
            amount: 42000,
            date: DateTime(2026, 9, 8),
            categoryId: 'food',
          ),
          ExtractedTransaction(
            id: '2',
            merchant: 'Uber',
            title: 'Uber Ride',
            amount: 28000,
            date: DateTime(2026, 9, 8),
            categoryId: 'transport',
          ),
        ];

        bool confirmed = false;

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(splashFactory: InkRipple.splashFactory),
            home: Scaffold(
              body: ReviewTransactionsView(
                transactions: transactions,
                selectedIds: const {'1'},
                failedImages: const [],
                errors: const [],
                onToggleTransaction: (_) {},
                onToggleSelectAll: () {},
                onUpdateTransaction: (_) {},
                onDeleteTransaction: (_) {},
                onKeepDuplicate: (_) {},
                onSkipDuplicate: (_) {},
                onConfirmImport: () => confirmed = true,
                onRetry: () {},
                onChooseDifferentScreenshots: () {},
              ),
            ),
          ),
        );

        expect(find.text('Review transactions'), findsOneWidget);
        expect(find.text('2 transactions · 1 selected'), findsOneWidget);
        expect(find.text('Swiggy'), findsOneWidget);
        expect(find.text('Uber'), findsOneWidget);
        expect(find.text('Import 1 transaction'), findsOneWidget);

        await tester.tap(find.text('Import 1 transaction'));
        expect(confirmed, isTrue);
      },
    );

    testWidgets('ImportPage integration flow in ProviderScope', (tester) async {
      final fakeRepo = FakeTransactionRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            transactionRepositoryProvider.overrideWithValue(fakeRepo),
            transactionExtractorProvider.overrideWithValue(
              MockTransactionExtractor(stepDelay: Duration.zero),
            ),
          ],
          child: MaterialApp(
            theme: ThemeData(splashFactory: InkRipple.splashFactory),
            home: const ImportPage(),
          ),
        ),
      );

      // Starts at initial selection view (AppBar title + Hero title)
      expect(find.text('Scan History'), findsNWidgets(2));
      expect(find.text('Select Screenshots'), findsOneWidget);
    });
  });
}
