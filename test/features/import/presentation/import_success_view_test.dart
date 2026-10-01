import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expense_app/features/import/presentation/views/import_success_view.dart';

void main() {
  group('ImportSuccessView Widget Tests', () {
    testWidgets('renders count, formatted total, and action buttons', (tester) async {
      bool finishCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: Scaffold(
            body: ImportSuccessView(
              count: 8,
              formattedTotal: '₹8,493.00',
              onFinish: () => finishCalled = true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Import complete'), findsOneWidget);
      expect(find.text('8 transactions added to your records'), findsOneWidget);
      expect(find.text('TOTAL IMPORTED'), findsOneWidget);
      expect(find.text('₹8,493.00'), findsOneWidget);
      expect(find.text('View transactions'), findsOneWidget);
      expect(find.text('Back to dashboard'), findsOneWidget);

      await tester.tap(find.text('View transactions'));
      expect(finishCalled, isTrue);
    });

    testWidgets('renders cleanly in dark mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            body: ImportSuccessView(
              count: 1,
              formattedTotal: '₹20.00',
              onFinish: _dummyFinish,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Import complete'), findsOneWidget);
      expect(find.text('1 transaction added to your records'), findsOneWidget);
      expect(find.text('₹20.00'), findsOneWidget);
    });
  });
}

void _dummyFinish() {}
