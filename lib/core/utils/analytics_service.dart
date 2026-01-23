import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Analytics service for tracking user events and behavior
class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  static final FirebaseAnalyticsObserver observer = FirebaseAnalyticsObserver(
    analytics: _analytics,
  );

  /// Log article opened event
  static Future<void> logArticleOpened({
    required String articleId,
    required String source,
    String? category,
  }) async {
    if (!kDebugMode) {
      await _analytics.logEvent(
        name: 'article_opened',
        parameters: {
          'article_id': articleId,
          'source': source,
          if (category != null) 'category': category,
        },
      );
    }
  }

  /// Log favorite added
  static Future<void> logFavoriteAdded(String articleId) async {
    if (!kDebugMode) {
      await _analytics.logEvent(
        name: 'favorite_added',
        parameters: {'article_id': articleId},
      );
    }
  }

  /// Log favorite removed
  static Future<void> logFavoriteRemoved(String articleId) async {
    if (!kDebugMode) {
      await _analytics.logEvent(
        name: 'favorite_removed',
        parameters: {'article_id': articleId},
      );
    }
  }

  /// Log search performed
  static Future<void> logSearch(String query) async {
    if (!kDebugMode) {
      await _analytics.logSearch(searchTerm: query);
    }
  }

  /// Log language changed
  static Future<void> logLanguageChanged(String language) async {
    if (!kDebugMode) {
      await _analytics.logEvent(
        name: 'language_changed',
        parameters: {'language': language},
      );
    }
  }

  /// Log theme changed
  static Future<void> logThemeChanged(String theme) async {
    if (!kDebugMode) {
      await _analytics.logEvent(
        name: 'theme_changed',
        parameters: {'theme': theme},
      );
    }
  }

  /// Log app opened event
  static Future<void> logAppOpen() async {
    if (!kDebugMode) {
      await _analytics.logAppOpen();
    }
  }

  /// Set user property
  static Future<void> setUserProperty({
    required String name,
    required String value,
  }) async {
    if (!kDebugMode) {
      await _analytics.setUserProperty(name: name, value: value);
    }
  }

  /// Set current screen name
  static Future<void> setCurrentScreen(String screenName) async {
    if (!kDebugMode) {
      await _analytics.logScreenView(screenName: screenName);
    }
  }

  /// Log generic custom event
  static Future<void> logEvent({
    required String name,
    Map<String, dynamic>? parameters,
  }) async {
    if (!kDebugMode) {
      await _analytics.logEvent(
        name: name,
        parameters: parameters?.map(
          (key, value) => MapEntry(key, value as Object),
        ),
      );
    }
  }
}
