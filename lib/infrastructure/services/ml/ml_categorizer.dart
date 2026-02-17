import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../ml_service.dart';

/// ML-powered article categorization service
/// Uses TFLite model for intelligent categorization with keyword fallback
class MLCategorizer {
  MLCategorizer(this._mlService);
  final MLService _mlService;
  bool _isInitialized = false;
  Map<String, dynamic>? _categories;
  final Map<String, String> _resultCache = {};

  /// Initialize the categorizer with model and metadata
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final categoriesJson = await rootBundle.loadString(
        'assets/ml_data/categories.json',
      );
      _categories = json.decode(categoriesJson);


      _isInitialized = true;
      if (kDebugMode) {
        debugPrint('✅ MLCategorizer initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ MLCategorizer initialization failed: $e');
      }
    }
  }

  /// Categorize an article using ML model (when available) or keyword fallback
  Future<String> categorizeArticle(String title, String content) async {
    final cacheKey = '${title.hashCode}_${content.hashCode}';
    if (_resultCache.containsKey(cacheKey)) {
      return _resultCache[cacheKey]!;
    }

    if (!_isInitialized) await initialize();

    final result = _keywordBasedCategorization(title, content);
    _resultCache[cacheKey] = result;
    return result;
  }

  /// Get category probabilities for an article
  Future<Map<String, double>> getCategoryProbabilities(String text) async {
    if (!_isInitialized) await initialize();

    final scores = <String, double>{};

    if (_categories != null) {
      final categoriesList = _categories!['categories'] as List;
      final lowerText = text.toLowerCase();

      for (final cat in categoriesList) {
        final keywords = (cat['keywords'] as List).cast<String>();
        var score = 0.0;

        for (final keyword in keywords) {
          if (lowerText.contains(keyword.toLowerCase())) {
            score += 1.0;
          }
        }

        scores[cat['id']] = score / keywords.length;
      }
    }

    return scores;
  }

  /// Keyword-based categorization fallback
  String _keywordBasedCategorization(String title, String content) {
    if (_categories == null) return 'world';

    final text = '${title.toLowerCase()} ${content.toLowerCase()}';
    final categoriesList = _categories!['categories'] as List;

    var maxScore = 0;
    var bestCategory = _categories!['default_category'] as String;

    for (final cat in categoriesList) {
      final keywords = (cat['keywords'] as List).cast<String>();
      var score = 0;

      for (final keyword in keywords) {
        if (text.contains(keyword.toLowerCase())) {
          score++;
        }
      }

      if (score > maxScore) {
        maxScore = score;
        bestCategory = cat['id'];
      }
    }

    return bestCategory;
  }

  /// Get category display info
  Map<String, dynamic>? getCategoryInfo(String categoryId) {
    if (_categories == null) return null;

    final categoriesList = _categories!['categories'] as List;
    for (final cat in categoriesList) {
      if (cat['id'] == categoryId) {
        return cat as Map<String, dynamic>;
      }
    }
    return null;
  }

  /// Clean up resources
  void dispose() {
    _mlService.close();
    _isInitialized = false;
  }
}
