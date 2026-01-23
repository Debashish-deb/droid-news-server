// lib/presentation/providers/premium_providers.dart
// =================================================
// RIVERPOD PROVIDERS FOR PREMIUM SERVICE
// =================================================

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'shared_providers.dart';

// ============================================
// PREMIUM STATE
// ============================================

/// Immutable premium state
@immutable
class PremiumState {
  const PremiumState({this.isPremium = false});
  final bool isPremium;

  bool get shouldShowAds => !isPremium;

  PremiumState copyWith({bool? isPremium}) {
    return PremiumState(isPremium: isPremium ?? this.isPremium);
  }
}

// ============================================
// PREMIUM NOTIFIER
// ============================================

class PremiumNotifier extends StateNotifier<PremiumState> {
  PremiumNotifier(this._prefs) : super(const PremiumState()) {
    loadStatus();
  }
  final SharedPreferences _prefs;
  static const String _key = 'is_premium';

  static const List<String> _premiumWhitelist = <String>[
    'ddeba32@gmail.com',
    'debashish.deb@gmail.com',
    'admin@bdnews.com',
    'test@test.com',
    'debashishdeb@gmail.com',
  ];

  /// Load premium status from storage and check whitelist
  Future<void> loadStatus() async {
    bool localStatus = _prefs.getBool(_key) ?? false;

    // Check whitelist - try Firebase Auth email first
    String? email;
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      email = firebaseUser?.email;
    } catch (_) {}

    // Fallback to cached email
    email ??= _prefs.getString('user_email');

    if (email != null && _premiumWhitelist.contains(email.toLowerCase())) {
      localStatus = true;
      debugPrint('👑 Premium granted via whitelist for: $email');
    }

    state = PremiumState(isPremium: localStatus);
  }

  /// Set premium status
  Future<void> setPremium(bool value) async {
    await _prefs.setBool(_key, value);
    state = PremiumState(isPremium: value);
  }

  /// Reload status (call after login/logout)
  Future<void> reloadStatus() async {
    debugPrint('🔄 Reloading premium status...');
    await loadStatus();
  }
}

// ============================================
// PROVIDERS
// ============================================

/// Main premium provider
final premiumProvider = StateNotifierProvider<PremiumNotifier, PremiumState>((
  ref,
) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return PremiumNotifier(prefs);
});

/// Convenience: just the isPremium boolean
final isPremiumProvider = Provider<bool>((ref) {
  return ref.watch(premiumProvider.select((state) => state.isPremium));
});

/// Convenience: should show ads
final shouldShowAdsProvider = Provider<bool>((ref) {
  return ref.watch(premiumProvider.select((state) => state.shouldShowAds));
});
