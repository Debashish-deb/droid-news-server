import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../domain/repositories/premium_repository.dart';
import '../ads/ad_runtime_gate.dart';

/// Service to manage rewarded video ads for unlocking premium content
class RewardedAdService {
  RewardedAdService(this._premiumRepository, this._prefs) {
    _init();
  }

  RewardedAd? _rewardedAd;
  bool _isAdLoaded = false;
  bool _isLoading = false;

  final Set<String> _unlockedArticles = <String>{};

  int _rewardedAdViewCount = 0;
  int _retryAttempt = 0;
  static const int _maxRetryAttempts = 6;
  Timer? _retryTimer;
  StreamSubscription<bool>? _premiumStatusSub;

  final PremiumRepository _premiumRepository;
  final SharedPreferences? _prefs;

  /// Initialize the service
  void _init() {
    if (_prefs != null) {
      _rewardedAdViewCount = _prefs.getInt('rewarded_ad_count') ?? 0;
      final savedArticles = _prefs.getStringList('unlocked_articles') ?? [];
      _unlockedArticles.addAll(savedArticles);
    }

    _premiumStatusSub = _premiumRepository.premiumStatusStream.listen((
      isPremium,
    ) {
      if (isPremium) {
        _retryTimer?.cancel();
        _rewardedAd?.dispose();
        _rewardedAd = null;
        _isAdLoaded = false;
        _isLoading = false;
        return;
      }
      if (!_isAdLoaded && !_isLoading) {
        unawaited(_loadAd());
      }
    });

    unawaited(_loadAd());
  }

  Future<void> _saveUnlockedArticles() async {
    if (_prefs != null) {
      await _prefs.setStringList(
        'unlocked_articles',
        _unlockedArticles.toList(),
      );
    }
  }

  /// Load a rewarded ad
  Future<void> _loadAd() async {
    if (_isAdLoaded || _isLoading) return;

    _isLoading = true;

    final sdkReady = await AdRuntimeGate.ensureInitializedIfEligible(
      _premiumRepository,
    );
    if (!sdkReady || !_premiumRepository.shouldShowAds) {
      _isLoading = false;
      return;
    }

    final String adUnitId = _resolveAdUnitId();

    try {
      await RewardedAd.load(
        adUnitId: adUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (RewardedAd ad) {
            _rewardedAd = ad;
            _isAdLoaded = true;
            _isLoading = false;
            _retryAttempt = 0;
            _retryTimer?.cancel();

            _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
              onAdDismissedFullScreenContent: (RewardedAd ad) {
                ad.dispose();
                _rewardedAd = null;
                _isAdLoaded = false;

                unawaited(_loadAd());
              },
              onAdFailedToShowFullScreenContent:
                  (RewardedAd ad, AdError error) {
                    if (kDebugMode) {
                      debugPrint('❌ Rewarded ad failed to show: $error');
                    }
                    ad.dispose();
                    _rewardedAd = null;
                    _isAdLoaded = false;
                    unawaited(_loadAd());
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
            _scheduleRetry();
          },
        ),
      );
    } catch (e) {
      _isLoading = false;
      _rewardedAd = null;
      _isAdLoaded = false;
      _scheduleRetry();
      if (kDebugMode) {
        debugPrint('❌ Rewarded ad load crashed: $e');
      }
    }
  }

  void _scheduleRetry() {
    if (_retryAttempt >= _maxRetryAttempts) {
      if (kDebugMode) {
        debugPrint('🛑 Rewarded ad retry cap reached for this session.');
      }
      return;
    }
    _retryAttempt++;
    final delaySeconds = (4 * (1 << (_retryAttempt - 1))).clamp(4, 300);
    _retryTimer?.cancel();
    _retryTimer = Timer(Duration(seconds: delaySeconds), () {
      unawaited(_loadAd());
    });
  }

  /// Resolve ad unit ID from environment or use test ID
  String _resolveAdUnitId() {
    final String? prod = dotenv.env['REWARDED_AD_UNIT_ID'];
    final String? test = dotenv.env['REWARDED_AD_UNIT_ID_TEST'];

    if (prod != null && prod.isNotEmpty) return prod;
    if (test != null && test.isNotEmpty) return test;

    return 'ca-app-pub-3940256099942544/5224354917';
  }

  /// Show rewarded ad to unlock article
  /// Returns true if ad was shown and reward granted, false otherwise
  Future<bool> showAdToUnlockArticle(String articleUrl) async {
    if (_premiumRepository.isPremium) {
      _unlockedArticles.add(articleUrl);
      return true;
    }

    if (!_premiumRepository.shouldShowAds) {
      if (!_isLoading) {
        unawaited(_loadAd());
      }
      return false;
    }

    if (_unlockedArticles.contains(articleUrl)) {
      return true;
    }

    if (!_isAdLoaded || _rewardedAd == null) {
      if (kDebugMode) {
        debugPrint('⚠️ Rewarded ad not ready yet');
      }

      if (!_isLoading) {
        unawaited(_loadAd());
      }
      return false;
    }

    final Completer<bool> completer = Completer<bool>();

    _rewardedAd!.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        _unlockedArticles.add(articleUrl);
        _rewardedAdViewCount++;
        _saveUnlockedArticles();
        _prefs?.setInt('rewarded_ad_count', _rewardedAdViewCount);

        if (kDebugMode) {
          debugPrint('🎁 User earned reward! Unlocked: $articleUrl');
          debugPrint('📊 Total rewarded ads watched: $_rewardedAdViewCount');
        }

        completer.complete(true);
      },
    );

    // Fix for silent Completer timeout bug
    Timer(const Duration(seconds: 45), () {
      if (!completer.isCompleted) {
        completer.complete(false);
      }
    });

    return completer.future;
  }

  /// Check if an article is unlocked
  bool isArticleUnlocked(String articleUrl) {
    if (_premiumRepository.isPremium) return true;

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
    _premiumStatusSub?.cancel();
    _premiumStatusSub = null;
    _retryTimer?.cancel();
    _rewardedAd?.dispose();
    _rewardedAd = null;
    _isAdLoaded = false;
    _isLoading = false;
  }
}
