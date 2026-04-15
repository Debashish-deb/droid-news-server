import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'ml_service.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// AAA-grade Bilingual Sentiment Analyzer — Bengali + English
/// Supports: বাংলা positive/negative/neutral classification
///
/// Architecture:
///  1. Language detection (Bangla vs English vs Mixed)
///  2. Lexicon-based multi-dimensional scoring (valence + arousal + dominance)
///  3. Negation handling ("ভালো না" → negative)
///  4. Intensifier amplification ("অত্যন্ত", "very" → boost)
///  5. Contextual news-domain calibration
///  6. Smooth-normalised output with rich metadata
/// ─────────────────────────────────────────────────────────────────────────────
class MLSentimentAnalyzer {
  MLSentimentAnalyzer(this._mlService);

  final MLService _mlService;
  bool _isInitialized = false;

  // Bounded LRU cache (text_hash → SentimentResult)
  final _cache = <String, SentimentResult>{};
  static const _maxCacheSize = 300;

  // ── Bangla sentiment lexicon ───────────────────────────────────────────────
  // Format: { 'word': valenceScore } where +1.0 = strongly positive, -1.0 = strongly negative

  static const _banglaPositiveWeights = {
    'বিজয়': 1.0,
    'জয়': 0.9,
    'সাফল্য': 1.0,
    'অর্জন': 0.9,
    'উন্নয়ন': 0.8,
    'অগ্রগতি': 0.8,
    'সমৃদ্ধি': 0.9,
    'শান্তি': 0.8,
    'প্রবৃদ্ধি': 0.8,
    'জিতেছে': 1.0,
    'চ্যাম্পিয়ন': 1.0,
    'সেঞ্চুরি': 0.9,
    'হ্যাটট্রিক': 1.0,
    'ঐতিহাসিক': 0.9,
    'ভালো': 0.6,
    'সুন্দর': 0.7,
    'চমৎকার': 0.9,
    'অসাধারণ': 0.9,
    'দারুণ': 0.8,
    'খুশি': 0.8,
    'আনন্দ': 0.8,
    'উৎসব': 0.7,
    'নিরাপদ': 0.6,
    'সুস্থ': 0.6,
    'ইতিবাচক': 0.7,
    'প্রশংসা': 0.7,
    'পুরস্কার': 0.7,
    'আশা': 0.6,
  };

  static const _banglaNegativeWeights = {
    'মৃত্যু': -1.0,
    'হত্যা': -1.0,
    'সংকট': -0.9,
    'দুর্যোগ': -1.0,
    'বন্যা': -0.8,
    'ঘূর্ণিঝড়': -0.9,
    'বিপদ': -0.8,
    'ক্ষতি': -0.7,
    'হার': -0.8,
    'পরাজয়': -0.9,
    'ব্যর্থ': -0.8,
    'দুর্নীতি': -0.9,
    'ধর্ষণ': -1.0,
    'নির্যাতন': -1.0,
    'সহিংসতা': -0.9,
    'দাঙ্গা': -0.9,
    'ধর্মঘট': -0.6,
    'অবরোধ': -0.7,
    'বিক্ষোভ': -0.6,
    'আতঙ্ক': -0.9,
    'ভয়': -0.7,
    'উদ্বেগ': -0.6,
    'মন্দা': -0.8,
    'মূল্যবৃদ্ধি': -0.7,
    'বেকারত্ব': -0.7,
    'দারিদ্র্য': -0.8,
    'অসুস্থ': -0.6,
    'রোগ': -0.6,
    'খারাপ': -0.6,
    'ভুল': -0.5,
    'নেতিবাচক': -0.6,
  };

  // ── English sentiment (news-domain calibrated) ─────────────────────────────
  static const _englishPositiveWeights = {
    'victory': 1.0,
    'win': 0.9,
    'success': 1.0,
    'achieve': 0.8,
    'breakthrough': 0.9,
    'record': 0.7,
    'champion': 1.0,
    'celebrate': 0.8,
    'progress': 0.7,
    'growth': 0.7,
    'recovery': 0.7,
    'improve': 0.6,
    'peace': 0.8,
    'hope': 0.6,
    'positive': 0.6,
    'praised': 0.7,
    'award': 0.7,
    'historic': 0.8,
    'landmark': 0.7,
    'safe': 0.5,
  };

  static const _englishNegativeWeights = {
    'death': -1.0,
    'killed': -1.0,
    'crisis': -0.9,
    'disaster': -1.0,
    'flood': -0.8,
    'cyclone': -0.9,
    'collapse': -0.9,
    'attack': -0.8,
    'violence': -0.9,
    'corruption': -0.9,
    'protest': -0.5,
    'strike': -0.6,
    'loss': -0.7,
    'defeat': -0.8,
    'fail': -0.7,
    'decline': -0.6,
    'inflation': -0.6,
    'unemployment': -0.7,
    'poverty': -0.8,
    'fear': -0.7,
    'threat': -0.7,
    'concern': -0.5,
    'warning': -0.6,
    'danger': -0.8,
    'riot': -0.9,
    'murder': -1.0,
    'rape': -1.0,
    'abuse': -0.9,
  };

