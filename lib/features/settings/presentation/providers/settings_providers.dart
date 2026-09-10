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

/// Provider for the active [DashboardPreferences].
final dashboardPreferencesProvider = Provider<DashboardPreferences>((ref) {
  return ref.watch(settingsNotifierProvider.select((s) => s.dashboardPreferences));
});

/// Provider for the active [OcrSettings].
final ocrSettingsProvider = Provider<OcrSettings>((ref) {
  return ref.watch(settingsNotifierProvider.select((s) => s.ocrSettings));
});
