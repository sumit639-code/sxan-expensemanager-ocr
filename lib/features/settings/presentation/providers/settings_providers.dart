import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/services/settings_service.dart';
import '../../domain/entities/app_settings.dart';

/// Provider for [SharedPreferences] instance.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden in ProviderScope');
});

/// Provider for [SettingsService].
final settingsServiceProvider = Provider<SettingsService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SettingsService(prefs);
});

/// StateNotifier managing reactive [AppSettings].
class SettingsNotifier extends StateNotifier<AppSettings> {
  final SettingsService? _service;

  SettingsNotifier([this._service])
      : super(_service?.loadSettings() ?? const AppSettings());

  Future<void> updateUserName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    state = state.copyWith(userName: trimmed);
    await _service?.saveUserName(trimmed);
  }

  Future<void> updateThemeMode(AppThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _service?.saveThemeMode(mode);
  }

  Future<void> updateAccentColor(AppAccentColor color) async {
    state = state.copyWith(accentColor: color);
    await _service?.saveAccentColor(color);
  }

  Future<void> updateCurrency(String currency) async {
    state = state.copyWith(currencyCode: currency);
    await _service?.saveCurrency(currency);
  }

  Future<void> updateDashboardPreferences(DashboardPreferences prefs) async {
    state = state.copyWith(dashboardPreferences: prefs);
    await _service?.saveDashboardPreferences(prefs);
  }

  Future<void> updateOcrSettings(OcrSettings settings) async {
    state = state.copyWith(ocrSettings: settings);
    await _service?.saveOcrSettings(settings);
  }

  Future<void> updateOcrEngineMode(OcrEngineMode mode) async {
    state = state.copyWith(
      ocrSettings: state.ocrSettings.copyWith(engineMode: mode),
    );
    await _service?.saveOcrSettings(state.ocrSettings);
  }

  Future<void> updateOcrApiBaseUrl(String url) async {
    state = state.copyWith(
      ocrSettings: state.ocrSettings.copyWith(apiBaseUrl: url),
    );
    await _service?.saveOcrSettings(state.ocrSettings);
  }

  Future<void> updateOcrApiVersion(PythonApiVersion version) async {
    state = state.copyWith(
      ocrSettings: state.ocrSettings.copyWith(apiVersion: version),
    );
    await _service?.saveOcrSettings(state.ocrSettings);
  }

  Future<void> updateSoundEnabled(bool enabled) async {
    state = state.copyWith(soundEnabled: enabled);
    await _service?.saveSoundEnabled(enabled);
  }

  Future<void> updateSoundVolume(double volume) async {
    state = state.copyWith(soundVolume: volume);
    await _service?.saveSoundVolume(volume);
  }

  Future<void> updateFontPreset(AppFontPreset preset) async {
    state = state.copyWith(fontPreset: preset);
    await _service?.saveFontPreset(preset);
  }

  Future<void> updateCardRounding(AppCardRounding rounding) async {
    state = state.copyWith(cardRounding: rounding);
    await _service?.saveCardRounding(rounding);
  }

  Future<void> updateCardStyle(AppCardStyle style) async {
    state = state.copyWith(cardStyle: style);
    await _service?.saveCardStyle(style);
  }

  Future<void> updateAutoDetectBankSms(bool enabled) async {
    state = state.copyWith(autoDetectBankSms: enabled);
    await _service?.saveAutoDetectBankSms(enabled);
  }

  Future<void> addSmsExcludedKeyword(String keyword) async {
    final clean = keyword.trim().toLowerCase();
    if (clean.isEmpty) return;
    if (state.smsExcludedKeywords.any((k) => k.toLowerCase() == clean)) return;
    final updated = [...state.smsExcludedKeywords, clean];
    state = state.copyWith(smsExcludedKeywords: updated);
    await _service?.saveSmsExcludedKeywords(updated);
  }

  Future<void> removeSmsExcludedKeyword(String keyword) async {
    final clean = keyword.trim().toLowerCase();
    final updated = state.smsExcludedKeywords
        .where((k) => k.toLowerCase() != clean)
        .toList();
    state = state.copyWith(smsExcludedKeywords: updated);
    await _service?.saveSmsExcludedKeywords(updated);
  }

  Future<void> resetSmsExcludedKeywords() async {
    final updated = List<String>.from(AppSettings.defaultSmsExcludedKeywords);
    state = state.copyWith(smsExcludedKeywords: updated);
    await _service?.saveSmsExcludedKeywords(updated);
  }
}

/// Provider managing active [AppSettings].
final settingsNotifierProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  try {
    final service = ref.watch(settingsServiceProvider);
    return SettingsNotifier(service);
  } catch (_) {
    return SettingsNotifier(null);
  }
});

/// Provider for the active [String] user name.
final userNameProvider = Provider<String>((ref) {
  return ref.watch(settingsNotifierProvider.select((s) => s.userName));
});

/// Provider for the active [AppThemeMode].
final appThemeModeProvider = Provider<AppThemeMode>((ref) {
  return ref.watch(settingsNotifierProvider.select((s) => s.themeMode));
});

/// Provider for the active [AppAccentColor].
final appAccentColorProvider = Provider<AppAccentColor>((ref) {
  return ref.watch(settingsNotifierProvider.select((s) => s.accentColor));
});

/// Provider for the active [AppFontPreset].
final appFontPresetProvider = Provider<AppFontPreset>((ref) {
  return ref.watch(settingsNotifierProvider.select((s) => s.fontPreset));
});

/// Provider for the active [AppCardRounding].
final appCardRoundingProvider = Provider<AppCardRounding>((ref) {
  return ref.watch(settingsNotifierProvider.select((s) => s.cardRounding));
});

/// Provider for the active [AppCardStyle].
final appCardStyleProvider = Provider<AppCardStyle>((ref) {
  return ref.watch(settingsNotifierProvider.select((s) => s.cardStyle));
});

/// Provider for the active [DashboardPreferences].
final dashboardPreferencesProvider = Provider<DashboardPreferences>((ref) {
  return ref.watch(settingsNotifierProvider.select((s) => s.dashboardPreferences));
});

/// Provider for the active [OcrSettings].
final ocrSettingsProvider = Provider<OcrSettings>((ref) {
  return ref.watch(settingsNotifierProvider.select((s) => s.ocrSettings));
});

/// Provider for sound effects enabled state.
final soundEnabledProvider = Provider<bool>((ref) {
  return ref.watch(settingsNotifierProvider.select((s) => s.soundEnabled));
});

/// Provider for sound effects volume level.
final soundVolumeProvider = Provider<double>((ref) {
  return ref.watch(settingsNotifierProvider.select((s) => s.soundVolume));
});

/// Provider for bank SMS auto-detection enabled state.
final autoDetectBankSmsProvider = Provider<bool>((ref) {
  return ref.watch(settingsNotifierProvider.select((s) => s.autoDetectBankSms));
});
