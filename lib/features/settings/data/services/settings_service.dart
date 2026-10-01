import 'package:shared_preferences/shared_preferences.dart';

import 'package:expense_app/features/analysis/domain/entities/analysis_period.dart';
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
  static const String _keySoundEnabled = 'app_sound_enabled';
  static const String _keySoundVolume = 'app_sound_volume';
  static const String _keyFontPreset = 'app_font_preset';
  static const String _keyCardRounding = 'app_card_rounding';
  static const String _keyCardStyle = 'app_card_style';
  static const String _keyAutoDetectBankSms = 'auto_detect_bank_sms';
  static const String _keySmsExcludedKeywords = 'sms_excluded_keywords';
  static const String _keySelectedPeriodType = 'selected_period_type';
  static const String _keySelectedPeriodCustomStart = 'selected_period_custom_start';
  static const String _keySelectedPeriodCustomEnd = 'selected_period_custom_end';

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

    final soundEnabled = _prefs.getBool(_keySoundEnabled) ?? true;
    final soundVolume = _prefs.getDouble(_keySoundVolume) ?? 0.8;
    final fontPresetStr = _prefs.getString(_keyFontPreset);
    final cardRoundingStr = _prefs.getString(_keyCardRounding);
    final cardStyleStr = _prefs.getString(_keyCardStyle);
    final autoDetectBankSms = _prefs.getBool(_keyAutoDetectBankSms) ?? true;
    final smsExcludedKeywords = _prefs.getStringList(_keySmsExcludedKeywords) ??
        AppSettings.defaultSmsExcludedKeywords;

    return AppSettings(
      userName: userName,
      themeMode: AppThemeMode.fromString(themeModeStr),
      accentColor: AppAccentColor.fromString(accentColorStr),
      currencyCode: currency,
      dashboardPreferences: dashPrefs,
      ocrSettings: ocrSettings,
      soundEnabled: soundEnabled,
      soundVolume: soundVolume,
      fontPreset: AppFontPreset.fromString(fontPresetStr),
      cardRounding: AppCardRounding.fromString(cardRoundingStr),
      cardStyle: AppCardStyle.fromString(cardStyleStr),
      autoDetectBankSms: autoDetectBankSms,
      smsExcludedKeywords: smsExcludedKeywords,
    );
  }

  Future<void> saveAutoDetectBankSms(bool enabled) async {
    await _prefs.setBool(_keyAutoDetectBankSms, enabled);
  }

  Future<void> saveSmsExcludedKeywords(List<String> keywords) async {
    await _prefs.setStringList(_keySmsExcludedKeywords, keywords);
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

  Future<void> saveSoundEnabled(bool enabled) async {
    await _prefs.setBool(_keySoundEnabled, enabled);
  }

  Future<void> saveSoundVolume(double volume) async {
    await _prefs.setDouble(_keySoundVolume, volume);
  }

  Future<void> saveFontPreset(AppFontPreset preset) async {
    await _prefs.setString(_keyFontPreset, preset.value);
  }

  Future<void> saveCardRounding(AppCardRounding rounding) async {
    await _prefs.setString(_keyCardRounding, rounding.value);
  }

  Future<void> saveCardStyle(AppCardStyle style) async {
    await _prefs.setString(_keyCardStyle, style.value);
  }

  /// Loads stored analysis/dashboard time period or defaults to thisMonth.
  AnalysisPeriod loadSelectedPeriod() {
    final typeStr = _prefs.getString(_keySelectedPeriodType);
    if (typeStr == null) {
      return AnalysisPeriod.fromType(AnalysisPeriodType.thisMonth);
    }
    final type = AnalysisPeriodType.values.firstWhere(
      (e) => e.name == typeStr,
      orElse: () => AnalysisPeriodType.thisMonth,
    );
    if (type == AnalysisPeriodType.custom) {
      final startMillis = _prefs.getInt(_keySelectedPeriodCustomStart);
      final endMillis = _prefs.getInt(_keySelectedPeriodCustomEnd);
      final start = startMillis != null
          ? DateTime.fromMillisecondsSinceEpoch(startMillis)
          : null;
      final end = endMillis != null
          ? DateTime.fromMillisecondsSinceEpoch(endMillis)
          : null;
      return AnalysisPeriod.fromType(type, customStart: start, customEnd: end);
    }
    return AnalysisPeriod.fromType(type);
  }

  /// Permanently saves the selected analysis/dashboard time period.
  Future<void> saveSelectedPeriod(AnalysisPeriod period) async {
    await _prefs.setString(_keySelectedPeriodType, period.type.name);
    if (period.type == AnalysisPeriodType.custom) {
      await _prefs.setInt(
        _keySelectedPeriodCustomStart,
        period.startDate.millisecondsSinceEpoch,
      );
      await _prefs.setInt(
        _keySelectedPeriodCustomEnd,
        period.endDate.millisecondsSinceEpoch,
      );
    } else {
      await _prefs.remove(_keySelectedPeriodCustomStart);
      await _prefs.remove(_keySelectedPeriodCustomEnd);
    }
  }
}
