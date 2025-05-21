import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import '../core/premium_service.dart';

class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({Key? key}) : super(key: key);

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;

  @override
  void initState() {
    super.initState();

    final unitId = dotenv.env['BANNER_AD_UNIT_ID']?.isNotEmpty == true
        ? dotenv.env['BANNER_AD_UNIT_ID']!
        : dotenv.env['BANNER_AD_UNIT_ID_TEST'] ??
            'ca-app-pub-3940256099942544/6300978111'; // fallback

    _bannerAd = BannerAd(
      adUnitId: unitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) {
            setState(() => _isAdLoaded = true);
          }
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

 @override
Widget build(BuildContext context) {
  final isPremium = context.watch<PremiumService>().isPremium;
  if (isPremium || !_isAdLoaded || _bannerAd == null) {
    return const SizedBox.shrink();
  }

  return Container(
    alignment: Alignment.center,
    width: _bannerAd!.size.width.toDouble(),
    height: _bannerAd!.size.height.toDouble(),
    child: AdWidget(ad: _bannerAd!),
  );
}

}
