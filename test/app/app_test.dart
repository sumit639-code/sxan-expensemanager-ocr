import 'package:expense_app/app/app.dart';
import 'package:expense_app/core/storage/app_preferences.dart';
import 'package:expense_app/core/storage/preferences_provider.dart';
import 'package:expense_app/features/settings/presentation/providers/settings_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'ExpenseApp renders Splash screen initially and navigates to Onboarding',
    (tester) async {
      final fakePrefs = FakeAppPreferences();
      final sharedPrefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appPreferencesProvider.overrideWithValue(fakePrefs),
            sharedPreferencesProvider.overrideWithValue(sharedPrefs),
          ],
          child: const ExpenseApp(),
        ),
      );

      // Initial Splash Screen rendering
      expect(find.text('SXAN'), findsOneWidget);
      expect(find.text('Simple. Smart. Yours.'), findsOneWidget);

      // Pump past splash delay (850ms) to transition to Onboarding
      await tester.pump(const Duration(milliseconds: 1000));
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.textContaining('Smart & Effortless'), findsOneWidget);
    },
  );
}
