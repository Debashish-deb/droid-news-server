// lib/core/splash_service.dart
import 'package:shared_preferences/shared_preferences.dart';

class SplashService {
  final SharedPreferences prefs;

  SplashService({required this.prefs});

  static const String onboardingCompletedKey = 'onboardingCompleted';
  static const String isLoggedInKey = 'isLoggedIn';

  Future<String> resolveInitialRoute() async {
    final hasSeenOnboarding = prefs.getBool(onboardingCompletedKey) ?? false;
    final isLoggedIn = prefs.getBool(isLoggedInKey) ?? false;

    if (!hasSeenOnboarding) {
      return '/onboarding';
    } else if (!isLoggedIn) {
      return '/login';
    } else {
      return '/home';
    }
  }
}
