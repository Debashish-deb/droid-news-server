// ignore_for_file: avoid_classes_with_only_static_members

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Application configuration for news sources
class AppConfig {
  static bool _envBool(String key, {bool fallback = false}) {
    final raw = dotenv.isInitialized ? dotenv.env[key]?.trim() : null;
    if (raw == null || raw.isEmpty) return fallback;
    switch (raw.toLowerCase()) {
      case '1':
      case 'true':
      case 'yes':
      case 'on':
        return true;
      case '0':
      case 'false':
      case 'no':
      case 'off':
        return false;
      default:
        return fallback;
    }
  }

  // Backend WebSocket server URL
  static String get backendUrl {
    const define = String.fromEnvironment('BACKEND_URL');
    final env = dotenv.isInitialized ? (dotenv.env['BACKEND_URL'] ?? '') : '';
    final resolved = define.trim().isNotEmpty ? define : env;
    return resolved.trim();
  }

  // Feature flags
  static bool get useWebSocket {
    const define = String.fromEnvironment('USE_WEBSOCKET');
    if (define.isNotEmpty) {
      final normalized = define.trim().toLowerCase();
      return normalized == '1' ||
          normalized == 'true' ||
          normalized == 'yes' ||
          normalized == 'on';
    }
    return _envBool('USE_WEBSOCKET');
  }

  static bool get useRssFallback => true;

  // Forced to 'rss' as requested: "remove api (stubb the api settings for now)"
  static String get newsPriority => 'rss';

  // API Keys (Stubbed)
  static String get newsApiKey => '';

  static String get newsDataApiKey => '';

  static String get gNewsApiKey => '';

  static bool isPlaceholderValue(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return true;
    return normalized.contains('YOUR_') ||
        normalized.contains('_HERE') ||
        normalized.contains('MISSING_') ||
        normalized == 'pub_YOUR_KEY';
  }

  static bool isConfiguredSecret(String value) => !isPlaceholderValue(value);

  static void _enforceHttpsBackendInRelease() {
    if (kReleaseMode &&
        useWebSocket &&
        backendUrl.isNotEmpty &&
        backendUrl.startsWith('http://')) {
      throw StateError('BACKEND_URL must use HTTPS in release mode.');
    }
  }

  static void validateConfiguration() {
    _enforceHttpsBackendInRelease();
    final missing = <String>[];
    final placeholders = <String>[];
    final priority = newsPriority.trim().toLowerCase();
    final isRssOnly = priority.isEmpty || priority == 'rss';

    void check(String key, String value) {
      if (value.isEmpty) {
        missing.add(key);
      } else if (value.contains('YOUR_') || value.contains('_HERE')) {
        placeholders.add(key);
      }
    }

    if (useWebSocket) {
      check('BACKEND_URL', backendUrl);
    }
    if (!isRssOnly) {
      check('NEWSDATA_API_KEY', newsDataApiKey);
      check('GNEWS_API_KEY', gNewsApiKey);
    }

    if (!dotenv.isInitialized && missing.isNotEmpty) {
      debugPrint(
        '⚠️ WARNING: .env file not loaded and no --dart-defines found.',
      );
    }

    if (missing.isNotEmpty) {
      debugPrint('❌ MISSING CONFIGURATION: ${missing.join(', ')}');
      debugPrint(
        'Please add these to your .env file or build with --dart-define',
      );
    }

    if (placeholders.isNotEmpty) {
      debugPrint(
        '💡 CONFIGURATION ALERT: Placeholder values detected for: ${placeholders.join(', ')}',
      );
      debugPrint('Some features may not work until you provide real API keys.');
    }

    if (missing.isEmpty && placeholders.isEmpty) {
      debugPrint('✅ App configuration validated.');
    }

    if (isRssOnly) {
      debugPrint(
        '📰 News source mode: RSS only (set NEWS_PRIORITY=api or mixed to enable API ingest).',
      );
    }
    if (!useWebSocket) {
      debugPrint('🔌 WebSocket backend disabled (USE_WEBSOCKET=false).');
    }
  }
}
