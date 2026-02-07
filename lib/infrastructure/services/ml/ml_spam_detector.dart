import 'package:flutter/foundation.dart';

// Spam and clickbait detection service
class MLSpamDetector {
  MLSpamDetector._();
  static final MLSpamDetector instance = MLSpamDetector._();

  bool _isInitialized = false;

  static const _clickbaitKeywords = [
    'you won\'t believe',
    'shocking',
    'one weird trick',
    'doctors hate',
    'click here',
    'amazing',
    'unbelievable',
    'this is why',
    'what happens next',
    'mind-blowing',
  ];

  static const _spamKeywords = [
    'free money',
    'act now',
    'limited time',
    'call now',
    'click now',
    'buy now',
    'order now',
  ];

  Future<void> initialize() async {
    if (_isInitialized) return;

    _isInitialized = true;
    if (kDebugMode) {
      debugPrint('✅ MLSpamDetector initialized');
    }
  }

  Future<double> getQualityScore(String title, String content) async {
    if (!_isInitialized) await initialize();

    var score = 1.0; 

    final lowerTitle = title.toLowerCase();
    final lowerContent = content.toLowerCase();

    var clickbaitCount = 0;
    for (final keyword in _clickbaitKeywords) {
      if (lowerTitle.contains(keyword)) clickbaitCount++;
    }
    score -= clickbaitCount * 0.15; 

    var spamCount = 0;
    for (final keyword in _spamKeywords) {
      if (lowerTitle.contains(keyword) || lowerContent.contains(keyword)) {
        spamCount++;
      }
    }
    score -= spamCount * 0.2; 

    final exclamationCount = '!!!'.allMatches(lowerTitle).length;
    final questionCount = '???'.allMatches(lowerTitle).length;
    score -= (exclamationCount + questionCount) * 0.1;

    if (title == title.toUpperCase() && title.length > 10) {
      score -= 0.2;
    }

    return score.clamp(0.0, 1.0);
  }

  Future<bool> isSpam(String title, String content) async {
    final score = await getQualityScore(title, content);
    return score < 0.3;
  }

  Future<bool> isClickbait(String title) async {
    final lowerTitle = title.toLowerCase();

    var count = 0;
    for (final keyword in _clickbaitKeywords) {
      if (lowerTitle.contains(keyword)) count++;
    }

    return count >= 2; 
  }

  Future<Map<String, dynamic>> analyzeArticle(
    String title,
    String content,
  ) async {
    final qualityScore = await getQualityScore(title, content);
    final isSpamArticle = await isSpam(title, content);
    final isClickbaitTitle = await isClickbait(title);

    return {
      'quality_score': qualityScore,
      'is_spam': isSpamArticle,
      'is_clickbait': isClickbaitTitle,
      'quality_label':
          qualityScore >= 0.7
              ? 'high'
              : (qualityScore >= 0.4 ? 'medium' : 'low'),
    };
  }
}
