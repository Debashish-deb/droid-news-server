import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../ml_service.dart';

/// ML-powered article categorization service
/// Uses TFLite model for intelligent categorization with keyword fallback
class MLCategorizer {
  MLCategorizer._();
  static final MLCategorizer instance = MLCategorizer._();

  final MLService _mlService = MLService();
  bool _isInitialized = false;
  Map<String, dynamic>? _categories;

  /// Initialize the categorizer with model and metadata
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Load category metadata
      final categoriesJson = await rootBundle.loadString(
        'assets/ml_data/categories.json',
      );
      _categories = json.decode(categoriesJson);

      // TODO: Load TFLite model when available
      // await _mlService.loadModel('assets/models/article_classifier.tflite');

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
    if (!_isInitialized) await initialize();

    // TODO: Use ML model for categorization when available
    // For now, use keyword-based fallback
    return _keywordBasedCategorization(title, content);
  }

  /// Get category probabilities for an article
  Future<Map<String, double>> getCategoryProbabilities(String text) async {
    if (!_isInitialized) await initialize();

    // TODO: Implement ML-based probability calculation
    // For now, return simple keyword matching scores
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
