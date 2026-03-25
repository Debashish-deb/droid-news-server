// ignore_for_file: avoid_classes_with_only_static_members

enum UrlSafetyDisposition { allowInApp, openExternal, reject }

class UrlSafetyDecision {
  const UrlSafetyDecision({required this.disposition, this.uri, this.reason});

  final UrlSafetyDisposition disposition;
  final Uri? uri;
  final String? reason;
}

class UrlSafetyPolicy {
  static const Set<String> _blockedSchemes = <String>{
    'content',
    'data',
    'file',
    'intent',
    'javascript',
  };

  static const Set<String> _externalSchemes = <String>{
    'itms-apps',
    'mailto',
    'market',
    'sms',
    'tel',
  };

  static const Set<String> translatorHosts = <String>{
    'translate.google.com',
    'www.microsofttranslator.com',
    'www.deepl.com',
  };

  static UrlSafetyDecision evaluate(String rawUrl) {
    final trimmed = rawUrl.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme) {
      return const UrlSafetyDecision(
        disposition: UrlSafetyDisposition.reject,
        reason: 'malformed_url',
      );
    }
    final scheme = uri.scheme.toLowerCase();
    if (_externalSchemes.contains(scheme)) {
      return UrlSafetyDecision(
        disposition: UrlSafetyDisposition.openExternal,
        uri: uri,
        reason: 'external_scheme',
      );
    }
    if (uri.host.trim().isEmpty) {
      return const UrlSafetyDecision(
        disposition: UrlSafetyDisposition.reject,
        reason: 'malformed_url',
      );
    }
    return evaluateUri(uri);
  }

  static UrlSafetyDecision evaluateUri(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    if (_blockedSchemes.contains(scheme)) {
      return UrlSafetyDecision(
        disposition: UrlSafetyDisposition.reject,
        uri: uri,
        reason: 'blocked_scheme',
      );
    }
    if (_externalSchemes.contains(scheme)) {
      return UrlSafetyDecision(
        disposition: UrlSafetyDisposition.openExternal,
        uri: uri,
        reason: 'external_scheme',
      );
    }
    if (scheme != 'https') {
      return UrlSafetyDecision(
        disposition: UrlSafetyDisposition.reject,
        uri: uri,
        reason: 'non_https',
      );
    }
    return UrlSafetyDecision(
      disposition: UrlSafetyDisposition.allowInApp,
      uri: uri,
    );
  }
}
