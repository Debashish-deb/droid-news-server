import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/performance_config.dart';
import '../../../domain/repositories/premium_repository.dart';
import '../../../infrastructure/network/app_network_service.dart';
import '../ads/ad_unit_config.dart';
import '../ads/ad_runtime_gate.dart';

/// Service to manage rewarded ads for optional non-blocking placements.
class RewardedAdService {
  RewardedAdService(
    this._premiumRepository,
    this._prefs,
    this._networkService,
  ) {
    _init();
  }

  RewardedAd? _rewardedAd;
  bool _isAdLoaded = false;
  bool _isLoading = false;
  int _retryAttempt = 0;
  static const int _maxRetryAttempts = 6;
  Timer? _retryTimer;
  StreamSubscription<bool>? _premiumStatusSub;

  final PremiumRepository _premiumRepository;
  final SharedPreferences? _prefs;
  final AppNetworkService _networkService;

  /// Initialize the service
  void _init() {
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

  /// Load a rewarded ad
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
  String? _resolveAdUnitId() {
    return AdUnitConfig.resolve(
      placement: AdPlacement.rewarded,
      productionEnvKey: 'REWARDED_AD_UNIT_ID',
      testEnvKey: 'REWARDED_AD_UNIT_ID_TEST',
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

  /// Check if ad is ready to show
  bool get isAdReady => _isAdLoaded && _rewardedAd != null;

  Future<bool> showAd({
    required void Function(RewardItem reward) onUserEarnedReward,
    String reason = 'Manual trigger',
  }) async {
    if (!isAdReady || _shouldSuppressAdLoads()) {
      if (!_isLoading) {
        unawaited(_loadAd());
      }
      return false;
    }

    final ad = _rewardedAd;
    if (ad == null) {
      return false;
    }

    if (kDebugMode) {
      debugPrint('🎁 Showing rewarded ad: $reason');
    }

    _rewardedAd = null;
    _isAdLoaded = false;
    final rewardCompleter = Completer<bool>();
    var rewardEarned = false;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (RewardedAd ad) {
        ad.dispose();
        if (!rewardCompleter.isCompleted) {
          rewardCompleter.complete(rewardEarned);
        }
        unawaited(_loadAd());
      },
      onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
        if (kDebugMode) {
          debugPrint('❌ Rewarded ad failed to show: $error');
        }
        ad.dispose();
        if (!rewardCompleter.isCompleted) {
          rewardCompleter.complete(false);
        }
        unawaited(_loadAd());
      },
    );

    try {
      await ad.show(
        onUserEarnedReward: (_, reward) {
          rewardEarned = true;
          onUserEarnedReward(reward);
        },
      );
      return await rewardCompleter.future;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Rewarded ad show crashed: $e');
      }
      ad.dispose();
      if (!rewardCompleter.isCompleted) {
        rewardCompleter.complete(false);
      }
      unawaited(_loadAd());
      return await rewardCompleter.future;
    }
  }

  /// Manually load an ad (useful if user needs to unlock but ad isn't ready)
  Future<void> loadAdManually() async {
    if (!_isAdLoaded && !_isLoading) {
      await _loadAd();
    }
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
