import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/performance_config.dart';
import '../../../infrastructure/network/app_network_service.dart';
import '../../../domain/repositories/premium_repository.dart';
import 'ad_unit_config.dart';
import 'ad_runtime_gate.dart';

// Service to manage interstitial ads with automatic premium bypass.
// Shows ads at strategic points to improve user engagement while
// respecting premium user status.
class InterstitialAdService with WidgetsBindingObserver {
  InterstitialAdService(
    this._premiumRepository, {
    required AppNetworkService networkService,
    required SharedPreferences? prefs,
  }) : _networkService = networkService,
       _prefs = prefs {
    _init();
  }

  InterstitialAd? _interstitialAd;
  bool _isAdLoaded = false;
  bool _isLoading = false;

  int _articleViewCount = 0;
  static const int _adFrequency = 4;
  static const int _maxAdsPerSession = 3;
  static const String _articleCountPrefsKey = 'interstitial_article_count';
  static const String _articleCountDayPrefsKey =
      'interstitial_article_count_day';
  static const Duration _sessionResetThreshold = Duration(minutes: 30);
  int _adsShownThisSession = 0;
  bool _hasPendingAdToShow = false;

  DateTime? _lastAdShownTime;
  DateTime? _backgroundedAt;
  static const Duration _cooldownDuration = Duration(minutes: 4);

  final PremiumRepository _premiumRepository;
  final AppNetworkService _networkService;
  final SharedPreferences? _prefs;
  Timer? _retryTimer;
  StreamSubscription<bool>? _premiumStatusSub;

  void _init() {
    WidgetsBinding.instance.addObserver(this);
    _restoreArticleViewCount();
    _premiumStatusSub = _premiumRepository.premiumStatusStream.listen((
      isPremium,
    ) {
      if (isPremium) {
        _retryTimer?.cancel();
        _interstitialAd?.dispose();
        _interstitialAd = null;
        _isAdLoaded = false;
        _isLoading = false;
        _hasPendingAdToShow = false;
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
    if (_isAdLoaded || _isLoading || _shouldSuppressAdLoads()) return;

    _isLoading = true;

    final sdkReady = await AdRuntimeGate.ensureInitializedIfEligible(
      _premiumRepository,
    );
    if (!sdkReady || _shouldSuppressAdLoads()) {
      _isLoading = false;
      return;
    }

    final String? adUnitId = _resolveAdUnitId();
    if (adUnitId == null) {
      _isLoading = false;
      return;
    }

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
                  onAdShowedFullScreenContent: _onAdShown,
                  onAdDismissedFullScreenContent: _onAdDismissed,
                  onAdFailedToShowFullScreenContent: _onAdFailedToShow,
                );

            if (_hasPendingAdToShow) {
              unawaited(_tryShowPendingAd());
            }
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

  void _onAdShown(InterstitialAd ad) {
    _lastAdShownTime = DateTime.now();
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

  String? _resolveAdUnitId() {
    return AdUnitConfig.resolve(
      placement: AdPlacement.interstitial,
      productionEnvKey: 'INTERSTITIAL_AD_UNIT_ID',
      testEnvKey: 'INTERSTITIAL_AD_UNIT_ID_TEST',
    );
  }

  bool _shouldSuppressAdLoads() {
    if (!AdRuntimeGate.isAdSdkAllowed) {
      return true;
    }
    if (!_premiumRepository.shouldShowAds) {
      return true;
    }
    if (_prefs?.getBool('data_saver') == true) {
      return true;
    }
    if (_networkService.currentQuality == NetworkQuality.offline ||
        _networkService.currentQuality == NetworkQuality.poor) {
      return true;
    }
    if (_networkService.performanceTier == DevicePerformanceTier.lowEnd) {
      return true;
    }
    return false;
  }

  bool _shouldShowAd() {
    if (_shouldSuppressAdLoads()) {
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
    if (_shouldSuppressAdLoads()) return;

    _restoreArticleViewCount();
    _articleViewCount++;
    _persistArticleViewCount();
    if (!_isAdLoaded && !_isLoading) {
      unawaited(_loadAd());
    }

    if (kDebugMode) {
      debugPrint('📰 Article view count: $_articleViewCount');
    }

    if (_articleViewCount % _adFrequency == 0) {
      if (_isAdLoaded && _interstitialAd != null) {
        _hasPendingAdToShow = false;
        await showAd(reason: 'Article view threshold reached');
      } else {
        _hasPendingAdToShow = true;
        if (!_isLoading) {
          unawaited(_loadAd());
        }
      }
    }
  }

  Future<bool> showAd({String reason = 'Manual trigger'}) async {
    if (!_shouldShowAd()) {
      if (kDebugMode) {
        debugPrint('🚫 Ad not shown: Conditions not met ($reason)');
      }
      if (!_isAdLoaded && !_isLoading) {
        unawaited(_loadAd());
      }
      return false;
    }

    final ad = _interstitialAd;
    if (ad == null) {
      if (!_isLoading) {
        unawaited(_loadAd());
      }
      return false;
    }

    if (kDebugMode) {
      debugPrint('🎬 Showing ad: $reason');
    }

    _interstitialAd = null;
    _isAdLoaded = false;

    try {
      await ad.show();
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Interstitial ad show failed: $e');
      }
      ad.dispose();
      _isAdLoaded = false;
      unawaited(_loadAd());
      return false;
    }
  }

  Future<void> onManualRefresh() async {
    await showAd(reason: 'Manual refresh');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _backgroundedAt = DateTime.now();
      return;
    }

    if (state == AppLifecycleState.resumed) {
      final backgroundedAt = _backgroundedAt;
      if (backgroundedAt != null &&
          DateTime.now().difference(backgroundedAt) >= _sessionResetThreshold) {
        if (kDebugMode) {
          debugPrint(
            '🔄 App resumed after extended background; resetting session ad cap',
          );
        }
        _adsShownThisSession = 0;
      }
      _backgroundedAt = null;
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
    _hasPendingAdToShow = false;
    _persistArticleViewCount();
  }

  Future<void> _tryShowPendingAd() async {
    if (!_hasPendingAdToShow) {
      return;
    }

    final shown = await showAd(reason: 'Pending threshold fulfilled');
    if (shown) {
      _hasPendingAdToShow = false;
    }
  }

  void _restoreArticleViewCount() {
    final prefs = _prefs;
    if (prefs == null) {
      return;
    }

    final today = _todayKey();
    final storedDay = prefs.getString(_articleCountDayPrefsKey);
    if (storedDay != today) {
      _articleViewCount = 0;
      unawaited(prefs.setString(_articleCountDayPrefsKey, today));
      unawaited(prefs.remove(_articleCountPrefsKey));
      return;
    }

    _articleViewCount = prefs.getInt(_articleCountPrefsKey) ?? 0;
  }

  void _persistArticleViewCount() {
    final prefs = _prefs;
    if (prefs == null) {
      return;
    }

    final today = _todayKey();
    unawaited(prefs.setString(_articleCountDayPrefsKey, today));
    unawaited(prefs.setInt(_articleCountPrefsKey, _articleViewCount));
  }

  String _todayKey() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }
}
