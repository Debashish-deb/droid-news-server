import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A single, app-wide service that holds "isPremium" state.
class PremiumService extends ChangeNotifier {
  static const _key = 'is_premium';

  final SharedPreferences prefs;
  PremiumService({required this.prefs});

  bool _isPremium = false;

  /// Returns true if the user has purchased premium access.
  bool get isPremium => _isPremium;

  /// Returns true if ads should be shown (i.e., not premium).
  bool get shouldShowAds => !_isPremium;

  /// Call once on app startup to load the saved premium state.
  Future<void> loadStatus() async {
    _isPremium = prefs.getBool(_key) ?? false;
    notifyListeners();
  }

  /// Call when a purchase completes or user upgrades to premium.
  Future<void> setPremium(bool value) async {
    await prefs.setBool(_key, value);
    _isPremium = value;
    notifyListeners();
  }
}
