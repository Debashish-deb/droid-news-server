import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../domain/repositories/premium_repository.dart';
import 'ad_unit_config.dart';

/// Centralized ad runtime guard.
///
/// Why this exists:
/// 1) Prevent ad SDK initialization before entitlement is verified.
/// 2) Keep premium/unresolved users fully ad-free (fail-safe default).
class AdRuntimeGate {
  AdRuntimeGate._();

  static const bool _kEnableAdsInNonRelease = bool.fromEnvironment(
    'ENABLE_ADS_IN_NON_RELEASE',
  );

  static Future<InitializationStatus>? _initFuture;
  static Future<void>? _refreshFuture;
  static DateTime? _lastRefreshAt;
  static const Duration _defaultRefreshThrottle = Duration(seconds: 30);

  static bool get isAdSdkAllowed =>
      kReleaseMode ||
      _kEnableAdsInNonRelease ||
      AdUnitConfig.hasAnyConfiguredUnitIds;

  static Future<bool> ensureInitializedIfEligible(
    PremiumRepository premiumRepository, {
    Duration refreshTimeout = const Duration(seconds: 3),
    Duration refreshThrottle = _defaultRefreshThrottle,
  }) async {
    if (!isAdSdkAllowed) {
      return false;
    }

    final now = DateTime.now();
    final shouldRefresh =
        !premiumRepository.isStatusResolved ||
        _lastRefreshAt == null ||
        now.difference(_lastRefreshAt!) >= refreshThrottle;

    if (shouldRefresh) {
      final pendingRefresh = _refreshFuture;
      if (pendingRefresh != null) {
        try {
          await pendingRefresh.timeout(refreshTimeout);
        } catch (_) {
          // Fail-safe: unresolved/failed refresh means we do NOT initialize ads.
        }
      } else {
        final refreshFuture = premiumRepository.refreshStatus();
        _refreshFuture = refreshFuture;
        try {
          await refreshFuture.timeout(refreshTimeout);
        } catch (_) {
          // Fail-safe: unresolved/failed refresh means we do NOT initialize ads.
        } finally {
          _lastRefreshAt = DateTime.now();
          _refreshFuture = null;
        }
      }
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
