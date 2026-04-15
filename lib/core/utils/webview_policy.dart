import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'url_identity.dart';

const Set<String> kConservativeWebViewHosts = <String>{
  'kalerkantho.com',
  'prothomalo.com',
  'thedailystar.net',
  'bdnews24.com',
  'dhakatribune.com',
  'banglatribune.com',
  'jugantor.com',
  'manabzamin.com',
  'tbsnews.net',
  'engadget.com',
  'techcrunch.com',
  'yahoo.com',
};

const Set<String> _kComparableHostPrefixes = <String>{
  'www',
  'm',
  'amp',
  'mobile',
  'edition',
};

const Set<String> _kConsentVendorHints = <String>{
  'onetrust',
  'didomi',
  'sourcepoint',
  'cookiebot',
  'trustarc',
  'quantcast',
  'sp_message',
  'privacy-mgmt',
};

const Set<String> _kConsentSignals = <String>{
  'cookie',
  'cookies',
  'consent',
  'gdpr',
  'ccpa',
  'cmp',
  'privacy',
  'preferences',
  'preference',
  'choices',
  'choice',
  'policy',
  'settings',
  'setting',
  'notice',
  'banner',
  'onetrust',
  'didomi',
  'sourcepoint',
  'cookiebot',
  'trustarc',
  'privacy-mgmt',
  'privacy manager',
  'privacy center',
  'manage cookies',
  'cookie settings',
  'your privacy choices',
};

const Set<String> _kStrongConsentSignals = <String>{
  'cookie',
  'cookies',
  'consent',
  'gdpr',
  'ccpa',
  'cmp',
  'onetrust',
  'didomi',
  'sourcepoint',
  'cookiebot',
  'trustarc',
  'privacy-mgmt',
  'manage cookies',
  'cookie settings',
  'your privacy choices',
};

const Set<String> _kSubscriptionGateSignals = <String>{
  'subscribe',
  'subscription',
  'sign in',
  'login',
  'log in',
  'register',
  'purchase',
  'checkout',
  'trial',
  'upgrade',
  'paywall',
  'membership',
};

const Set<String> _kHeavyThirdPartyHints = <String>{
  'doubleclick',
  'googlesyndication',
  'googleadservices',
  'googletagmanager',
  'google-analytics',
  'analytics',
  'tracking',
  'telemetry',
  'pixel',
  'beacon',
  'segment',
  'mixpanel',
  'hotjar',
  'clarity.ms',
  'fullstory',
  'newrelic',
  'sentry',
  'datadog',
  'taboola',
  'outbrain',
  'mgid',
  'teads',
  'adnxs',
  'adform',
  'pubmatic',
  'amazon-adsystem',
  'rubiconproject',
  'openx',
  'prebid',
  'bidswitch',
  '360yield',
  'fonts.googleapis.com',
  'fonts.gstatic.com',
  'use.typekit.net',
  'fontawesome',
  'youtube.com/embed',
  'youtu.be',
  'player.vimeo',
  'vimeo.com',
  'platform.twitter.com',
  'twitter.com/i/widgets',
  'x.com/i/widgets',
  'instagram.com/embed',
  'facebook.com/plugins',
  'connect.facebook.net',
  'redditmedia.com',
  'tiktok.com/embed',
  'jwplayer',
  'brightcove',
};

final RegExp _kDataSaverMediaUrlPattern = RegExp(
  r'\.(gif|webp|png|jpe?g|avif|bmp|ico|mp4|webm|mov|avi|m3u8|mp3|wav|ogg|flac)(\?.*)?$',
);
final RegExp _kHeavyThirdPartyAssetPattern = RegExp(
  r'\.(woff2?|ttf|otf|eot)(\?.*)?$',
);

String webViewHostCacheKey(Uri? uri) {
  final host = (uri?.host ?? '').toLowerCase();
  if (host.isEmpty) return '';
  return host
      .replaceFirst(RegExp(r'^www\.'), '')
      .replaceFirst(RegExp(r'^m\.'), '')
      .replaceFirst(RegExp(r'^amp\.'), '');
}

bool isConservativeWebViewHost(Uri? uri) {
  final host = webViewHostCacheKey(uri);
  if (host.isEmpty) return false;
  for (final conservativeHost in kConservativeWebViewHosts) {
    if (host == conservativeHost || host.endsWith('.$conservativeHost')) {
      return true;
    }
  }
  return false;
}

String comparableWebViewHost(Uri? uri) {
  final host = webViewHostCacheKey(uri);
  if (host.isEmpty) return '';

  final parts = host.split('.');
  while (parts.length > 2 && _kComparableHostPrefixes.contains(parts.first)) {
    parts.removeAt(0);
  }
  return parts.join('.');
}

