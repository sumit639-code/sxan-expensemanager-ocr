import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:expense_app/features/settings/data/services/settings_service.dart';
import 'package:expense_app/features/settings/domain/entities/app_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsService & AppSettings', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('loads default settings when storage is empty', () async {
      final prefs = await SharedPreferences.getInstance();
      final service = SettingsService(prefs);
      final settings = service.loadSettings();

      expect(settings.themeMode, AppThemeMode.system);
      expect(settings.accentColor, AppAccentColor.purple);
      expect(settings.dashboardPreferences.showBalance, isTrue);
      expect(settings.dashboardPreferences.showRecentTransactions, isTrue);
      expect(settings.ocrSettings.reviewBeforeSaving, isTrue);
      expect(settings.ocrSettings.duplicateDetection, isTrue);
    });

    test('persists and restores custom theme and accent color', () async {
      final prefs = await SharedPreferences.getInstance();
      final service = SettingsService(prefs);

      await service.saveThemeMode(AppThemeMode.dark);
      await service.saveAccentColor(AppAccentColor.emerald);

      final settings = service.loadSettings();
      expect(settings.themeMode, AppThemeMode.dark);
      expect(settings.accentColor, AppAccentColor.emerald);
    });

    test('persists and restores dashboard preferences', () async {
      final prefs = await SharedPreferences.getInstance();
      final service = SettingsService(prefs);

      const customDashboard = DashboardPreferences(
        showBalance: false,
        showRecentTransactions: true,
        showSpendingSummary: false,
        showQuickActions: true,
      );

      await service.saveDashboardPreferences(customDashboard);

      final settings = service.loadSettings();
      expect(settings.dashboardPreferences.showBalance, isFalse);
      expect(settings.dashboardPreferences.showSpendingSummary, isFalse);
      expect(settings.dashboardPreferences.showRecentTransactions, isTrue);
    });

    test('persists and restores OCR preferences including engineMode, apiBaseUrl, and apiVersion', () async {
      final prefs = await SharedPreferences.getInstance();
      final service = SettingsService(prefs);

      const customOcr = OcrSettings(
        engineMode: OcrEngineMode.api,
        apiBaseUrl: 'http://192.168.1.50:8000',
        apiVersion: PythonApiVersion.v1,
        reviewBeforeSaving: false,
        duplicateDetection: true,
      );

      await service.saveOcrSettings(customOcr);

      final settings = service.loadSettings();
      expect(settings.ocrSettings.engineMode, OcrEngineMode.api);
      expect(settings.ocrSettings.apiBaseUrl, 'http://192.168.1.50:8000');
      expect(settings.ocrSettings.apiVersion, PythonApiVersion.v1);
      expect(settings.ocrSettings.reviewBeforeSaving, isFalse);
      expect(settings.ocrSettings.duplicateDetection, isTrue);
    });
  });
}
