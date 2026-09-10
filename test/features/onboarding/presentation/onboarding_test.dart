import 'package:expense_app/app/app.dart';
import 'package:expense_app/core/storage/app_preferences.dart';
import 'package:expense_app/core/storage/preferences_provider.dart';
import 'package:expense_app/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

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

Widget createOnboardingTestApp(AppPreferences prefs) {
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
    overrides: [appPreferencesProvider.overrideWithValue(prefs)],
    child: MaterialApp.router(
      theme: ThemeData(splashFactory: InkRipple.splashFactory),
      routerConfig: testRouter,
    ),
  );
}

void main() {
  testWidgets('SplashPage renders branding title and subtitle', (tester) async {
    final fakePrefs = FakeAppPreferences();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appPreferencesProvider.overrideWithValue(fakePrefs)],
        child: const ExpenseApp(),
      ),
    );

    expect(find.text('Expense'), findsOneWidget);
    expect(find.text('Simple. Smart. Yours.'), findsOneWidget);

    // Pump past splash timer
    await tester.pump(const Duration(milliseconds: 1700));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'OnboardingPage renders slide 1 and advances to slide 2 on Next tap',
    (tester) async {
      final fakePrefs = FakeAppPreferences();

      await tester.pumpWidget(createOnboardingTestApp(fakePrefs));

      expect(find.textContaining('Track Your Money'), findsOneWidget);
      expect(find.text('Next →'), findsOneWidget);

      await tester.tap(find.text('Next →'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Add Expenses'), findsOneWidget);
    },
  );

  testWidgets(
    'OnboardingPage navigates to Name Setup and completes with entered name',
    (tester) async {
      final fakePrefs = FakeAppPreferences();

      await tester.pumpWidget(createOnboardingTestApp(fakePrefs));

      // Slide 1 -> Slide 2
      await tester.tap(find.text('Next →'));
      await tester.pumpAndSettle();

      // Slide 2 -> Slide 3
      await tester.tap(find.text('Next →'));
      await tester.pumpAndSettle();

      // Slide 3 -> Slide 4 (Name Setup)
      await tester.tap(find.text('Next →'));
      await tester.pumpAndSettle();

      expect(find.text("What's your name?"), findsOneWidget);
      expect(
        find.text("We'll use your name to personalize your experience."),
        findsOneWidget,
      );
      expect(find.text('Get Started →'), findsOneWidget);

      // Enter name
      await tester.enterText(find.byType(TextField), '  Jordan  ');
      await tester.pump();

      await tester.tap(find.text('Get Started →'));
      await tester.pumpAndSettle();

      expect(await fakePrefs.hasCompletedOnboarding(), isTrue);
      expect(await fakePrefs.getUserName(), 'Jordan');
      expect(find.text('Home Screen'), findsOneWidget);
    },
  );

  testWidgets(
    'OnboardingPage completes and updates preference when Skip is tapped',
    (tester) async {
      final fakePrefs = FakeAppPreferences();

      await tester.pumpWidget(createOnboardingTestApp(fakePrefs));

      expect(find.text('Skip'), findsOneWidget);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(await fakePrefs.hasCompletedOnboarding(), isTrue);
      expect(find.text('Home Screen'), findsOneWidget);
    },
  );
}
