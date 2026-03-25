import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../../domain/repositories/premium_repository.dart';
import 'ad_runtime_gate.dart';

// Service to manage interstitial ads with automatic premium bypass.
// Shows ads at strategic points to improve user engagement while
// respecting premium user status.
class InterstitialAdService {
  InterstitialAdService(this._premiumRepository) {
    _init();
  }

  InterstitialAd? _interstitialAd;
  bool _isAdLoaded = false;
  bool _isLoading = false;

  int _articleViewCount = 0;
  static const int _adFrequency = 4;
  static const int _maxAdsPerSession = 4;
  int _adsShownThisSession = 0;

  DateTime? _lastAdShownTime;
  static const Duration _cooldownDuration = Duration(minutes: 45);

  final PremiumRepository _premiumRepository;
  Timer? _retryTimer;
  StreamSubscription<bool>? _premiumStatusSub;

  void _init() {
    _premiumStatusSub = _premiumRepository.premiumStatusStream.listen((
      isPremium,
    ) {
      if (isPremium) {
        _retryTimer?.cancel();
        _interstitialAd?.dispose();
        _interstitialAd = null;
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

  int _retryAttempt = 0;
  static const int _maxRetryAttempts = 6;

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

    if (kDebugMode) {
      debugPrint('⏳ Loading Interstitial Ad...');
    }

    try {
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
            _retryAttempt = 0;

            _interstitialAd!.fullScreenContentCallback =
                FullScreenContentCallback(
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
    } catch (e) {
      _isLoading = false;
      _interstitialAd = null;
      _isAdLoaded = false;
      _scheduleRetry();
      if (kDebugMode) {
        debugPrint('❌ Interstitial ad load crashed: $e');
      }
    }
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
    final int delaySeconds = (2 * (1 << (_retryAttempt - 1))).clamp(2, 300);
    if (kDebugMode) {
      debugPrint(
        '🔄 Retrying ad load in $delaySeconds seconds (Attempt $_retryAttempt)',
      );
    }

    _retryTimer?.cancel();
    _retryTimer = Timer(Duration(seconds: delaySeconds), () {
      unawaited(_loadAd());
    });
  }

  void _onAdDismissed(InterstitialAd ad) {
    if (kDebugMode) {
      debugPrint('👋 Ad Dismissed');
    }
    ad.dispose();
    _interstitialAd = null;
    _isAdLoaded = false;
    _adsShownThisSession++;
    unawaited(_loadAd());
  }

  void _onAdFailedToShow(InterstitialAd ad, AdError error) {
    if (kDebugMode) {
      debugPrint('⚠️ Ad Failed to Show: ${error.message}');
    }
    ad.dispose();
    _interstitialAd = null;
    _isAdLoaded = false;
    unawaited(_loadAd());
  }

  String _resolveAdUnitId() {
    final String? prod = dotenv.env['INTERSTITIAL_AD_UNIT_ID'];
    final String? test = dotenv.env['INTERSTITIAL_AD_UNIT_ID_TEST'];

    if (prod != null && prod.isNotEmpty) return prod;
    if (test != null && test.isNotEmpty) return test;

    return 'ca-app-pub-3940256099942544/1033173712';
  }

  bool _shouldShowAd() {
    if (!(_premiumRepository.shouldShowAds)) {
      if (kDebugMode) debugPrint('🚫 Ad blocked: Premium/unknown entitlement');
      return false;
    }

    if (_adsShownThisSession >= _maxAdsPerSession) {
      if (kDebugMode) {
        debugPrint(
          '🚫 Ad blocked: Session ad cap reached ($_maxAdsPerSession)',
        );
      }
      return false;
    }

    if (!_isAdLoaded || _interstitialAd == null) return false;

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

  Future<void> onArticleViewed() async {
    if (!(_premiumRepository.shouldShowAds)) return;

    _articleViewCount++;
    if (!_isAdLoaded && !_isLoading) {
      unawaited(_loadAd());
    }

    if (kDebugMode) {
      debugPrint('📰 Article view count: $_articleViewCount');
    }

    if (_articleViewCount % _adFrequency == 0) {
      await showAd(reason: 'Article view threshold reached');
    }
  }

  Future<void> showAd({String reason = 'Manual trigger'}) async {
    if (!_shouldShowAd()) {
      if (kDebugMode) {
        debugPrint('🚫 Ad not shown: Conditions not met ($reason)');
      }
      if (!_isAdLoaded && !_isLoading) {
        unawaited(_loadAd());
      }
      return;
    }

    if (kDebugMode) {
      debugPrint('🎬 Showing ad: $reason');
    }

    _lastAdShownTime = DateTime.now();
    await _interstitialAd?.show();
  }

  Future<void> onManualRefresh() async {
    await showAd(reason: 'Manual refresh');
  }

  void dispose() {
    _premiumStatusSub?.cancel();
    _premiumStatusSub = null;
    _retryTimer?.cancel();
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _isAdLoaded = false;
    _isLoading = false;
  }

  void resetArticleCount() {
    _articleViewCount = 0;
    _adsShownThisSession = 0;
  }
}
