import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/premium_service.dart';

/// Service to manage rewarded video ads for unlocking premium content
class RewardedAdService {
  factory RewardedAdService() => _instance;
  RewardedAdService._internal();
  static final RewardedAdService _instance = RewardedAdService._internal();

  RewardedAd? _rewardedAd;
  bool _isAdLoaded = false;
  bool _isLoading = false;

  // Track unlocked articles (temporary - resets on app restart)
  final Set<String> _unlockedArticles = <String>{};

  // Track rewarded ad views for analytics
  int _rewardedAdViewCount = 0;

  PremiumService? _premiumService;
  SharedPreferences? _prefs;

  /// Initialize the service with PremiumService reference
  void init(PremiumService premiumService, SharedPreferences prefs) {
    _premiumService = premiumService;
    _prefs = prefs;
    _rewardedAdViewCount = prefs.getInt('rewarded_ad_count') ?? 0;

    // Preload first ad
    _loadAd();
  }

  /// Load a rewarded ad
  Future<void> _loadAd() async {
    // Don't load if already loaded or loading
    if (_isAdLoaded || _isLoading) return;

    // Premium users don't need rewarded ads
    if (_premiumService?.isPremium ?? false) return;

    _isLoading = true;

    final String adUnitId = _resolveAdUnitId();

    await RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          _rewardedAd = ad;
          _isAdLoaded = true;
          _isLoading = false;

          // Set up callbacks
          _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (RewardedAd ad) {
              ad.dispose();
              _rewardedAd = null;
              _isAdLoaded = false;
              // Preload next ad
              _loadAd();
            },
            onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
              if (kDebugMode) {
                debugPrint('❌ Rewarded ad failed to show: $error');
              }
              ad.dispose();
              _rewardedAd = null;
              _isAdLoaded = false;
              _loadAd();
            },
          );

          if (kDebugMode) {
            debugPrint('✅ Rewarded ad loaded successfully');
          }
        },
        onAdFailedToLoad: (LoadAdError error) {
          if (kDebugMode) {
            debugPrint('❌ Rewarded ad failed to load: $error');
          }
          _isLoading = false;
          _rewardedAd = null;
          _isAdLoaded = false;

          // Retry after delay
          Future<void>.delayed(const Duration(seconds: 30), _loadAd);
        },
      ),
    );
  }

  /// Resolve ad unit ID from environment or use test ID
  String _resolveAdUnitId() {
    final String? prod = dotenv.env['REWARDED_AD_UNIT_ID'];
    final String? test = dotenv.env['REWARDED_AD_UNIT_ID_TEST'];

    if (prod != null && prod.isNotEmpty) return prod;
    if (test != null && test.isNotEmpty) return test;

    // Google's test rewarded ad ID
    return 'ca-app-pub-3940256099942544/5224354917';
  }

  /// Show rewarded ad to unlock article
  /// Returns true if ad was shown and reward granted, false otherwise
  Future<bool> showAdToUnlockArticle(String articleUrl) async {
    // Premium users get instant access
    if (_premiumService?.isPremium ?? false) {
      _unlockedArticles.add(articleUrl);
      return true;
    }

    // Already unlocked
    if (_unlockedArticles.contains(articleUrl)) {
      return true;
    }

    // Check if ad is ready
    if (!_isAdLoaded || _rewardedAd == null) {
      if (kDebugMode) {
        debugPrint('⚠️ Rewarded ad not ready yet');
      }
      // Try to load if not already loading
      if (!_isLoading) {
        _loadAd();
      }
      return false;
    }

    // Show the ad
    final Completer<bool> completer = Completer<bool>();

    _rewardedAd!.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        // User watched the ad - unlock the article
        _unlockedArticles.add(articleUrl);
        _rewardedAdViewCount++;
        _prefs?.setInt('rewarded_ad_count', _rewardedAdViewCount);

        if (kDebugMode) {
          debugPrint('🎁 User earned reward! Unlocked: $articleUrl');
          debugPrint('📊 Total rewarded ads watched: $_rewardedAdViewCount');
        }

        completer.complete(true);
      },
    );

    // Set a timeout in case the callback doesn't fire
    Future<void>.delayed(const Duration(seconds: 45), () {
      if (!completer.isCompleted) {
        completer.complete(false);
      }
    });

    return completer.future;
  }

  /// Check if an article is unlocked
  bool isArticleUnlocked(String articleUrl) {
    // Premium users have access to all articles
    if (_premiumService?.isPremium ?? false) return true;

    return _unlockedArticles.contains(articleUrl);
  }

  /// Check if ad is ready to show
  bool get isAdReady => _isAdLoaded && _rewardedAd != null;

  /// Get total number of rewarded ads watched
  int get totalRewardedAdsWatched => _rewardedAdViewCount;

  /// Manually load an ad (useful if user needs to unlock but ad isn't ready)
  Future<void> loadAdManually() async {
    if (!_isAdLoaded && !_isLoading) {
      await _loadAd();
    }
  }

  /// Clear unlocked articles (called on app restart or when user logs out)
  void clearUnlockedArticles() {
    _unlockedArticles.clear();
  }

  /// Dispose of the current ad
  void dispose() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
    _isAdLoaded = false;
    _isLoading = false;
  }
}
