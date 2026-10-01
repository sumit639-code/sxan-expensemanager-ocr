import 'package:expense_app/core/storage/app_preferences.dart';
import 'package:expense_app/core/storage/preferences_provider.dart';
import 'package:expense_app/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:expense_app/features/settings/presentation/providers/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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

Widget createOnboardingTestApp(AppPreferences prefs, SharedPreferences sharedPrefs) {
  final testRouter = GoRouter(
    initialLocation: '/onboarding',
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingPage(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const Scaffold(body: Text('Home Screen')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      appPreferencesProvider.overrideWithValue(prefs),
      sharedPreferencesProvider.overrideWithValue(sharedPrefs),
    ],
    child: MaterialApp.router(
      theme: ThemeData(splashFactory: InkRipple.splashFactory),
      routerConfig: testRouter,
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> advancePage(WidgetTester tester) async {
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets(
    'OnboardingPage renders slide 0 and advances through setup on Next tap',
    (tester) async {
      final fakePrefs = FakeAppPreferences();
      final sharedPrefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(createOnboardingTestApp(fakePrefs, sharedPrefs));
      await tester.pump();

      expect(find.textContaining('Smart & Effortless'), findsOneWidget);
      expect(find.text('Next →'), findsOneWidget);

      // Advance to Slide 1 (Receipt OCR)
      await tester.tap(find.text('Next →'));
      await advancePage(tester);
      expect(find.textContaining('Snap or Direct Share'), findsOneWidget);

      // Advance to Slide 2 (Bank SMS)
      await tester.tap(find.text('Next →'));
      await advancePage(tester);
      expect(find.textContaining('Automated Bank &'), findsOneWidget);

      // Advance to Slide 3 (Privacy / Spam Filter)
      await tester.tap(find.text('Next →'));
      await advancePage(tester);
      expect(find.textContaining('100% Private'), findsOneWidget);

      // Advance to Slide 4 (Personalization & Theme)
      await tester.tap(find.text('Next →'));
      await advancePage(tester);
      expect(find.text('Personalize ScanEx'), findsOneWidget);
      expect(find.text('Save & Continue →'), findsOneWidget);

      // Enter custom name
      await tester.enterText(find.byType(TextField).first, 'Jordan');
      await tester.pump();

      // Advance to Slide 5 (Done / Ready)
      await tester.tap(find.text('Save & Continue →'));
      await advancePage(tester);

      expect(find.textContaining("You're All Set, Jordan!"), findsOneWidget);
      expect(find.text('Start Managing Expenses 🚀'), findsOneWidget);

      // Complete
      await tester.tap(find.text('Start Managing Expenses 🚀'));
      await advancePage(tester);

      expect(await fakePrefs.hasCompletedOnboarding(), isTrue);
      expect(find.text('Home Screen'), findsOneWidget);
    },
  );

  testWidgets(
    'OnboardingPage completes and updates preference when Skip is tapped',
    (tester) async {
      final fakePrefs = FakeAppPreferences();
      final sharedPrefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(createOnboardingTestApp(fakePrefs, sharedPrefs));
      await tester.pump();

      expect(find.text('Skip'), findsOneWidget);
      await tester.tap(find.text('Skip'));
      await advancePage(tester);

      expect(await fakePrefs.hasCompletedOnboarding(), isTrue);
      expect(find.text('Home Screen'), findsOneWidget);
    },
  );
}
