import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'di/service_locator.dart';

/// A single, app-wide service that holds "isPremium" state.
class PremiumService extends ChangeNotifier {
  PremiumService({required this.prefs});
  static const String _key = 'is_premium';

  final SharedPreferences prefs;

  bool _isPremium = false;

  /// Returns true if the user has purchased premium access.
  bool get isPremium => _isPremium;

  /// Returns true if ads should be shown (i.e., not premium).
  bool get shouldShowAds => !_isPremium;

  /// Call once on app startup to load the saved premium state.
  Future<void> loadStatus() async {
    // 1. Check persistent storage override
    bool localStatus = prefs.getBool(_key) ?? false;

    // 2. Check whitelist from Remote Config
    String? email;
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      email = firebaseUser?.email;
    } catch (_) {
      // Firebase not available
    }
    email ??= prefs.getString('user_email');

    if (email != null) {
      // Get whitelist from Remote Config
      final dynamic whitelist = sl.remoteConfig.getJson('premium_whitelist');
      if (whitelist is List) {
        final List<String> emails = whitelist.cast<String>();
        if (emails.contains(email.toLowerCase())) {
          localStatus = true;
          debugPrint('👑 Premium granted via Remote Config whitelist for: $email');
        }
      }
    }

    _isPremium = localStatus;
    notifyListeners();
  }

  /// Reload premium status - call after login/logout or app resume.
  /// Re-checks both SharedPreferences and whitelist.
  Future<void> reloadStatus() async {
    debugPrint('🔄 Reloading premium status...');
    await loadStatus();
  }

  /// Call when a purchase completes or user upgrades to premium.
  Future<void> setPremium(bool value) async {
    await prefs.setBool(_key, value);
    _isPremium = value;
    notifyListeners();
  }
}
