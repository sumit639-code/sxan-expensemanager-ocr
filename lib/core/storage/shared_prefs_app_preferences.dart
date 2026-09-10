import 'package:shared_preferences/shared_preferences.dart';

import 'app_preferences.dart';

/// SharedPreferences implementation of [AppPreferences].
class SharedPrefsAppPreferences implements AppPreferences {
  static const String _onboardingKey = 'has_completed_onboarding';
  static const String _userNameKey = 'user_name';

  @override
  Future<bool> hasCompletedOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingKey) ?? false;
  }

  @override
  Future<void> setOnboardingCompleted(bool completed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, completed);
  }

  @override
  Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userNameKey);
  }

  @override
  Future<void> setUserName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userNameKey, name);
  }
}