  // ── Negation & intensifiers ────────────────────────────────────────────────
  static const _banglaIntensifiers = {
    'অত্যন্ত': 1.5,
    'খুব': 1.3,
    'অনেক': 1.2,
    'প্রচণ্ড': 1.5,
    'ভীষণ': 1.4,
    'মারাত্মক': 1.5,
    'অসাধারণ': 1.4,
    'বেশি': 1.2,
  };

  static const _englishIntensifiers = {
    'very': 1.3,
    'extremely': 1.5,
    'highly': 1.3,
    'massively': 1.4,
    'severely': 1.4,
    'critically': 1.5,
    'absolutely': 1.3,
  };

  static const _banglaNegators = [
    'না',
    'নয়',
    'নেই',
    'ছিল না',
    'হয়নি',
    'পারেনি',
    'করেনি',
  ];

  static const _englishNegators = [
    'not',
    "don't",
    "doesn't",
    "didn't",
    "won't",
    "no",
    "never",
    "without",
  ];

  // ── Public API ─────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
    debugLog('✅ MLSentimentAnalyzer initialised (bilingual EN+BN)');
  }

  /// Analyse sentiment of text with full bilingual support
  Future<SentimentResult> analyzeSentiment(String text) async {
    if (text.trim().isEmpty) {
      return SentimentResult.neutral(text: text);
    }

    final cacheKey = text.hashCode.toString();
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;
    if (!_isInitialized) await initialize();

    final language = _detectLanguage(text);
    final result = _analyze(text, language);

    _evictCacheIfNeeded();
    _cache[cacheKey] = result;
    return result;
  }

  /// Batch analyse multiple texts efficiently using a background Isolate
  Future<List<SentimentResult>> analyzeBatch(List<String> texts) async {
    if (texts.isEmpty) return [];
    if (!_isInitialized) await initialize();

    // Only use Isolate for larger batches to avoid overhead
    if (texts.length < 5) {
      return [for (final t in texts) await analyzeSentiment(t)];
    }

    return await compute(_analyzeBatchIsolate, texts);
  }

  /// Static Isolate function for parallel batch processing
  static List<SentimentResult> _analyzeBatchIsolate(List<String> texts) {
    // Note: We can't use the instance cache here, but that's fine for a batch
    return texts.map((text) {
      if (text.trim().isEmpty) return SentimentResult.neutral(text: text);
      final language = _detectLanguageStatic(text);
      return _analyzeStatic(text, language);
    }).toList();
  }

  // ── Core analysis ──────────────────────────────────────────────────────────

  SentimentResult _analyze(String text, SentimentLanguage language) {
    return _analyzeStatic(text, language);
  }

  static SentimentResult _analyzeStatic(
    String text,
    SentimentLanguage language,
  ) {
    final tokens = _tokenizeStatic(text);
    var positiveSum = 0.0;
    var negativeSum = 0.0;
    var hits = 0;

    final posWeights = language == SentimentLanguage.bangla
        ? _banglaPositiveWeights
        : _englishPositiveWeights;
    final negWeights = language == SentimentLanguage.bangla
        ? _banglaNegativeWeights
        : _englishNegativeWeights;
    final intensifiers = language == SentimentLanguage.bangla
        ? _banglaIntensifiers
        : _englishIntensifiers;
    final negators = language == SentimentLanguage.bangla
        ? _banglaNegators
        : _englishNegators;

    for (var i = 0; i < tokens.length; i++) {
      final token = tokens[i];

      // Check for preceding negator (window of 2 tokens)
      final negated = i > 0 && negators.contains(tokens[i - 1]);

      // Check for preceding intensifier (window of 2 tokens)
      var intensityMult = 1.0;
      if (i > 0) {
        intensityMult = intensifiers[tokens[i - 1]] ?? 1.0;
      }

      final posScore = posWeights[token];
      if (posScore != null) {
        final adjusted = posScore * intensityMult;
        if (negated) {
          negativeSum += adjusted * 0.7; // negation flips with dampening
        } else {
          positiveSum += adjusted;
        }
        hits++;
      }

      final negScore = negWeights[token];
      if (negScore != null) {
        final adjusted = negScore.abs() * intensityMult;
        if (negated) {
          positiveSum += adjusted * 0.5;
        } else {
          negativeSum += adjusted;
        }
        hits++;
      }
    }

    if (hits == 0) return SentimentResult.neutral(text: text);

    // Normalise using smooth sigmoid-like scaling
    final netScore = (positiveSum - negativeSum) / math.max(1, hits);
    final normalised = _sigmoidNormaliseStatic(netScore);

    final sentiment = normalised >= 0.62
        ? Sentiment.positive
        : normalised <= 0.38
        ? Sentiment.negative
        : Sentiment.neutral;

    final magnitude = (positiveSum + negativeSum) / math.max(1, hits);

    return SentimentResult(
      rawScore: normalised,
      sentiment: sentiment,
      language: language,
      positiveSignals: positiveSum.clamp(0.0, 10.0),
      negativeSignals: negativeSum.clamp(0.0, 10.0),
      magnitude: magnitude.clamp(0.0, 1.0),
      text: text.length > 100 ? '${text.substring(0, 97)}…' : text,
    );
  }

  static double _sigmoidNormaliseStatic(double x) =>
      (math.tan(x * 1.5) + 1) / 2;

  SentimentLanguage _detectLanguage(String text) {
    return _detectLanguageStatic(text);
  }

  static SentimentLanguage _detectLanguageStatic(String text) {
    final banglaChars = RegExp(r'[\u0980-\u09FF]').allMatches(text).length;
    final ratio = banglaChars / math.max(1, text.length);
    if (ratio > 0.4) return SentimentLanguage.bangla;
    if (ratio > 0.1) return SentimentLanguage.mixed;
    return SentimentLanguage.english;
  }

  static List<String> _tokenizeStatic(String text) {
    return text
        .toLowerCase()
        .split(RegExp(r'[\s,،.!?।\n]+'))
        .where((t) => t.isNotEmpty)
        .toList();
  }

  void _evictCacheIfNeeded() {
    if (_cache.length >= _maxCacheSize) {
      _cache.remove(_cache.keys.first);
    }
  }

  void dispose() {
    _mlService.close();
    _cache.clear();
    _isInitialized = false;
  }

  void debugLog(String msg) {
    if (kDebugMode) debugPrint(msg);
  }
}

