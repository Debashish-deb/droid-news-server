import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../domain/repositories/premium_repository.dart';

/// Centralized ad runtime guard.
///
/// Why this exists:
/// 1) Prevent ad SDK initialization before entitlement is verified.
/// 2) Keep premium/unresolved users fully ad-free (fail-safe default).
class AdRuntimeGate {
  AdRuntimeGate._();

  static Future<InitializationStatus>? _initFuture;

  static Future<bool> ensureInitializedIfEligible(
    PremiumRepository premiumRepository, {
    Duration refreshTimeout = const Duration(seconds: 3),
  }) async {
    // Always refresh entitlement before ad work to avoid stale tier leaks.
    try {
      await premiumRepository.refreshStatus().timeout(refreshTimeout);
    } catch (_) {
      // Fail-safe: unresolved/failed refresh means we do NOT initialize ads.
    }

    if (!premiumRepository.shouldShowAds) {
      return false;
    }

    final existing = _initFuture;
    if (existing != null) {
      try {
        await existing;
        return true;
      } catch (_) {
        _initFuture = null;
        return false;
      }
    }

    _initFuture = MobileAds.instance.initialize();
    try {
      await _initFuture;
      return true;
    } catch (_) {
      _initFuture = null;
      return false;
    }
  }
}
