import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../core/config/performance_config.dart';
import '../../core/di/providers.dart' show premiumRepositoryProvider;
import '../../infrastructure/services/ads/ad_runtime_gate.dart';
import '../../infrastructure/network/app_network_service.dart';
import '../providers/app_settings_providers.dart';
import '../providers/network_providers.dart';
import '../providers/performance_providers.dart';
import '../providers/premium_providers.dart' show shouldShowAdsProvider;

class BannerAdWidget extends ConsumerStatefulWidget {
  const BannerAdWidget({super.key});

  @override
  ConsumerState<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends ConsumerState<BannerAdWidget>
    with WidgetsBindingObserver {
  BannerAd? _bannerAd;
  AdSize? _adSize;
  bool _isAdLoaded = false;
  bool _isLoading = false;
  int _retryAttempt = 0;
  Timer? _retryTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _evaluateAndMaybeLoad();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.resumed:
        _evaluateAndMaybeLoad();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _retryTimer?.cancel();
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }

  bool _shouldSuppressAds() {
    final shouldShowAds = ref.read(shouldShowAdsProvider);
    final dataSaver = ref.read(dataSaverProvider);
    final network = ref.read(networkQualityProvider);
    final tier = ref.read(performanceTierProvider);

    if (!shouldShowAds) return true;
    if (dataSaver) return true;
    if (network == NetworkQuality.offline || network == NetworkQuality.poor) {
      return true;
    }
    if (tier == DevicePerformanceTier.lowEnd) return true;
    return false;
  }

  void _disposeBanner() {
    _bannerAd?.dispose();
    _bannerAd = null;
    _adSize = null;
    _isAdLoaded = false;
    _isLoading = false;
  }

  void _evaluateAndMaybeLoad() {
    if (_shouldSuppressAds()) {
      _retryTimer?.cancel();
      _disposeBanner();
      return;
    }
    if (_bannerAd == null && !_isLoading) {
      unawaited(_loadAd());
    }
  }

  Future<void> _loadAd() async {
    if (!mounted || _isLoading || _shouldSuppressAds()) return;

    _isLoading = true;

    final premiumRepo = ref.read(premiumRepositoryProvider);
    final sdkReady = await AdRuntimeGate.ensureInitializedIfEligible(
      premiumRepo,
      refreshTimeout: const Duration(seconds: 2),
    );
    if (!mounted || !sdkReady || _shouldSuppressAds()) {
      _isLoading = false;
      return;
    }

    final width = MediaQuery.of(context).size.width;

    final adaptiveSize =
        await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
          width.truncate(),
        );

    if (!mounted || adaptiveSize == null || _shouldSuppressAds()) {
      _isLoading = false;
      return;
    }

    _adSize = adaptiveSize;
    final unitId = _resolveAdUnitId();

    final banner = BannerAd(
      adUnitId: unitId,
      size: adaptiveSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted || _shouldSuppressAds()) {
            ad.dispose();
            _isLoading = false;
            return;
          }
          setState(() {
            _bannerAd = ad as BannerAd;
            _isAdLoaded = true;
            _isLoading = false;
            _retryAttempt = 0;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _bannerAd = null;
          _isAdLoaded = false;
          _isLoading = false;
          if (!mounted || _shouldSuppressAds()) return;

          _retryAttempt = math.min(_retryAttempt + 1, 6);
          final retrySeconds = math.min(8 * (1 << (_retryAttempt - 1)), 180);
          _retryTimer?.cancel();
          _retryTimer = Timer(Duration(seconds: retrySeconds), () {
            if (mounted) {
              unawaited(_loadAd());
            }
          });
        },
      ),
    );

    await banner.load();
  }

  String _resolveAdUnitId() {
    final prod = dotenv.env['BANNER_AD_UNIT_ID'];
    final test = dotenv.env['BANNER_AD_UNIT_ID_TEST'];

    if (prod != null && prod.isNotEmpty) return prod;
    if (test != null && test.isNotEmpty) return test;
    return 'ca-app-pub-3940256099942544/6300978111';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _retryTimer?.cancel();
    _disposeBanner();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(shouldShowAdsProvider, (_, _) => _evaluateAndMaybeLoad());
    ref.listen(dataSaverProvider, (_, _) => _evaluateAndMaybeLoad());
    ref.listen(networkQualityProvider, (_, _) => _evaluateAndMaybeLoad());
    ref.listen(performanceTierProvider, (_, _) => _evaluateAndMaybeLoad());

    final shouldShowAds = ref.watch(shouldShowAdsProvider);
    final dataSaver = ref.watch(dataSaverProvider);
    final network = ref.watch(networkQualityProvider);
    final tier = ref.watch(performanceTierProvider);

    final suppressAds =
        !shouldShowAds ||
        dataSaver ||
        network == NetworkQuality.offline ||
        network == NetworkQuality.poor ||
        tier == DevicePerformanceTier.lowEnd;

    if (suppressAds || !_isAdLoaded || _bannerAd == null || _adSize == null) {
      if (suppressAds) {
        _retryTimer?.cancel();
        _disposeBanner();
      }
      return const SizedBox.shrink();
    }

    return SafeArea(
      top: false,
      child: Align(
        child: SizedBox(
          width: _adSize!.width.toDouble(),
          height: _adSize!.height.toDouble(),
          child: ClipRect(child: AdWidget(ad: _bannerAd!)),
        ),
      ),
    );
  }
}
