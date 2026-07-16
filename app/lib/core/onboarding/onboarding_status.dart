import 'package:shared_preferences/shared_preferences.dart';

const _prefsKey = 'onboarding_completed';

/// Lokal statt gegen profiles geprüft — ein SharedPreferences-Read ist
/// synchron genug, um vor dem ersten Frame zu entscheiden, ohne den
/// Kaltstart auf einen Netzwerk-Roundtrip warten zu lassen. profiles wird
/// beim Abschluss trotzdem mitgeschrieben (siehe OnboardingScreen), aber nur
/// als Sync-Ziel fürs Backend, nicht als Quelle für diese Entscheidung.
class OnboardingStatus {
  const OnboardingStatus._();

  static Future<bool> isCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsKey) ?? false;
  }

  static Future<void> markCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, true);
  }
}
