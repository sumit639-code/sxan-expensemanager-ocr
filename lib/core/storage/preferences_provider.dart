import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_preferences.dart';
import 'shared_prefs_app_preferences.dart';

/// Riverpod provider exposing the [AppPreferences] singleton instance.
final appPreferencesProvider = Provider<AppPreferences>((ref) {
  return SharedPrefsAppPreferences();
});
