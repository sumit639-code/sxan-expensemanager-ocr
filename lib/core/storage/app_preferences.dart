/// Abstract contract for local application preferences persistence.
abstract class AppPreferences {
  Future<bool> hasCompletedOnboarding();
  Future<void> setOnboardingCompleted(bool completed);
  Future<String?> getUserName();
  Future<void> setUserName(String name);
}
