import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _keyOnboardingDone = 'utserve_onboarding_done';

final onboardingDoneProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_keyOnboardingDone) ?? false;
});

Future<void> setOnboardingDone() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_keyOnboardingDone, true);
}

/// Clears the onboarding-done flag so the user will see onboarding again on next login.
Future<void> clearOnboardingDone() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_keyOnboardingDone);
}

final onboardingRoleProvider = StateProvider<String?>((ref) => null);
final onboardingFirstNameProvider = StateProvider<String>((ref) => '');
final onboardingLastNameProvider = StateProvider<String>((ref) => '');
final onboardingUsernameProvider = StateProvider<String>((ref) => '');
final onboardingInterestsProvider = StateProvider<List<String>>((ref) => []);
