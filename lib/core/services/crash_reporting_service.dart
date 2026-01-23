import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Enhanced crash reporting service with custom context
class CrashReportingService {
  static Future<void> initialize() async {
    final packageInfo = await PackageInfo.fromPlatform();

    // Set app version
    await FirebaseCrashlytics.instance.setCustomKey(
      'app_version',
      packageInfo.version,
    );
    await FirebaseCrashlytics.instance.setCustomKey(
      'build_number',
      packageInfo.buildNumber,
    );

    // Listen to auth state for user context
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        FirebaseCrashlytics.instance.setUserIdentifier(user.uid);
        FirebaseCrashlytics.instance.setCustomKey(
          'user_email',
          user.email ?? 'unknown',
        );
        FirebaseCrashlytics.instance.setCustomKey(
          'user_created',
          user.metadata.creationTime?.toIso8601String() ?? 'unknown',
        );
      } else {
        FirebaseCrashlytics.instance.setUserIdentifier('anonymous');
      }
    });
  }

  /// Log a breadcrumb for tracking user actions
  static void logBreadcrumb(String message, {Map<String, dynamic>? data}) {
    FirebaseCrashlytics.instance.log(
      '$message ${data != null ? data.toString() : ''}',
    );
  }

  /// Set custom key for crash context
  static Future<void> setCustomKey(String key, dynamic value) async {
    await FirebaseCrashlytics.instance.setCustomKey(key, value);
  }

  /// Log non-fatal error
  static Future<void> logError(
    dynamic error,
    StackTrace? stackTrace, {
    String? reason,
  }) async {
    await FirebaseCrashlytics.instance.recordError(
      error,
      stackTrace,
      reason: reason,
    );
  }

  /// Set user properties for better debugging
  static Future<void> setUserProperties({
    required bool isPremium,
    String? preferredLanguage,
    String? themeMode,
    int? deviceCount,
  }) async {
    await FirebaseCrashlytics.instance.setCustomKey('is_premium', isPremium);
    if (preferredLanguage != null) {
      await FirebaseCrashlytics.instance.setCustomKey(
        'language',
        preferredLanguage,
      );
    }
    if (themeMode != null) {
      await FirebaseCrashlytics.instance.setCustomKey('theme', themeMode);
    }
    if (deviceCount != null) {
      await FirebaseCrashlytics.instance.setCustomKey(
        'device_count',
        deviceCount,
      );
    }
  }

  /// Log feature usage for crash context
  static Future<void> logFeatureUsage(String feature) async {
    await FirebaseCrashlytics.instance.setCustomKey('last_feature', feature);
    logBreadcrumb('Feature used: $feature');
  }

  /// Log article interaction for crash context
  static Future<void> logArticleInteraction(
    String articleId,
    String action,
  ) async {
    await FirebaseCrashlytics.instance.setCustomKey('last_article', articleId);
    await FirebaseCrashlytics.instance.setCustomKey('last_action', action);
    logBreadcrumb('Article $action: $articleId');
  }

  /// Log network error context
  static Future<void> logNetworkError(
    String url,
    int? statusCode,
    String? error,
  ) async {
    await FirebaseCrashlytics.instance.setCustomKey('last_network_url', url);
    if (statusCode != null) {
      await FirebaseCrashlytics.instance.setCustomKey(
        'last_network_status',
        statusCode,
      );
    }
    logBreadcrumb('Network error: $url - $error');
  }
}
