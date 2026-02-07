import 'package:flutter/foundation.dart';
import '../ml_service.dart';

/// ML-powered sentiment analysis service
class MLSentimentAnalyzer {
  MLSentimentAnalyzer._();
  static final MLSentimentAnalyzer instance = MLSentimentAnalyzer._();

  final MLService _mlService = MLService();
  bool _isInitialized = false;
  final Map<String, double> _resultCache = {};

  static const _positiveKeywords = [
    'success',
    'win',
    'achieve',
    'victory',
    'celebrate',
    'happy',
    'excellent',
    'breakthrough',
    'improve',
    'progress',
    'hope',
  ];

  static const _negativeKeywords = [
    'fail',
    'loss',
    'crisis',
    'disaster',
    'death',
    'attack',
    'concern',
    'fear',
    'threat',
    'decline',
    'collapse',
  ];

  /// Initialize the sentiment analyzer
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {

      _isInitialized = true;
      if (kDebugMode) {
        debugPrint('✅ MLSentimentAnalyzer initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ MLSentimentAnalyzer initialization failed: $e');
      }
    }
  }

  /// Analyze sentiment of text
  /// Returns score: 0.0-0.3 (negative), 0.3-0.7 (neutral), 0.7-1.0 (positive)
  Future<double> analyzeSentiment(String text) async {
    final cacheKey = text.hashCode.toString();
    if (_resultCache.containsKey(cacheKey)) {
      return _resultCache[cacheKey]!;
    }

    if (!_isInitialized) await initialize();

    final result = _keywordBasedSentiment(text);
    _resultCache[cacheKey] = result;
    return result;
  }

  /// Get sentiment label
  String getSentimentLabel(double score) {
    if (score < 0.3) return 'negative';
    if (score < 0.7) return 'neutral';
    return 'positive';
  }

  /// Get sentiment emoji
  String getSentimentEmoji(double score) {
    if (score < 0.3) return '😔';
    if (score < 0.7) return '😐';
    return '😊';
  }

  /// Keyword-based sentiment fallback
  double _keywordBasedSentiment(String text) {
    final lowerText = text.toLowerCase();
    var positiveCount = 0;
    var negativeCount = 0;

    for (final word in _positiveKeywords) {
      if (lowerText.contains(word)) positiveCount++;
    }

    for (final word in _negativeKeywords) {
      if (lowerText.contains(word)) negativeCount++;
    }

    final total = positiveCount + negativeCount;
    if (total == 0) return 0.5;

    final positiveRatio = positiveCount / total;
    return positiveRatio;
  }

  /// Clean up resources
  void dispose() {
    _mlService.close();
    _isInitialized = false;
  }
}
