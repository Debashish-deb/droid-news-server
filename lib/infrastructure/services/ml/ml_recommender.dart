import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Content recommendation engine for personalized article suggestions
class MLRecommender {
  MLRecommender._();
  static final MLRecommender instance = MLRecommender._();

  static const _readHistoryKey = 'ml_read_history';
  static const _categoryPrefsKey = 'ml_category_prefs';
  static const _maxHistorySize = 100;

  List<String> _readHistory = [];
  Map<String, int> _categoryPreferences = {};
  bool _isInitialized = false;

  /// Initialize the recommender
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      final historyJson = prefs.getString(_readHistoryKey);
      if (historyJson != null) {
        _readHistory = List<String>.from(json.decode(historyJson));
      }

      final prefsJson = prefs.getString(_categoryPrefsKey);
      if (prefsJson != null) {
        _categoryPreferences = Map<String, int>.from(json.decode(prefsJson));
      }

      _isInitialized = true;
      if (kDebugMode) {
        debugPrint(
          '✅ MLRecommender initialized - ${_readHistory.length} articles in history',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ MLRecommender initialization failed: $e');
      }
    }
  }

  /// Track article read
  Future<void> trackArticleRead(String articleUrl, String? category) async {
    if (!_isInitialized) await initialize();

    if (!_readHistory.contains(articleUrl)) {
      _readHistory.insert(0, articleUrl);

      if (_readHistory.length > _maxHistorySize) {
        _readHistory = _readHistory.sublist(0, _maxHistorySize);
      }
    }

    if (category != null) {
      _categoryPreferences[category] =
          (_categoryPreferences[category] ?? 0) + 1;
    }

    await _savePreferences();
  }

  /// Get recommended categories based on user preferences
  List<String> getRecommendedCategories({int limit = 3}) {
    if (_categoryPreferences.isEmpty) return [];

    final sorted =
        _categoryPreferences.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(limit).map((e) => e.key).toList();
  }

  /// Calculate recommendation score for an article
  double getRecommendationScore(String? category, String url) {
    var score = 0.5; 

    if (_readHistory.contains(url)) {
      score -= 0.3;
    }

    if (category != null && _categoryPreferences.containsKey(category)) {
      final categoryScore = _categoryPreferences[category]!;
      final maxScore = _categoryPreferences.values.reduce(
        (a, b) => a > b ? a : b,
      );
      score += 0.4 * (categoryScore / maxScore);
    }

    if (!_readHistory.contains(url)) {
      score += 0.1;
    }

    return score.clamp(0.0, 1.0);
  }

  /// Get reading history
  List<String> getReadHistory({int limit = 20}) {
    return _readHistory.take(limit).toList();
  }

  /// Clear reading history
  Future<void> clearHistory() async {
    _readHistory.clear();
    _categoryPreferences.clear();
    await _savePreferences();
  }

  /// Save preferences to storage
  Future<void> _savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_readHistoryKey, json.encode(_readHistory));
      await prefs.setString(
        _categoryPrefsKey,
        json.encode(_categoryPreferences),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Failed to save preferences: $e');
      }
    }
  }

  /// Get stats for debugging
  Map<String, dynamic> getStats() {
    return {
      'total_reads': _readHistory.length,
      'category_preferences': _categoryPreferences,
      'top_categories': getRecommendedCategories(limit: 5),
    };
  }
}