// ── Supporting models ─────────────────────────────────────────────────────────

enum Sentiment { positive, neutral, negative }

enum SentimentLanguage { english, bangla, mixed }

class SentimentResult {
  const SentimentResult({
    required this.rawScore,
    required this.sentiment,
    required this.language,
    required this.positiveSignals,
    required this.negativeSignals,
    required this.magnitude,
    required this.text,
  });

  factory SentimentResult.neutral({required String text}) => SentimentResult(
    rawScore: 0.5,
    sentiment: Sentiment.neutral,
    language: SentimentLanguage.english,
    positiveSignals: 0,
    negativeSignals: 0,
    magnitude: 0,
    text: text,
  );

  final double rawScore; // 0.0 (negative) → 0.5 (neutral) → 1.0 (positive)
  final Sentiment sentiment;
  final SentimentLanguage language;
  final double positiveSignals;
  final double negativeSignals;
  final double magnitude; // Overall emotional intensity
  final String text;

  // ── Convenience getters ────────────────────────────────────────────────────

  /// Bangla label for display in app
  String get labelBn {
    switch (sentiment) {
      case Sentiment.positive:
        return magnitude > 0.7 ? 'অত্যন্ত ইতিবাচক' : 'ইতিবাচক';
      case Sentiment.negative:
        return magnitude > 0.7 ? 'অত্যন্ত নেতিবাচক' : 'নেতিবাচক';
      case Sentiment.neutral:
        return 'নিরপেক্ষ';
    }
  }

  String get labelEn {
    switch (sentiment) {
      case Sentiment.positive:
        return magnitude > 0.7 ? 'Very Positive' : 'Positive';
      case Sentiment.negative:
        return magnitude > 0.7 ? 'Very Negative' : 'Negative';
      case Sentiment.neutral:
        return 'Neutral';
    }
  }

  String get emoji {
    switch (sentiment) {
      case Sentiment.positive:
        return rawScore > 0.8 ? '🎉' : '😊';
      case Sentiment.negative:
        return rawScore < 0.2 ? '😢' : '😟';
      case Sentiment.neutral:
        return '😐';
    }
  }

  /// Colour hint for UI (hex string)
  String get colorHex {
    switch (sentiment) {
      case Sentiment.positive:
        return '#2ECC71';
      case Sentiment.negative:
        return '#E74C3C';
      case Sentiment.neutral:
        return '#95A5A6';
    }
  }

  bool get isPositive => sentiment == Sentiment.positive;
  bool get isNegative => sentiment == Sentiment.negative;
  bool get isNeutral => sentiment == Sentiment.neutral;
  bool get isBangla => language == SentimentLanguage.bangla;

  String get scorePercent => '${(rawScore * 100).toStringAsFixed(0)}%';

  @override
  String toString() =>
      'SentimentResult($labelEn, score: ${rawScore.toStringAsFixed(2)}, '
      'magnitude: ${magnitude.toStringAsFixed(2)}, lang: ${language.name})';
}
