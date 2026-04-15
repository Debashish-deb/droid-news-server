import 'dart:async';
import '../../core/theme/theme_skeleton.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../core/config/performance_config.dart';
import '../../core/di/providers.dart' show premiumRepositoryProvider;
import '../../infrastructure/services/ads/ad_unit_config.dart';
import '../../infrastructure/services/ads/ad_runtime_gate.dart';
import '../../infrastructure/network/app_network_service.dart';
import '../providers/app_settings_providers.dart';
import '../providers/network_providers.dart';
import '../providers/performance_providers.dart';
import '../providers/premium_providers.dart'
    show isPremiumStateProvider, shouldShowAdsProvider;

class BannerAdWidget extends ConsumerStatefulWidget {
  const BannerAdWidget({
    super.key,
    this.framed = false,
    this.margin = EdgeInsets.zero,
    this.framePadding = ThemeSkeleton.insetsV8,
  });

  final bool framed;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry framePadding;

  @override
  ConsumerState<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends ConsumerState<BannerAdWidget>
    with WidgetsBindingObserver {
  static const Duration _initialLoadDelay = Duration(milliseconds: 450);
  static const double _fallbackReservedHeight = 56;

  BannerAd? _bannerAd;
  AdSize? _adSize;
  bool _isAdLoaded = false;
  bool _isLoading = false;
  int _retryAttempt = 0;
  Timer? _retryTimer;
  Timer? _initialLoadTimer;
  ProviderSubscription<bool>? _shouldShowAdsSubscription;
  ProviderSubscription<bool>? _dataSaverSubscription;
  ProviderSubscription<NetworkQuality>? _networkSubscription;
  ProviderSubscription<DevicePerformanceTier>? _performanceSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _shouldShowAdsSubscription ??= ref.listenManual<bool>(
      shouldShowAdsProvider,
      (_, _) => _scheduleEvaluateAndMaybeLoad(delay: Duration.zero),
    );
    _dataSaverSubscription ??= ref.listenManual<bool>(
      dataSaverProvider,
      (_, _) => _scheduleEvaluateAndMaybeLoad(delay: Duration.zero),
    );
    _networkSubscription ??= ref.listenManual<NetworkQuality>(
      networkQualityProvider,
      (_, _) => _scheduleEvaluateAndMaybeLoad(delay: Duration.zero),
    );
    _performanceSubscription ??= ref.listenManual<DevicePerformanceTier>(
      performanceTierProvider,
      (_, _) => _scheduleEvaluateAndMaybeLoad(delay: Duration.zero),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scheduleEvaluateAndMaybeLoad();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bannerAd == null && !_isLoading && _initialLoadTimer == null) {
      _scheduleEvaluateAndMaybeLoad();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.resumed:
        _scheduleEvaluateAndMaybeLoad(delay: Duration.zero);
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

    if (!AdRuntimeGate.isAdSdkAllowed) return true;
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

  void _scheduleEvaluateAndMaybeLoad({Duration delay = _initialLoadDelay}) {
    _initialLoadTimer?.cancel();
    _initialLoadTimer = Timer(delay, () {
      if (mounted) {
        _evaluateAndMaybeLoad();
      }
    });
  }

  void _evaluateAndMaybeLoad() {
    _initialLoadTimer?.cancel();
    _initialLoadTimer = null;
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
    if (unitId == null) {
      _isLoading = false;
      return;
    }

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

          if (_retryAttempt >= 6) return;
          _retryAttempt++;
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

  String? _resolveAdUnitId() {
    return AdUnitConfig.resolve(
      placement: AdPlacement.banner,
      productionEnvKey: 'BANNER_AD_UNIT_ID',
      testEnvKey: 'BANNER_AD_UNIT_ID_TEST',
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _shouldShowAdsSubscription?.close();
    _dataSaverSubscription?.close();
    _networkSubscription?.close();
    _performanceSubscription?.close();
    _initialLoadTimer?.cancel();
    _retryTimer?.cancel();
    _disposeBanner();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = ref.watch(isPremiumStateProvider);
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
    final hasConfiguredUnitId = _resolveAdUnitId() != null;
    final shouldRenderReservedSlot =
        widget.framed && hasConfiguredUnitId && !isPremium;

    if (isPremium || !hasConfiguredUnitId) {
      if (suppressAds) {
        _retryTimer?.cancel();
        _disposeBanner();
      }
      return const SizedBox.shrink();
    }

    if (!_isAdLoaded || _bannerAd == null || _adSize == null) {
      if (!shouldRenderReservedSlot) {
        return const SizedBox.shrink();
      }
      return _buildFramedContainer(
        context,
        SizedBox(
          height: _adSize?.height.toDouble() ?? _fallbackReservedHeight,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isLoading) ...[
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.8,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: ThemeSkeleton.size10),
                ],
                Text(
                  'Sponsored',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.72),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final Widget content = SafeArea(
      top: false,
      child: Align(
        child: SizedBox(
          width: _adSize!.width.toDouble(),
          height: _adSize!.height.toDouble(),
          child: ClipRect(child: AdWidget(ad: _bannerAd!)),
        ),
      ),
    );

    if (!widget.framed) {
      return content;
    }

    return _buildFramedContainer(context, content);
  }

  Widget _buildFramedContainer(BuildContext context, Widget child) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: widget.margin,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.brightness == Brightness.dark
              ? scheme.surface.withValues(alpha: 0.22)
              : scheme.surface,
          borderRadius: ThemeSkeleton.shared.circular(18),
          border: Border.all(
            color: scheme.outline.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.24 : 0.16,
            ),
          ),
        ),
        child: Padding(padding: widget.framePadding, child: child),
      ),
    );
  }
}
