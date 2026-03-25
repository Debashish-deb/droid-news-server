import 'dart:async' show unawaited;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class SplashService {
  SplashService({required this.prefs});
  
  final SharedPreferences? prefs;

  static const String onboardingCompletedKey = 'onboardingCompleted';
  static const String isLoggedInKey = 'isLoggedIn';

  Future<String> resolveInitialRoute() async {
    if (prefs == null) {
      return '/splash';
    }

    final bool onboardingCompleted = prefs!.getBool(onboardingCompletedKey) ?? false;
    
    // Check Source of Truth (Firebase)
    // Only if Firebase is initialized.
    bool isLoggedIn = false;
    if (Firebase.apps.isNotEmpty) {
      isLoggedIn = FirebaseAuth.instance.currentUser != null;
    } else {
      // Fallback to hint if Firebase is not yet ready (though it should be in new bootstrap)
      isLoggedIn = prefs!.getBool(isLoggedInKey) ?? false;
    }
    
    // Synchronize the hint if needed
    final bool prefsLoggedIn = prefs!.getBool(isLoggedInKey) ?? false;
    if (isLoggedIn != prefsLoggedIn) {
      debugPrint('🔄 Synchronizing SharedPreferences isLoggedIn flag to $isLoggedIn');
      unawaited(prefs!.setBool(isLoggedInKey, isLoggedIn));
    }

    if (isLoggedIn) {
      return '/home';
    } else if (!onboardingCompleted) {
      return '/onboarding'; 
    }
    return '/home'; 
  }
}
