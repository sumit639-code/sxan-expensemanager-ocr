import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:expense_app/features/analysis/domain/entities/analysis_period.dart';
import 'package:expense_app/features/analysis/presentation/providers/analysis_providers.dart';
import 'package:expense_app/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:expense_app/features/settings/data/services/settings_service.dart';
import 'package:expense_app/features/settings/domain/entities/app_settings.dart';
import 'package:expense_app/features/settings/presentation/pages/data_management_page.dart';
import 'package:expense_app/features/settings/presentation/pages/settings_page.dart';
import 'package:expense_app/features/settings/presentation/pages/ui_customization_page.dart';
import 'package:expense_app/features/settings/presentation/providers/settings_providers.dart';
import 'package:expense_app/features/transactions/presentation/providers/transaction_providers.dart';
import 'package:expense_app/shared/widgets/app_bottom_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Widget buildTestableWidget(Widget child) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        watchAllTransactionsProvider.overrideWith((ref) => Stream.value([])),
      ],
      child: MaterialApp(
        home: child,
      ),
    );
  }

  group('UICustomizationPage Widget Tests', () {
    testWidgets('renders live preview card and all 8 accent color presets', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestableWidget(const UICustomizationPage()));
      await tester.pumpAndSettle();

      expect(find.text('LIVE PREVIEW'), findsOneWidget);
      expect(find.text('Monthly Spending'), findsOneWidget);
      expect(find.text('₹12,450.00'), findsOneWidget);
      expect(find.text('Add Expense'), findsOneWidget);
      expect(find.text('APPEARANCE'), findsOneWidget);
      expect(find.text('ACCENT COLOR PRESETS'), findsOneWidget);
      expect(find.text('TYPOGRAPHY & FONTS'), findsOneWidget);

      // Verify all 8 accent preset names are displayed
      for (final accent in AppAccentColor.values) {
        expect(find.text(accent.label.split(' ').last), findsOneWidget);
      }

      // Verify all 8 font presets are displayed
      for (final font in AppFontPreset.values) {
        expect(find.text(font.label), findsOneWidget);
      }

      // Tap on Teal accent
      final tealButton = find.text('Teal');
      expect(tealButton, findsOneWidget);
      await tester.tap(tealButton);
      await tester.pumpAndSettle();

      // Tap on Bold Impact font
      final boldFontButton = find.text('Bold Impact');
      expect(boldFontButton, findsOneWidget);
      await tester.tap(boldFontButton);
      await tester.pumpAndSettle();

      // Verify check icon is visible
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });
  });

  group('DataManagementPage Widget Tests', () {
    testWidgets('renders storage metrics, export options, and clear data dialog', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestableWidget(const DataManagementPage()));
      await tester.pumpAndSettle();

      expect(find.text('Data Management'), findsOneWidget);
      expect(find.text('100% Offline & Private'), findsOneWidget);
      expect(find.text('YOUR DATA'), findsOneWidget);
      expect(find.text('Database Engine'), findsOneWidget);
      expect(find.text('Export as JSON'), findsOneWidget);
      expect(find.text('Export as CSV'), findsOneWidget);
      expect(find.text('Clear All Data'), findsOneWidget);
    });
  });

  group('AppBottomSheet Layout Tests', () {
    testWidgets('AppBottomSheet renders content with safe bottom clearances', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppBottomSheet(
              title: Text('Filter Sheet'),
              bottomAction: ElevatedButton(
                onPressed: null,
                child: Text('Apply'),
              ),
              child: Text('Filter Options'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Filter Sheet'), findsOneWidget);
      expect(find.text('Filter Options'), findsOneWidget);
      expect(find.text('Apply'), findsOneWidget);
    });
  });

  group('SettingsPage Widget Tests', () {
    testWidgets('renders developer attribution with Sumit Kumar Dandia', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestableWidget(const SettingsPage()));
      await tester.pumpAndSettle();

      expect(find.text('Sumit Kumar Dandia'), findsOneWidget);
      expect(find.text('Developer'), findsOneWidget);
      expect(find.text('Creator'), findsOneWidget);
    });
  });

  group('Settings Persistence Tests', () {
    test('User name and UI customizations persist across app restarts', () async {
      SharedPreferences.setMockInitialValues({});
      final initialPrefs = await SharedPreferences.getInstance();

      // Session 1: User changes their name and UI customization
      final container1 = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(initialPrefs),
        ],
      );

      final notifier1 = container1.read(settingsNotifierProvider.notifier);
      await notifier1.updateUserName('Sumit');
      await notifier1.updateAccentColor(AppAccentColor.green);
      await notifier1.updateThemeMode(AppThemeMode.dark);
      await notifier1.updateFontPreset(AppFontPreset.bold);

      expect(container1.read(settingsNotifierProvider).userName, 'Sumit');
      expect(container1.read(settingsNotifierProvider).accentColor, AppAccentColor.green);
      expect(container1.read(settingsNotifierProvider).themeMode, AppThemeMode.dark);
      expect(container1.read(settingsNotifierProvider).fontPreset, AppFontPreset.bold);

      // Verify data is written to SharedPreferences storage
      expect(initialPrefs.getString('user_name'), 'Sumit');
      expect(initialPrefs.getString('app_accent_color'), AppAccentColor.green.value);
      expect(initialPrefs.getString('app_theme_mode'), AppThemeMode.dark.value);
      expect(initialPrefs.getString('app_font_preset'), AppFontPreset.bold.value);

      container1.dispose();

      // Session 2: User closes and reopens the app (new ProviderScope / new container)
      final container2 = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(initialPrefs),
        ],
      );

      final reloadedSettings = container2.read(settingsNotifierProvider);
      expect(reloadedSettings.userName, 'Sumit');
      expect(reloadedSettings.accentColor, AppAccentColor.green);
      expect(reloadedSettings.themeMode, AppThemeMode.dark);
      expect(reloadedSettings.fontPreset, AppFontPreset.bold);

      container2.dispose();
    });

    test('SettingsNotifier saves correctly with SettingsService', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final notifier = SettingsNotifier(SettingsService(prefs));
      await notifier.updateUserName('Rahul');
      await notifier.updateAccentColor(AppAccentColor.blue);

      expect(notifier.state.userName, 'Rahul');
      expect(notifier.state.accentColor, AppAccentColor.blue);

      expect(prefs.getString('user_name'), 'Rahul');
      expect(prefs.getString('app_accent_color'), AppAccentColor.blue.value);
    });

    test('Selected time period is saved permanently across app restarts', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      // Session 1: User selects 'This Year' on Dashboard
      final container1 = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );

      final thisYearPeriod = AnalysisPeriod.fromType(AnalysisPeriodType.thisYear);
      container1.read(dashboardPeriodProvider.notifier).state = thisYearPeriod;

      expect(container1.read(dashboardPeriodProvider).type, AnalysisPeriodType.thisYear);
      expect(container1.read(selectedAnalysisPeriodProvider).type, AnalysisPeriodType.thisYear);
      expect(prefs.getString('selected_period_type'), 'thisYear');

      container1.dispose();

      // Session 2: User closes and reopens app - verify 'This Year' is restored
      final container2 = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );

      final restoredPeriod = container2.read(dashboardPeriodProvider);
      expect(restoredPeriod.type, AnalysisPeriodType.thisYear);
      expect(container2.read(selectedAnalysisPeriodProvider).type, AnalysisPeriodType.thisYear);

      // Change to Last 3 Months and verify persistence
      final last3Months = AnalysisPeriod.fromType(AnalysisPeriodType.last3Months);
      container2.read(dashboardPeriodProvider.notifier).state = last3Months;
      expect(prefs.getString('selected_period_type'), 'last3Months');

      container2.dispose();
    });
  });
}
