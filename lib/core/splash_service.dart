import 'package:shared_preferences/shared_preferences.dart';

class SplashService {
  SplashService({required this.prefs});
  
  final SharedPreferences prefs;

  static const String onboardingCompletedKey = 'onboardingCompleted';
  static const String isLoggedInKey = 'isLoggedIn';

  // Removed _initializeServices() - notification permission should be requested
  // later in the user journey, not during app startup

  Future<String> resolveInitialRoute() async {

    final bool isLoggedIn = prefs.getBool(isLoggedInKey) ?? false;
    final bool onboardingCompleted = prefs.getBool(onboardingCompletedKey) ?? false;

    if (isLoggedIn) {
      return '/home';
    } else if (!onboardingCompleted) {
      return '/onboarding'; 
    }
    return '/home'; 
  }
}
