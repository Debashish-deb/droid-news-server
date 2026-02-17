// lib/domain/repositories/premium_repository.dart
import 'dart:async';

abstract class PremiumRepository {
  /// Stream of premium status for real-time UI updates
  Stream<bool> get premiumStatusStream;
  
  /// Synchronous check of the last known status
  bool get isPremium;

  /// Whether the app should show ads (inverse of isPremium)
  bool get shouldShowAds;

  /// Refreshes the status from local storage and Remote Config whitelists
  Future<void> refreshStatus();

  /// Manually set the premium status (e.g., after a successful purchase)
  Future<void> setPremium(bool value);
}