bool isLikelySamePublisherHost(Uri? first, Uri? second) {
  final firstHost = comparableWebViewHost(first);
  final secondHost = comparableWebViewHost(second);
  if (firstHost.isEmpty || secondHost.isEmpty) return false;
  return firstHost == secondHost ||
      firstHost.endsWith('.$secondHost') ||
      secondHost.endsWith('.$firstHost');
}

bool isConsentManagementDetour({required Uri targetUri, Uri? articleUri}) {
  if (articleUri != null &&
      UrlIdentity.canonicalize(targetUri.toString()) ==
          UrlIdentity.canonicalize(articleUri.toString())) {
    return false;
  }

  final samePublisher = articleUri == null
      ? false
      : isLikelySamePublisherHost(articleUri, targetUri);
  final host = targetUri.host.toLowerCase();
  final vendorManagedHost = _containsAny(host, _kConsentVendorHints);
  if (!samePublisher && !vendorManagedHost) {
    return false;
  }

  final normalizedText = _normalizeDetourText(targetUri);
  if (_containsAny(normalizedText, _kSubscriptionGateSignals)) {
    return false;
  }

  var score = 0;
  if (_containsAny(host, _kConsentVendorHints)) {
    score += 2;
  }
  if (_containsAny(normalizedText, _kStrongConsentSignals)) {
    score += 2;
  }
  if (_containsAny(normalizedText, _kConsentSignals)) {
    score += 1;
  }

  return score >= 2;
}

bool shouldUseHybridCompositionForWebView({
  required bool isEmulator,
  required bool isLowEndDevice,
  required bool lowPowerMode,
  bool preferRuntimeHybridComposition = false,
}) {
  return isEmulator ||
      isLowEndDevice ||
      lowPowerMode ||
      preferRuntimeHybridComposition;
}

bool isRetryableTransientWebViewError(WebResourceError error) {
  if (error.type == WebResourceErrorType.RESET ||
      error.type == WebResourceErrorType.TIMEOUT ||
      error.type == WebResourceErrorType.NETWORK_CONNECTION_LOST ||
      error.type == WebResourceErrorType.NOT_CONNECTED_TO_INTERNET ||
      error.type == WebResourceErrorType.HOST_LOOKUP ||
      error.type == WebResourceErrorType.CONNECTION_ABORTED ||
      error.type == WebResourceErrorType.IO ||
      error.type == WebResourceErrorType.SECURE_CONNECTION_FAILED ||
      error.type == WebResourceErrorType.FAILED_SSL_HANDSHAKE) {
    return true;
  }

  final description = error.description.toLowerCase();
  return description.contains('net_error -101') ||
      description.contains('connection reset') ||
      description.contains('handshake failed') ||
      description.contains('timed out') ||
      description.contains('network connection was lost');
}

bool shouldRetryTransientPublisherLoad({
  required bool isPublisherMode,
  required bool isMainFrame,
  required bool hasRetryBudget,
  required WebResourceError error,
}) {
  return isPublisherMode &&
      isMainFrame &&
      hasRetryBudget &&
      isRetryableTransientWebViewError(error);
}

bool shouldBlockHeavyThirdPartySubresource({
  required Uri? pageUri,
  required Uri? requestUri,
  required bool adBlockingEnabled,
  required bool dataSaver,
  required bool lightweightMode,
}) {
  if (requestUri == null) return false;
  final lowerUrl = requestUri.toString().toLowerCase();
  if (lowerUrl.isEmpty ||
      lowerUrl.startsWith('about:') ||
      lowerUrl.startsWith('blob:') ||
      lowerUrl.startsWith('data:')) {
    return false;
  }

  if (adBlockingEnabled && _containsAny(lowerUrl, _kHeavyThirdPartyHints)) {
    return true;
  }

  if (dataSaver && _kDataSaverMediaUrlPattern.hasMatch(lowerUrl)) {
    return true;
  }

  if (!lightweightMode) return false;

  final samePublisher =
      pageUri != null && isLikelySamePublisherHost(pageUri, requestUri);
  if (samePublisher) {
    return false;
  }

  return _containsAny(lowerUrl, _kHeavyThirdPartyHints) ||
      _kHeavyThirdPartyAssetPattern.hasMatch(lowerUrl);
}

bool _containsAny(String text, Set<String> hints) {
  for (final hint in hints) {
    if (text.contains(hint)) {
      return true;
    }
  }
  return false;
}

String _normalizeDetourText(Uri uri) {
  final buffer = StringBuffer()
    ..write(uri.host.toLowerCase())
    ..write(' ')
    ..write(uri.path.toLowerCase().replaceAll(RegExp(r'[_\-]+'), ' '))
    ..write(' ')
    ..write(uri.query.toLowerCase().replaceAll(RegExp(r'[_\-]+'), ' '))
    ..write(' ')
    ..write(uri.fragment.toLowerCase().replaceAll(RegExp(r'[_\-]+'), ' '));
  return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}
