import 'package:expense_app/core/storage/shared_prefs_app_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SharedPrefsAppPreferences tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('defaults hasCompletedOnboarding to false', () async {
      final prefs = SharedPrefsAppPreferences();
      final completed = await prefs.hasCompletedOnboarding();
      expect(completed, isFalse);
    });

    test('sets hasCompletedOnboarding to true', () async {
      final prefs = SharedPrefsAppPreferences();
      await prefs.setOnboardingCompleted(true);
      final completed = await prefs.hasCompletedOnboarding();
      expect(completed, isTrue);
    });
  });
}
