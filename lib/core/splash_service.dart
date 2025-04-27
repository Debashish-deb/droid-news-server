// lib/core/splash_service.dart
import 'package:shared_preferences/shared_preferences.dart';

class SplashService {
  Future<String> resolveInitialRoute() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenOnboarding = prefs.getBool('onboardingCompleted') ?? false;
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

    if (!hasSeenOnboarding) {
      return '/onboarding';
    } else if (!isLoggedIn) {
      return '/login';
    } else {
      return '/home';
    }
  }
}