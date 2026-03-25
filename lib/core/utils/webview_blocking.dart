import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Legacy pattern retained for backward-compatible tests and callers.
const String kAdUrlFilterPattern =
    r'.*(ads|doubleclick|googlesyndication|adservice|googleadservices|taboola|outbrain|adsystem|rubiconproject|openx).*';

/// Strict premium network filters for stable hosts.
const List<String> _kPremiumStrictAdUrlFilters = <String>[
  r'.*(doubleclick|googlesyndication|googleadservices|adservice|adnxs|adform|adsystem|adroll|moatads|scorecardresearch|quantserve|rubiconproject|openx|casalemedia|criteo|pubmatic|taboola|outbrain|teads|mgid|zemanta|smartadserver|advertising|adserver|amazon-adsystem|onetag|adsafeprotected|adtrafficquality|media\.net|[?&](adunit|ads|ad_tag|ad_id)=|utm_source=taboola).*',
  r'.*(analytics|tracking|pixel|beacon|segment|mixpanel|hotjar|facebook\.com/tr|googletagmanager|google-analytics|stats|telemetry|clarity\.ms|fullstory|newrelic|sentry|datadog).*',
  r'.*(onetrust|cookiebot|didomi|privacy-mgmt|quantcast|trustarc|consensu|sourcepoint|sp_message|cookie-notice|cookiebanner|gdpr).*',
  r'.*(popup|popunder|interstitial|sponsored|promo|newsletter|subscribe|cookie|consent).*',
];

/// Safer subset for conservative hosts (keeps article assets intact).
const List<String> _kPremiumConservativeAdUrlFilters = <String>[
  r'.*(doubleclick|googlesyndication|googleadservices|adservice|adnxs|adform|rubiconproject|openx|casalemedia|criteo|pubmatic|taboola|outbrain|teads|mgid|advertising|adserver|amazon-adsystem|media\.net).*',
  r'.*(sp_message|onetrust|cookiebot|didomi|cookiebanner|gdpr).*',
];

/// Exported for reuse by runtime JS injection in WebView screen.
const String kPremiumAdCssSelectors = '''
.ad, .ads, .advertisement, .advert, .ad-container, .ad-wrapper, .ad-slot,
.ad-banner, .adunit, .adbox, .adsbox, .adsense, .sponsored, .sponsor,
.promo, .promoted, .outbrain, .taboola, .teads, .mgid, .google-auto-placed,
[class*="sponsored"], [id*="sponsored"], [class*="recommend"], [id*="recommend"],
[class*="related"], [id*="related"], [class*="newsletter"], [id*="newsletter"],
[class*="cookie"], [id*="cookie"], [class*="consent"], [id*="consent"],
[class*="cmp"], [id*="cmp"], [class*="onetrust"], [id*="onetrust"],
[class*="didomi"], [id*="didomi"], [id*="sp_message_container"], [class*="sp_message"],
[id*="ad-"], [id^="ad_"], [id*="ads"], [id*="sponsored"], [id*="promo"],
[class*="ad-"], [class^="ad_"], [class*=" ads"], [class*="sponsor"], [class*="promo"],
ins.adsbygoogle, amp-ad, amp-auto-ads,
iframe[src*="doubleclick"], iframe[src*="googlesyndication"], iframe[src*="taboola"],
iframe[src*="outbrain"], iframe[src*="mgid"], iframe[src*="ads"], iframe[id*="ad"],
[data-ad], [data-ad-unit], [data-ad-slot], [data-testid*="ad"], [data-testid*="sponsor"],
[aria-label*="advert"], [aria-label*="sponsored"], [class*="sponsor"], [id*="sponsor"]
''';

const List<String> _kDataSaverUrlFilters = <String>[
  r'.*\.(gif|webp|png|jpe?g|avif|bmp|ico|mp4|webm|mov|avi|m3u8|mp3|wav|ogg|flac)(\?.*)?$',
  r'.*(/video/|/videos/|/player/|/embed/|/amp-video/).*',
  r'.*(doubleclick|googlesyndication|googleadservices|taboola|outbrain|mgid|teads|adservice|adnxs|adform).*',
];

ContentBlocker _premiumUrlBlocker(String urlFilter) {
  return ContentBlocker(
    trigger: ContentBlockerTrigger(urlFilter: urlFilter),
    action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
  );
}

/// Builds content blockers for in-app webviews.
///
/// Free tier intentionally keeps aggressive ad blocking disabled.
/// Premium tier enables layered network + DOM element suppression.
List<ContentBlocker> buildWebViewContentBlockers({
  required bool isPremium,
  bool conservative = false,
  bool dataSaver = false,
}) {
  final blockers = <ContentBlocker>[];

  if (isPremium) {
    final filters = conservative
        ? _kPremiumConservativeAdUrlFilters
        : _kPremiumStrictAdUrlFilters;
    for (final filter in filters) {
      blockers.add(_premiumUrlBlocker(filter));
    }

    // DOM-level suppression (CSS_DISPLAY_NONE) is safe even in conservative mode.
    blockers.add(
      ContentBlocker(
        trigger: ContentBlockerTrigger(urlFilter: r'.*'),
        action: ContentBlockerAction(
          type: ContentBlockerActionType.CSS_DISPLAY_NONE,
          selector: kPremiumAdCssSelectors,
        ),
      ),
    );
  }

  if (dataSaver) {
    for (final filter in _kDataSaverUrlFilters) {
      blockers.add(
        ContentBlocker(
          trigger: ContentBlockerTrigger(urlFilter: filter),
          action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
        ),
      );
    }
    blockers.add(
      ContentBlocker(
        trigger: ContentBlockerTrigger(urlFilter: r'.*'),
        action: ContentBlockerAction(
          type: ContentBlockerActionType.CSS_DISPLAY_NONE,
          selector: 'video,audio,iframe,[class*="video"],[id*="video"],picture',
        ),
      ),
    );
  }

  return blockers;
}
