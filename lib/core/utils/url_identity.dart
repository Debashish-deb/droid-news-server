class UrlIdentity {
  UrlIdentity._();

  static const Set<String> _trackingQueryKeys = <String>{
    'fbclid',
    'gclid',
    'igshid',
    'mc_cid',
    'mc_eid',
    'ref',
    'ref_src',
    'source',
  };

  static String canonicalize(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return '';

    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasAuthority) {
      return trimmed.toLowerCase();
    }

    final scheme = uri.scheme.toLowerCase();
    final host = uri.host.toLowerCase();
    final normalizedPath = _normalizePath(uri.path);
    final normalizedPort = _normalizePort(scheme, uri);
    final query = _normalizeQuery(uri);

    final normalized = Uri(
      scheme: scheme,
      userInfo: uri.userInfo.isEmpty ? null : uri.userInfo,
      host: host,
      port: normalizedPort,
      path: normalizedPath,
      query: query,
    );

    return normalized.toString();
  }

  static String idFromUrl(String rawUrl) {
    final canonical = canonicalize(rawUrl);
    return canonical.hashCode.toString();
  }

  static String _normalizePath(String path) {
    if (path.isEmpty) return '';
    if (path.endsWith('/') && path.length > 1) {
      return path.substring(0, path.length - 1);
    }
    return path;
  }

  static int? _normalizePort(String scheme, Uri uri) {
    if (!uri.hasPort) return null;
    final isDefaultHttp = scheme == 'http' && uri.port == 80;
    final isDefaultHttps = scheme == 'https' && uri.port == 443;
    if (isDefaultHttp || isDefaultHttps) {
      return null;
    }
    return uri.port;
  }

  static String? _normalizeQuery(Uri uri) {
    final items = <({String key, String value})>[];

    for (final entry in uri.queryParametersAll.entries) {
      final key = entry.key.toLowerCase();
      if (_isTrackingQueryKey(key)) {
        continue;
      }
      for (final value in entry.value) {
        items.add((key: key, value: value));
      }
    }

    if (items.isEmpty) return null;

    items.sort((a, b) {
      final keyComp = a.key.compareTo(b.key);
      if (keyComp != 0) return keyComp;
      return a.value.compareTo(b.value);
    });

    return items
        .map(
          (item) =>
              '${Uri.encodeQueryComponent(item.key)}=${Uri.encodeQueryComponent(item.value)}',
        )
        .join('&');
  }

  static bool _isTrackingQueryKey(String key) {
    return key.startsWith('utm_') || _trackingQueryKeys.contains(key);
  }
}
