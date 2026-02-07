import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/subscription_providers.dart' show isPremiumProvider;

class BannerAdWidget extends ConsumerStatefulWidget {
  const BannerAdWidget({super.key});

  @override
  ConsumerState<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends ConsumerState<BannerAdWidget> {
  BannerAd? _bannerAd;
  AdSize? _adSize;
  bool _isAdLoaded = false;
  bool _isLoading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_bannerAd == null && !_isLoading) {
      _loadAd();
    }
  }
  Future<void> _loadAd() async {
    final bool isPremium = ref.read(isPremiumProvider);
    if (isPremium) return;

    _isLoading = true;

    final double width = MediaQuery.of(context).size.width;

    final AdSize? adaptiveSize =
        await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
          width.truncate(),
        );

    if (!mounted || adaptiveSize == null) {
      _isLoading = false;
      return;
    }

    _adSize = adaptiveSize;

    final String unitId = _resolveAdUnitId();

    final BannerAd banner = BannerAd(
      adUnitId: unitId,
      size: adaptiveSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) {
          if (mounted) {
            setState(() {
              _bannerAd = ad as BannerAd;
              _isAdLoaded = true;
              _isLoading = false;
            });
          }
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          ad.dispose();
          _bannerAd = null;
          _isAdLoaded = false;
          _isLoading = false;

          Future<void>.delayed(const Duration(seconds: 20), () {
            if (mounted) _loadAd();
          });
        },
      ),
    );

    await banner.load();
  }

   String _resolveAdUnitId() {
    final String? prod = dotenv.env['BANNER_AD_UNIT_ID'];
    final String? test = dotenv.env['BANNER_AD_UNIT_ID_TEST'];

    if (prod != null && prod.isNotEmpty) return prod;
    if (test != null && test.isNotEmpty) return test;

  
    return 'ca-app-pub-3940256099942544/6300978111';
  }

  
  @override
  void dispose() {
    _bannerAd?.dispose();
    _bannerAd = null;
    super.dispose();
  }

 
  @override
  Widget build(BuildContext context) {
    final bool isPremium = ref.watch(isPremiumProvider);

    if (isPremium || !_isAdLoaded || _bannerAd == null || _adSize == null) {
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
