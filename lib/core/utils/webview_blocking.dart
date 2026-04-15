import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Legacy pattern retained for backward-compatible tests and callers.
const String kAdUrlFilterPattern =
    r'.*(ads|doubleclick|googlesyndication|adservice|googleadservices|taboola|outbrain|adsystem|rubiconproject|openx|bilsyndication|safeframe|pubmatic|vidoomy|3lift|bidswitch|360yield|adform).*';

/// Strict webview ad/tracker filters for stable hosts.
const List<String> _kStrictAdBlockingUrlFilters = <String>[
  r'.*(doubleclick|googlesyndication|googleadservices|googletagservices|adservice|adnxs|adform|adsystem|adroll|moatads|scorecardresearch|quantserve|rubiconproject|openx|casalemedia|criteo|pubmatic|taboola|outbrain|teads|mgid|zemanta|smartadserver|advertising|adserver|amazon-adsystem|onetag|adsafeprotected|adtrafficquality|media\.net|bilsyndication|safeframe|mraid|vidoomy|3lift|bidswitch|360yield|prebid|hbopenbid|[?&](adunit|ads|ad_tag|ad_id)=|utm_source=taboola).*',
  r'.*(analytics|tracking|pixel|beacon|segment|mixpanel|hotjar|facebook\.com/tr|googletagmanager|google-analytics|stats|telemetry|clarity\.ms|fullstory|newrelic|sentry|datadog).*',
];

/// Safer subset for conservative hosts (keeps article assets intact).
const List<String> _kConservativeAdBlockingUrlFilters = <String>[
  r'.*(doubleclick|googlesyndication|googleadservices|googletagservices|adservice|adnxs|adform|rubiconproject|openx|casalemedia|criteo|pubmatic|taboola|outbrain|teads|mgid|advertising|adserver|amazon-adsystem|media\.net|bilsyndication|safeframe|vidoomy|3lift|bidswitch|360yield).*',
];

/// Exported for reuse by runtime JS injection in WebView screen.
const String kWebViewAdCssSelectors = '''
.ad, .ads, .advertisement, .advert, .ad-container, .ad-wrapper, .ad-slot,
.ad-banner, .adunit, .adbox, .adsbox, .adsense, .sponsored, .sponsor,
.promo, .promoted, .outbrain, .taboola, .teads, .mgid, .google-auto-placed,
[class*="sponsored"], [id*="sponsored"], [class*="recommend"], [id*="recommend"],
[class*="related"], [id*="related"],
[class*="cookie"], [id*="cookie"], [class*="consent"], [id*="consent"],
[class*="cmp"], [id*="cmp"], [class*="onetrust"], [id*="onetrust"],
[class*="didomi"], [id*="didomi"], [id*="sp_message_container"], [class*="sp_message"],
[id*="ad-"], [id^="ad_"], [id*="ads"], [id*="sponsored"], [id*="promo"],
[class*="ad-"], [class^="ad_"], [class*=" ads"], [class*="sponsor"], [class*="promo"],
ins.adsbygoogle, amp-ad, amp-auto-ads,
iframe[src*="doubleclick"], iframe[src*="googlesyndication"], iframe[src*="taboola"],
iframe[src*="outbrain"], iframe[src*="mgid"], iframe[src*="ads"], iframe[id*="ad"],
iframe[src*="safeframe"], iframe[src*="bilsyndication"], script[src*="bilsyndication"],
iframe[src*="vidoomy"], script[src*="vidoomy"], iframe[src*="pubmatic"], script[src*="pubmatic"],
iframe[src*="3lift"], script[src*="3lift"], iframe[src*="bidswitch"], script[src*="bidswitch"],
iframe[src*="360yield"], script[src*="360yield"], iframe[src*="adform"], script[src*="adform"],
[id*="google_ads_iframe"], [class*="adsbygoogle"],
[data-ad], [data-ad-unit], [data-ad-slot], [data-testid*="ad"], [data-testid*="sponsor"],
[aria-label*="advert"], [aria-label*="sponsored"], [class*="sponsor"], [id*="sponsor"]
''';

const List<String> _kDataSaverUrlFilters = <String>[
  r'.*\.(mp4|webm|mov|avi|m3u8|mp3|wav|ogg|flac)(\?.*)?$',
  r'.*(/video/|/videos/|/player/|/embed/|/amp-video/).*',
  r'.*(doubleclick|googlesyndication|googleadservices|taboola|outbrain|mgid|teads|adservice|adnxs|adform|bilsyndication|safeframe|pubmatic|vidoomy|3lift|bidswitch|360yield).*',
];

const List<String> _kLightweightModeUrlFilters = <String>[
  r'.*(fonts\.googleapis\.com|fonts\.gstatic\.com|use\.typekit\.net|fontawesome).*',
  r'.*(platform\.twitter\.com|twitter\.com/i/widgets|x\.com/i/widgets|instagram\.com/embed|facebook\.com/plugins|connect\.facebook\.net|youtube\.com/embed|youtu\.be|player\.vimeo\.com|jwplayer|brightcove|redditmedia\.com|tiktok\.com/embed).*',
  r'.*(analytics|tracking|pixel|beacon|telemetry|segment|mixpanel|hotjar|clarity\.ms|fullstory|newrelic|sentry|datadog|googletagmanager|google-analytics).*',
  r'.*\.(woff2?|ttf|otf|eot)(\?.*)?$',
];

ContentBlocker _adBlockingUrlBlocker(String urlFilter) {
  return ContentBlocker(
    trigger: ContentBlockerTrigger(urlFilter: urlFilter),
    action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
  );
}

/// Builds content blockers for in-app webviews.
///
/// Publisher/article ad blocking applies to every tier.
/// App-owned AdMob placements are gated separately outside the webview.
List<ContentBlocker> buildWebViewContentBlockers({
  required bool enableAdBlocking,
  bool conservative = false,
  bool dataSaver = false,
  bool lightweightMode = false,
}) {
  final blockers = <ContentBlocker>[];

  if (enableAdBlocking) {
    final filters = conservative
        ? _kConservativeAdBlockingUrlFilters
        : _kStrictAdBlockingUrlFilters;
    for (final filter in filters) {
      blockers.add(_adBlockingUrlBlocker(filter));
    }

    // DOM-level suppression (CSS_DISPLAY_NONE) is safe even in conservative mode.
    blockers.add(
      ContentBlocker(
        trigger: ContentBlockerTrigger(urlFilter: r'.*'),
        action: ContentBlockerAction(
          type: ContentBlockerActionType.CSS_DISPLAY_NONE,
          selector: kWebViewAdCssSelectors,
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
          selector:
              'video,audio,iframe[src*="player"],iframe[src*="embed"],'
              'iframe[src*="youtube"],iframe[src*="facebook"],'
              'iframe[src*="instagram"],iframe[src*="twitter"],'
              '[class*="video-player"],[id*="video-player"]',
        ),
      ),
    );
  }

  if (lightweightMode) {
    for (final filter in _kLightweightModeUrlFilters) {
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
          selector:
              'iframe[src*="youtube"],iframe[src*="twitter"],'
              'iframe[src*="instagram"],iframe[src*="facebook"],'
              'iframe[src*="tiktok"],iframe[src*="vimeo"],'
              '[class*="social-embed"],[class*="embed"],'
              '[class*="share-widget"],[id*="share-widget"]',
        ),
      ),
    );
  }

  return blockers;
}
