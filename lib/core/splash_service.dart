// lib/core/splash_service.dart
import 'package:shared_preferences/shared_preferences.dart';
import '../data/services/push_notification_service.dart';

class SplashService {
  SplashService({required this.prefs}) {
    // Initialize heavy services in background (don't block UI)
    _initializeServices();
  }
  
  final SharedPreferences prefs;

  static const String onboardingCompletedKey = 'onboardingCompleted';
  static const String isLoggedInKey = 'isLoggedIn';

  Future<void> _initializeServices() async {
    try {
      // Fire and forget - let these run in background
      await PushNotificationService().initialize(prefs: prefs);
    } catch (e) {
      // Log error but don't crash
      print('Service init error: $e');
    }
  }

  Future<String> resolveInitialRoute() async {

    // Check if user is logged in
    final bool isLoggedIn = prefs.getBool(isLoggedInKey) ?? false;
    final bool onboardingCompleted = prefs.getBool(onboardingCompletedKey) ?? false;

    if (isLoggedIn) {
      return '/home';
    } else if (!onboardingCompleted) {
      return '/onboarding'; // Assuming route exists, or defaults to home
    } else {
       return '/home'; 
    }
  }
}
