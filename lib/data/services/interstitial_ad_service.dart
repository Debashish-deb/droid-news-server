import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../core/premium_service.dart';

/// Service to manage interstitial ads with automatic premium bypass.
/// Shows ads at strategic points to improve user engagement while
/// respecting premium user status.
class InterstitialAdService {
  factory InterstitialAdService() => _instance;
  InterstitialAdService._internal();
  static final InterstitialAdService _instance =
      InterstitialAdService._internal();

  InterstitialAd? _interstitialAd;
  bool _isAdLoaded = false;
  bool _isLoading = false;

  // Track article views to show ads every 3rd article
  int _articleViewCount = 0;
  static const int _adFrequency = 3; // Show ad every 3 articles

  // Cooldown to prevent too frequent ads
  DateTime? _lastAdShownTime;
  static const Duration _cooldownDuration = Duration(minutes: 30);

  PremiumService? _premiumService;

  /// Initialize the service with PremiumService reference
  void init(PremiumService premiumService) {
    _premiumService = premiumService;
    // Preload first ad for smooth UX
    _loadAd();
  }

  // Exponential Backoff
  int _retryAttempt = 0;
  static const int _maxRetryAttempts = 6;

  /// Load an interstitial ad
  Future<void> _loadAd() async {
    // Don't load if already loaded or loading
    if (_isAdLoaded || _isLoading) return;

    // Don't load for premium users
    if (_premiumService?.isPremium ?? false) return;

    _isLoading = true;
    final String adUnitId = _resolveAdUnitId();

    if (kDebugMode) {
      debugPrint('⏳ Loading Interstitial Ad...');
    }

    await InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          if (kDebugMode) {
            debugPrint('✅ Interstitial Ad Loaded');
          }
          _interstitialAd = ad;
          _isAdLoaded = true;
          _isLoading = false;
          _retryAttempt = 0; // Reset retry count on success

          _interstitialAd!
              .fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: _onAdDismissed,
            onAdFailedToShowFullScreenContent: _onAdFailedToShow,
          );
        },
        onAdFailedToLoad: (LoadAdError error) {
          if (kDebugMode) {
            debugPrint('❌ Interstitial Ad Failed to Load: ${error.message}');
          }
          _isLoading = false;
          _interstitialAd = null;
          _isAdLoaded = false;
          _scheduleRetry();
        },
      ),
    );
  }

  void _scheduleRetry() {
    if (_retryAttempt >= _maxRetryAttempts) {
      if (kDebugMode) {
        debugPrint(
          '🛑 Max ad retry attempts reached. Giving up for this session.',
        );
      }
      return;
    }

    _retryAttempt++;
    final int delaySeconds =
        2 * (1 << (_retryAttempt - 1)); // 2, 4, 8, 16, 32...
    if (kDebugMode) {
      debugPrint(
        '🔄 Retrying ad load in $delaySeconds seconds (Attempt $_retryAttempt)',
      );
    }

    Future.delayed(Duration(seconds: delaySeconds), _loadAd);
  }

  void _onAdDismissed(InterstitialAd ad) {
    if (kDebugMode) {
      debugPrint('👋 Ad Dismissed');
    }
    ad.dispose();
    _interstitialAd = null;
    _isAdLoaded = false;
    _loadAd(); // Preload next
  }

  void _onAdFailedToShow(InterstitialAd ad, AdError error) {
    if (kDebugMode) {
      debugPrint('⚠️ Ad Failed to Show: ${error.message}');
    }
    ad.dispose();
    _interstitialAd = null;
    _isAdLoaded = false;
    _loadAd(); // Try again
  }

  /// Resolve ad unit ID from environment or use test ID
  String _resolveAdUnitId() {
    final String? prod = dotenv.env['INTERSTITIAL_AD_UNIT_ID'];
    final String? test = dotenv.env['INTERSTITIAL_AD_UNIT_ID_TEST'];

    if (prod != null && prod.isNotEmpty) return prod;
    if (test != null && test.isNotEmpty) return test;

    // Google's test interstitial ad ID
    return 'ca-app-pub-3940256099942544/1033173712';
  }

  /// Check if an ad should be shown based on cooldown and premium status
  bool _shouldShowAd() {
    // Never show ads to premium users
    if (_premiumService?.isPremium ?? false) return false;

    // Check if ad is loaded
    if (!_isAdLoaded || _interstitialAd == null) return false;

    // Check cooldown period
    if (_lastAdShownTime != null) {
      final Duration timeSinceLastAd = DateTime.now().difference(
        _lastAdShownTime!,
      );
      if (timeSinceLastAd < _cooldownDuration) {
        if (kDebugMode) {
          debugPrint(
            '⏳ Ad cooldown active. ${_cooldownDuration.inSeconds - timeSinceLastAd.inSeconds}s remaining',
          );
        }
        return false;
      }
    }

    return true;
  }

  /// Increment article view count and show ad if threshold reached
  Future<void> onArticleViewed() async {
    // Don't track for premium users
    if (_premiumService?.isPremium ?? false) return;

    _articleViewCount++;

    if (kDebugMode) {
      debugPrint('📰 Article view count: $_articleViewCount');
    }

    // Show ad every 3rd article
    if (_articleViewCount % _adFrequency == 0) {
      await showAd(reason: 'Article view threshold reached');
    }
  }

  /// Show interstitial ad if conditions are met
  Future<void> showAd({String reason = 'Manual trigger'}) async {
    if (!_shouldShowAd()) {
      if (kDebugMode) {
        debugPrint('🚫 Ad not shown: Conditions not met ($reason)');
      }
      // Try to load if not loaded
      if (!_isAdLoaded && !_isLoading) {
        _loadAd();
      }
      return;
    }

    if (kDebugMode) {
      debugPrint('🎬 Showing ad: $reason');
    }

    _lastAdShownTime = DateTime.now();
    await _interstitialAd?.show();
  }

  /// Show ad on manual refresh if cooldown has elapsed
  Future<void> onManualRefresh() async {
    await showAd(reason: 'Manual refresh');
  }

  /// Dispose of the current ad
  void dispose() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _isAdLoaded = false;
    _isLoading = false;
  }

  /// Reset article view count (useful for testing or session resets)
  void resetArticleCount() {
    _articleViewCount = 0;
  }
}
