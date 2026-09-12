import 'package:expense_app/app/app.dart';
import 'package:expense_app/core/storage/app_preferences.dart';
import 'package:expense_app/core/storage/preferences_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAppPreferences implements AppPreferences {
  bool _completed = false;
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
    'ExpenseApp renders Splash screen initially and navigates to Onboarding',
    (tester) async {
      final fakePrefs = FakeAppPreferences();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [appPreferencesProvider.overrideWithValue(fakePrefs)],
          child: const ExpenseApp(),
        ),
      );

      // Initial Splash Screen rendering
      expect(find.text('SXAN'), findsOneWidget);
      expect(find.text('Simple. Smart. Yours.'), findsOneWidget);

      // Pump past splash delay (1.6s) to transition to Onboarding
      await tester.pump(const Duration(milliseconds: 1700));
      await tester.pumpAndSettle();

      expect(find.textContaining('Track Your Money'), findsOneWidget);
    },
  );
}
