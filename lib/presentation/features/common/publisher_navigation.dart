import 'package:flutter/material.dart';

import '../../../core/navigation/navigation_helper.dart';
import '../../../core/navigation/url_safety_policy.dart';

String resolvePublisherUrl(Map<String, dynamic> publisher) {
  final maybeWebsite = publisher['contact']?['website'];
  final website = _normalizePublisherUrl(maybeWebsite);
  if (website.isNotEmpty) {
    return website;
  }
  final maybeUrl = publisher['url'] ?? publisher['link'];
  return _normalizePublisherUrl(maybeUrl);
}

String resolvePublisherTitle(
  Map<String, dynamic> publisher, {
  required String fallbackTitle,
}) {
  final rawName = publisher['name'];
  if (rawName is String && rawName.trim().isNotEmpty) {
    return rawName.trim();
  }
  return fallbackTitle;
}

Future<bool> openPublisherWebView(
  BuildContext context, {
  required Map<String, dynamic> publisher,
  required String fallbackTitle,
  required String noUrlMessage,
  VoidCallback? onBeforeOpen,
}) async {
  final url = resolvePublisherUrl(publisher);
  final title = resolvePublisherTitle(publisher, fallbackTitle: fallbackTitle);
  if (url.isEmpty) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(noUrlMessage)));
    return false;
  }

  final decision = UrlSafetyPolicy.evaluate(url);
  if (decision.disposition == UrlSafetyDisposition.reject) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(noUrlMessage)));
    return false;
  }

  onBeforeOpen?.call();
  if (!context.mounted) {
    return false;
  }
  await NavigationHelper.goWebView(context, url: url, title: title);
  return true;
}

String _normalizePublisherUrl(Object? rawValue) {
  if (rawValue is! String) return '';
  var raw = rawValue.trim();
  if (raw.isEmpty || raw.toLowerCase() == 'n/a') return '';

  final markdownMatch = RegExp(r'^\[[^\]]+\]\(([^)]+)\)$').firstMatch(raw);
  if (markdownMatch != null) {
    raw = markdownMatch.group(1)?.trim() ?? '';
  } else {
    final embeddedUrl = RegExp(
      r'https?://[^\s\])>"]+',
      caseSensitive: false,
    ).firstMatch(raw);
    if (embeddedUrl != null) {
      raw = embeddedUrl.group(0)?.trim() ?? '';
    }
  }

  raw = raw
      .replaceAll(RegExp("^[<(\"']+"), '')
      .replaceAll(RegExp("[>)\"'.]+\$"), '')
      .trim();
  if (raw.isEmpty) return '';

  if (raw.startsWith(RegExp(r'www\.', caseSensitive: false))) {
    raw = 'https://$raw';
  } else if (raw.startsWith(RegExp(r'http://', caseSensitive: false))) {
    raw = raw.replaceFirst(
      RegExp(r'^http://', caseSensitive: false),
      'https://',
    );
  }

  final uri = Uri.tryParse(raw);
  if (uri == null || !uri.hasScheme) return '';
  final scheme = uri.scheme.toLowerCase();
  if ((scheme == 'http' || scheme == 'https') && uri.host.trim().isNotEmpty) {
    return raw;
  }
  if (scheme == 'mailto' || scheme == 'tel') {
    return raw;
  }

  // Ignore accidental asset paths, labels, or other non-navigation strings so
  // callers can fall back to another publisher URL field.
  return '';
}
