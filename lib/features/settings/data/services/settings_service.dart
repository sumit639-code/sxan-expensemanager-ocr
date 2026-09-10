import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/app_settings.dart';

/// Local service managing persistence of [AppSettings] via [SharedPreferences].
class SettingsService {
  static const String _keyUserName = 'user_name';
  static const String _keyThemeMode = 'app_theme_mode';
  static const String _keyAccentColor = 'app_accent_color';
  static const String _keyCurrency = 'app_currency_code';
  static const String _keyShowBalance = 'dash_show_balance';
  static const String _keyShowRecent = 'dash_show_recent';
  static const String _keyShowSummary = 'dash_show_summary';
  static const String _keyShowQuickActions = 'dash_show_quick_actions';
  static const String _keyOcrEngineMode = 'ocr_engine_mode';
  static const String _keyOcrApiBaseUrl = 'ocr_api_base_url';
  static const String _keyOcrApiVersion = 'ocr_api_version';
  static const String _keyOcrReview = 'ocr_review_before_saving';
  static const String _keyOcrDuplicate = 'ocr_duplicate_detection';

  final SharedPreferences _prefs;

  SettingsService(this._prefs);

  /// Loads stored settings or returns defaults.
  AppSettings loadSettings() {
    final userName = _prefs.getString(_keyUserName) ?? 'Alex';
    final themeModeStr = _prefs.getString(_keyThemeMode);
    final accentColorStr = _prefs.getString(_keyAccentColor);
    final currency = _prefs.getString(_keyCurrency) ?? 'INR';

    final dashPrefs = DashboardPreferences(
      showBalance: _prefs.getBool(_keyShowBalance) ?? true,
      showRecentTransactions: _prefs.getBool(_keyShowRecent) ?? true,
      showSpendingSummary: _prefs.getBool(_keyShowSummary) ?? true,
      showQuickActions: _prefs.getBool(_keyShowQuickActions) ?? true,
    );

    final ocrEngineModeStr = _prefs.getString(_keyOcrEngineMode);
    final ocrApiBaseUrl =
        _prefs.getString(_keyOcrApiBaseUrl) ?? 'http://127.0.0.1:8000';
    final ocrApiVersionStr = _prefs.getString(_keyOcrApiVersion);

    final ocrSettings = OcrSettings(
      engineMode: OcrEngineMode.fromString(ocrEngineModeStr),
      apiBaseUrl: ocrApiBaseUrl,
      apiVersion: PythonApiVersion.fromString(ocrApiVersionStr),
      reviewBeforeSaving: _prefs.getBool(_keyOcrReview) ?? true,
      duplicateDetection: _prefs.getBool(_keyOcrDuplicate) ?? true,
    );

    return AppSettings(
      userName: userName,
      themeMode: AppThemeMode.fromString(themeModeStr),
      accentColor: AppAccentColor.fromString(accentColorStr),
      currencyCode: currency,
      dashboardPreferences: dashPrefs,
      ocrSettings: ocrSettings,
    );
  }

  Future<void> saveUserName(String name) async {
    await _prefs.setString(_keyUserName, name);
  }

  Future<void> saveThemeMode(AppThemeMode mode) async {
    await _prefs.setString(_keyThemeMode, mode.value);
  }

  Future<void> saveAccentColor(AppAccentColor color) async {
    await _prefs.setString(_keyAccentColor, color.value);
  }

  Future<void> saveCurrency(String currency) async {
    await _prefs.setString(_keyCurrency, currency);
  }

  Future<void> saveDashboardPreferences(DashboardPreferences prefs) async {
    await _prefs.setBool(_keyShowBalance, prefs.showBalance);
    await _prefs.setBool(_keyShowRecent, prefs.showRecentTransactions);
    await _prefs.setBool(_keyShowSummary, prefs.showSpendingSummary);
    await _prefs.setBool(_keyShowQuickActions, prefs.showQuickActions);
  }

  Future<void> saveOcrSettings(OcrSettings settings) async {
    await _prefs.setString(_keyOcrEngineMode, settings.engineMode.value);
    await _prefs.setString(_keyOcrApiBaseUrl, settings.apiBaseUrl);
    await _prefs.setString(_keyOcrApiVersion, settings.apiVersion.value);
    await _prefs.setBool(_keyOcrReview, settings.reviewBeforeSaving);
    await _prefs.setBool(_keyOcrDuplicate, settings.duplicateDetection);
  }
}
