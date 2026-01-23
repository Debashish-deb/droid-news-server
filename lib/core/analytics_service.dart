import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Analytics service for tracking user behavior and app events
class AnalyticsService {
  AnalyticsService._();

  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  static final FirebaseAnalyticsObserver observer = FirebaseAnalyticsObserver(
    analytics: _analytics,
  );

  static bool _consentGiven = true;

  static Future<void> setConsent({required bool granted}) async {
    _consentGiven = granted;
    await _analytics.setAnalyticsCollectionEnabled(granted);
    if (kDebugMode) debugPrint('📊 Analytics Consent: $granted');
  }

  static bool get isConsentGiven => _consentGiven;

  // Screen Views
  static Future<void> logScreenView(String screenName) async {
    try {
      await _analytics.logScreenView(screenName: screenName);
      if (kDebugMode) debugPrint('📊 Screen: $screenName');
    } catch (e) {
      debugPrint('Analytics error: $e');
    }
  }

  // Article Events
  static Future<void> logArticleRead({
    required String title,
    required String category,
    required String source,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'article_read',
        parameters: {
          'article_title': title.substring(
            0,
            title.length > 100 ? 100 : title.length,
          ),
          'category': category,
          'source': source,
        },
      );
      if (kDebugMode) debugPrint('📊 Article Read: $category');
    } catch (e) {
      debugPrint('Analytics error: $e');
    }
  }

  static Future<void> logArticleShare({
    required String title,
    required String category,
  }) async {
    try {
      await _analytics.logShare(
        contentType: 'article',
        itemId: title.substring(0, title.length > 100 ? 100 : title.length),
        method: 'share_button',
      );
      if (kDebugMode) debugPrint('📊 Article Shared');
    } catch (e) {
      debugPrint('Analytics error: $e');
    }
  }

  static Future<void> logArticleBookmark({
    required String title,
    required bool isBookmarked,
  }) async {
    try {
      await _analytics.logEvent(
        name: isBookmarked ? 'bookmark_add' : 'bookmark_remove',
        parameters: {
          'article_title': title.substring(
            0,
            title.length > 100 ? 100 : title.length,
          ),
        },
      );
      if (kDebugMode) debugPrint('📊 Bookmark: $isBookmarked');
    } catch (e) {
      debugPrint('Analytics error: $e');
    }
  }

  // Search Events
  static Future<void> logSearch(String query) async {
    try {
      await _analytics.logSearch(searchTerm: query);
      if (kDebugMode) debugPrint('📊 Search: $query');
    } catch (e) {
      debugPrint('Analytics error: $e');
    }
  }

  // Category Selection
  static Future<void> logCategorySelect(String category) async {
    try {
      await _analytics.logEvent(
        name: 'category_select',
        parameters: {'category': category},
      );
      if (kDebugMode) debugPrint('📊 Category: $category');
    } catch (e) {
      debugPrint('Analytics error: $e');
    }
  }

  // Reader Mode
  static Future<void> logReaderMode() async {
    try {
      await _analytics.logEvent(name: 'reader_mode_activate');
      if (kDebugMode) debugPrint('📊 Reader Mode Activated');
    } catch (e) {
      debugPrint('Analytics error: $e');
    }
  }

  // TTS Events
  static Future<void> logTTSUsage({required bool started}) async {
    try {
      await _analytics.logEvent(name: started ? 'tts_start' : 'tts_stop');
      if (kDebugMode) debugPrint('📊 TTS: ${started ? "Start" : "Stop"}');
    } catch (e) {
      debugPrint('Analytics error: $e');
    }
  }

  // Premium Events
  static Future<void> logPremiumPurchase(String productId) async {
    try {
      await _analytics.logEvent(
        name: 'premium_purchase',
        parameters: {'product_id': productId},
      );
      if (kDebugMode) debugPrint('📊 Premium Purchase: $productId');
    } catch (e) {
      debugPrint('Analytics error: $e');
    }
  }

  static Future<void> logPremiumFeatureAttempt(String feature) async {
    try {
      await _analytics.logEvent(
        name: 'premium_feature_attempt',
        parameters: {'feature': feature},
      );
      if (kDebugMode) debugPrint('📊 Premium Feature Attempt: $feature');
    } catch (e) {
      debugPrint('Analytics error: $e');
    }
  }

  // User Properties
  static Future<void> setUserLanguage(String language) async {
    try {
      await _analytics.setUserProperty(name: 'language', value: language);
    } catch (e) {
      debugPrint('Analytics error: $e');
    }
  }

  static Future<void> setUserTheme(String theme) async {
    try {
      await _analytics.setUserProperty(name: 'theme', value: theme);
    } catch (e) {
      debugPrint('Analytics error: $e');
    }
  }

  static Future<void> setIsPremium(bool isPremium) async {
    try {
      await _analytics.setUserProperty(
        name: 'is_premium',
        value: isPremium.toString(),
      );
    } catch (e) {
      debugPrint('Analytics error: $e');
    }
  }

  // Error Tracking
  static Future<void> logError({
    required String error,
    required String location,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'app_error',
        parameters: {
          'error_message': error.substring(
            0,
            error.length > 100 ? 100 : error.length,
          ),
          'location': location,
        },
      );
      if (kDebugMode) debugPrint('📊 Error: $error at $location');
    } catch (e) {
      debugPrint('Analytics error: $e');
    }
  }

  // App Lifecycle
  static Future<void> logAppOpen() async {
    try {
      await _analytics.logAppOpen();
      if (kDebugMode) debugPrint('📊 App Opened');
    } catch (e) {
      debugPrint('Analytics error: $e');
    }
  }
}
