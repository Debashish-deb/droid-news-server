// ignore_for_file: avoid_classes_with_only_static_members

import '../../presentation/features/common/webview_args.dart';
import 'app_paths.dart';
import 'url_safety_policy.dart';

class NotificationRouteTarget {
  const NotificationRouteTarget({
    required this.location,
    required this.extra,
  });

  final String location;
  final Object? extra;
}

class NotificationPayloadParser {
  static NotificationRouteTarget? parse(Map<String, dynamic> payload) {
    final rawUrl = _readString(payload, 'article_url') ?? _readString(payload, 'url');
    if (rawUrl == null || rawUrl.isEmpty) {
      return null;
    }

    final decision = UrlSafetyPolicy.evaluate(rawUrl);
    if (decision.disposition != UrlSafetyDisposition.allowInApp ||
        decision.uri == null) {
      return null;
    }

    final title =
        _readString(payload, 'title') ??
        _readString(payload, 'article_title') ??
        _readString(payload, 'source') ??
        'News update';

    return NotificationRouteTarget(
      location: AppPaths.webview,
      extra: WebViewArgs(
        url: decision.uri!,
        title: title,
        origin: WebViewOrigin.notification,
      ),
    );
  }

  static String? _readString(Map<String, dynamic> payload, String key) {
    final value = payload[key];
    if (value is! String) {
      return null;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
