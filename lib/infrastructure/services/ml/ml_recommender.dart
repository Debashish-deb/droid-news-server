import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// AAA-grade Personalised Content Recommendation Engine
/// Built for Bangladeshi users — bilingual (EN + বাংলা), culturally-aware
///
/// Algorithm:
///  • Collaborative-filtering proxy via category affinity scoring
///  • Recency-weighted read history decay
///  • Time-of-day content boosting (morning news vs evening entertainment)
///  • Language preference learning
///  • Diversity injection to prevent filter-bubble effect
/// ─────────────────────────────────────────────────────────────────────────────
class MLRecommender {
  MLRecommender._();
  static final MLRecommender instance = MLRecommender._();

  // ── Persistence keys ───────────────────────────────────────────────────────
  static const _kReadHistory = 'ml_v2_read_history';
  static const _kCategoryPrefs = 'ml_v2_category_prefs';
  static const _kLangPref = 'ml_v2_lang_pref';
  static const _kSessionData = 'ml_v2_session_data';

  // ── Limits ─────────────────────────────────────────────────────────────────
  static const _maxHistorySize = 200;
  static const _diversityFactor = 0.25; // 25% diversity injection

  // ── State ──────────────────────────────────────────────────────────────────
  List<_ReadEntry> _readHistory = [];
  Map<String, double> _categoryAffinities = {};
  Map<String, double> _tagAffinities = {};
  _LanguagePreference _langPref = _LanguagePreference.auto;
  int _totalReadingMinutes = 0;
  int _sessionArticleCount = 0;
  bool _isInitialized = false;

  // BD-specific prime time mapping (hour → boosted categories)
  static const _bdPrimeTimeBoosts = <int, List<String>>{
    7: ['politics', 'economy', 'bangladesh'],    // Morning commute
    8: ['politics', 'economy', 'bangladesh'],
    12: ['cricket', 'sports', 'entertainment'],  // Lunch break
    13: ['cricket', 'sports', 'entertainment'],
    17: ['bangladesh', 'international', 'economy'], // Afternoon
    18: ['cricket', 'entertainment', 'sports'],  // Evening
    19: ['cricket', 'entertainment', 'sports'],
    20: ['religion', 'entertainment', 'health'], // Night wind-down
    21: ['religion', 'entertainment', 'health'],
  };

  // ── Initialisation ─────────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        _loadReadHistory(prefs),
        _loadCategoryAffinities(prefs),
        _loadLanguagePreference(prefs),
        _loadSessionData(prefs),
      ]);
      _isInitialized = true;
      debugLog(
        '✅ MLRecommender ready — ${_readHistory.length} articles, '
        'lang: ${_langPref.name}',
      );
    } catch (e) {
      debugLog('❌ MLRecommender init failed: $e');
    }
  }

  // ── Core tracking ──────────────────────────────────────────────────────────

  /// Track a read article with rich metadata for better recommendations
  Future<void> trackArticleRead({
    required String articleUrl,
    required String title,
    String? category,
    List<String>? tags,
    int readDurationSeconds = 0,
    bool isInBangla = false,
  }) async {
    if (!_isInitialized) await initialize();

    // Update language preference learning
    _updateLanguagePref(isInBangla);

    // Avoid duplicate consecutive reads; allow re-read after 7 days
    final existing = _readHistory
        .where((e) => e.url == articleUrl)
        .firstOrNull;
    if (existing != null) {
      final ageHours = DateTime.now().difference(existing.readAt).inHours;
      if (ageHours < 168) return; // De-dupe within 7 days
    }

    _readHistory.insert(
      0,
      _ReadEntry(
        url: articleUrl,
        title: title,
        category: category,
        tags: tags ?? [],
        readAt: DateTime.now(),
        durationSeconds: readDurationSeconds,
        isBangla: isInBangla,
      ),
    );

    // Trim history
    if (_readHistory.length > _maxHistorySize) {
      _readHistory = _readHistory.sublist(0, _maxHistorySize);
    }

    // Update affinity signals
    if (category != null) {
      _updateCategoryAffinity(category, readDurationSeconds);
    }
    for (final tag in (tags ?? [])) {
      _tagAffinities[tag] = (_tagAffinities[tag] ?? 0) + 1;
    }

    _totalReadingMinutes += (readDurationSeconds ~/ 60);
    _sessionArticleCount++;

    await _persist();
  }

  // ── Recommendation scoring ─────────────────────────────────────────────────

  /// Compute a composite recommendation score [0.0–1.0] for a given article
  RecommendationScore getRecommendationScore({
    required String url,
    required String title,
    String? category,
    List<String>? tags,
    DateTime? publishedAt,
    bool isBangla = false,
  }) {
    if (!_isInitialized) {
      return const RecommendationScore(
        score: 0.5,
        reason: RecommendReason.neutral,
        boost: [],
      );
    }

    var score = 0.4; // base
    final boostReasons = <String>[];

    // ── 1. Already-read penalty ──────────────────────────────────────────────
    final alreadyRead = _readHistory.any((e) => e.url == url);
    if (alreadyRead) {
      score -= 0.35;
    } else {
      score += 0.05;
    }

    // ── 2. Category affinity (recency-weighted) ──────────────────────────────
    if (category != null && _categoryAffinities.containsKey(category)) {
      final affinity = _categoryAffinities[category]!;
      final categoryBoost = 0.35 * affinity;
      score += categoryBoost;
      if (categoryBoost > 0.15) {
        boostReasons.add('আপনার পছন্দের বিভাগ'); // "Your preferred category"
      }
    }

    // ── 3. Tag overlap ───────────────────────────────────────────────────────
    if (tags != null && tags.isNotEmpty) {
      var tagScore = 0.0;
      for (final tag in tags) {
        if (_tagAffinities.containsKey(tag)) {
          tagScore += _tagAffinities[tag]! * 0.02;
        }
      }
      score += math.min(0.15, tagScore);
    }

    // ── 4. Freshness bonus ───────────────────────────────────────────────────
    if (publishedAt != null) {
      final ageHours = DateTime.now().difference(publishedAt).inHours;
      if (ageHours < 3) {
        score += 0.12;
        boostReasons.add('সদ্য প্রকাশিত'); // "Just published"
      } else if (ageHours < 24) {
        score += 0.06;
      }
    }

    // ── 5. Time-of-day prime-time boost ─────────────────────────────────────
    final currentHour = DateTime.now().hour;
    final primeCategories = _bdPrimeTimeBoosts[currentHour];
    if (category != null &&
        primeCategories != null &&
        primeCategories.contains(category)) {
      score += 0.08;
      boostReasons.add('এখন ট্রেন্ডিং'); // "Trending now"
    }

    // ── 6. Language alignment bonus ──────────────────────────────────────────
    if (_langPref == _LanguagePreference.bangla && isBangla) {
      score += 0.07;
    } else if (_langPref == _LanguagePreference.english && !isBangla) {
      score += 0.07;
    }

    // ── 7. Diversity injection (prevent same-category monopoly) ─────────────
    score = _applyDiversityFactor(score, category);

    final clamped = score.clamp(0.0, 1.0);

    final reason = clamped >= 0.75
        ? RecommendReason.highlyRelevant
        : clamped >= 0.55
            ? RecommendReason.relevant
            : clamped >= 0.4
                ? RecommendReason.neutral
                : RecommendReason.lowPriority;

    return RecommendationScore(
      score: clamped,
      reason: reason,
      boost: boostReasons,
    );
  }

  // ── Category & preference insights ────────────────────────────────────────

  /// Top N recommended categories (Bangladesh-culturally weighted)
  List<CategoryPreference> getRecommendedCategories({int limit = 5}) {
    if (_categoryAffinities.isEmpty) return _defaultBdCategories(limit);

    final sorted = _categoryAffinities.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(limit).map((e) {
      return CategoryPreference(
        categoryId: e.key,
        affinityScore: e.value,
        isTopPick: e.value > 0.8,
      );
    }).toList();
  }

  /// User reading stats (for profile/settings screen)
  UserReadingStats getReadingStats() {
    final topCategories = getRecommendedCategories(limit: 3);
    final banglaCount = _readHistory.where((e) => e.isBangla).length;
    final totalCount = _readHistory.length;

    return UserReadingStats(
      totalArticlesRead: totalCount,
      totalReadingMinutes: _totalReadingMinutes,
      topCategories: topCategories,
      langPreference: _langPref.name,
      banglaRatio: totalCount > 0 ? banglaCount / totalCount : 0.5,
      averageSessionArticles: _sessionArticleCount,
    );
  }

  /// Detect and return the user's probable reading language
  String get preferredLanguage {
    switch (_langPref) {
      case _LanguagePreference.bangla:
        return 'bn';
      case _LanguagePreference.english:
        return 'en';
      case _LanguagePreference.auto:
        return 'bn'; // Default to Bangla for BD users
    }
  }

  List<String> getReadHistory({int limit = 20}) =>
      _readHistory.take(limit).map((e) => e.url).toList();

  bool hasReadArticle(String url) => _readHistory.any((e) => e.url == url);

  Future<void> clearHistory() async {
    _readHistory.clear();
    _categoryAffinities.clear();
    _tagAffinities.clear();
    _langPref = _LanguagePreference.auto;
    _totalReadingMinutes = 0;
    _sessionArticleCount = 0;
    await _persist();
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  void _updateCategoryAffinity(String category, int durationSeconds) {
    // Duration-weighted: longer reads = stronger affinity
    final durationWeight = math.min(1.0, durationSeconds / 300); // cap at 5min
    final increment = 0.1 + (0.2 * durationWeight);

    _categoryAffinities[category] =
        ((_categoryAffinities[category] ?? 0) + increment).clamp(0.0, 1.0);

    // Decay all other categories slightly (simulate forgetting)
    for (final key in _categoryAffinities.keys.toList()) {
      if (key != category) {
        _categoryAffinities[key] =
            (_categoryAffinities[key]! * 0.99).clamp(0.0, 1.0);
      }
    }
  }

  void _updateLanguagePref(bool isBangla) {
    final banglaCount = _readHistory.where((e) => e.isBangla).length;
    final totalCount = _readHistory.length + 1;
    final banglaRatio = (banglaCount + (isBangla ? 1 : 0)) / totalCount;

    if (banglaRatio > 0.65) {
      _langPref = _LanguagePreference.bangla;
    } else if (banglaRatio < 0.35) {
      _langPref = _LanguagePreference.english;
    } else {
      _langPref = _LanguagePreference.auto;
    }
  }

  double _applyDiversityFactor(double score, String? category) {
    if (category == null || _categoryAffinities.isEmpty) return score;
    final recentCategories = _readHistory
        .take(5)
        .map((e) => e.category)
        .where((c) => c != null)
        .cast<String>()
        .toList();
    final recentSameCategory = recentCategories.where((c) => c == category).length;
    if (recentSameCategory >= 3) {
      // User has seen 3+ of the same category recently → inject diversity
      score -= _diversityFactor * (recentSameCategory - 2) * 0.1;
    }
    return score;
  }

  List<CategoryPreference> _defaultBdCategories(int limit) {
    // Default priority for new Bangladeshi users (culturally calibrated)
    final defaults = [
      'bangladesh', 'cricket', 'politics', 'economy', 'international',
    ];
    return defaults
        .take(limit)
        .map((id) => CategoryPreference(
              categoryId: id,
              affinityScore: 0.5,
              isTopPick: false,
            ))
        .toList();
  }

  // ── Persistence ────────────────────────────────────────────────────────────

  Future<void> _loadReadHistory(SharedPreferences prefs) async {
    final json_ = prefs.getString(_kReadHistory);
    if (json_ != null) {
      final list = json.decode(json_) as List;
      _readHistory = list
          .map((e) => _ReadEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    }
  }

  Future<void> _loadCategoryAffinities(SharedPreferences prefs) async {
    final json_ = prefs.getString(_kCategoryPrefs);
    if (json_ != null) {
      _categoryAffinities =
          Map<String, double>.from(json.decode(json_));
    }
  }

  Future<void> _loadLanguagePreference(SharedPreferences prefs) async {
    final langStr = prefs.getString(_kLangPref);
    _langPref = _LanguagePreference.values.firstWhere(
      (e) => e.name == langStr,
      orElse: () => _LanguagePreference.auto,
    );
  }

  Future<void> _loadSessionData(SharedPreferences prefs) async {
    final json_ = prefs.getString(_kSessionData);
    if (json_ != null) {
      final data = json.decode(json_) as Map<String, dynamic>;
      _totalReadingMinutes = data['total_reading_minutes'] as int? ?? 0;
      _sessionArticleCount = data['session_count'] as int? ?? 0;
      final tagJson = data['tag_affinities'];
      if (tagJson != null) {
        _tagAffinities = Map<String, double>.from(tagJson);
      }
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.setString(
          _kReadHistory,
          json.encode(_readHistory.map((e) => e.toJson()).toList()),
        ),
        prefs.setString(_kCategoryPrefs, json.encode(_categoryAffinities)),
        prefs.setString(_kLangPref, _langPref.name),
        prefs.setString(
          _kSessionData,
          json.encode({
            'total_reading_minutes': _totalReadingMinutes,
            'session_count': _sessionArticleCount,
            'tag_affinities': _tagAffinities,
          }),
        ),
      ]);
    } catch (e) {
      debugLog('❌ MLRecommender persist failed: $e');
    }
  }

  void debugLog(String msg) {
    if (kDebugMode) debugPrint(msg);
  }
}

// ── Supporting models ─────────────────────────────────────────────────────────

enum _LanguagePreference { auto, bangla, english }
enum RecommendReason { highlyRelevant, relevant, neutral, lowPriority }

class _ReadEntry {

  factory _ReadEntry.fromJson(Map<String, dynamic> json) => _ReadEntry(
        url: json['url'] as String,
        title: json['title'] as String? ?? '',
        category: json['category'] as String?,
        tags: List<String>.from(json['tags'] as List? ?? []),
        readAt: DateTime.parse(json['read_at'] as String),
        durationSeconds: json['duration_s'] as int? ?? 0,
        isBangla: json['is_bangla'] as bool? ?? false,
      );
  _ReadEntry({
    required this.url,
    required this.title,
    required this.readAt, this.category,
    this.tags = const [],
    this.durationSeconds = 0,
    this.isBangla = false,
  });

  final String url;
  final String title;
  final String? category;
  final List<String> tags;
  final DateTime readAt;
  final int durationSeconds;
  final bool isBangla;

  Map<String, dynamic> toJson() => {
        'url': url,
        'title': title,
        'category': category,
        'tags': tags,
        'read_at': readAt.toIso8601String(),
        'duration_s': durationSeconds,
        'is_bangla': isBangla,
      };
}

class RecommendationScore {
  const RecommendationScore({
    required this.score,
    required this.reason,
    required this.boost,
  });

  final double score; // 0.0–1.0
  final RecommendReason reason;
  final List<String> boost; // Human-readable Bengali boost labels

  bool get isRecommended => score >= 0.55;
  String get scoreLabel {
    if (score >= 0.75) return 'অত্যন্ত প্রাসঙ্গিক';
    if (score >= 0.55) return 'প্রাসঙ্গিক';
    if (score >= 0.4) return 'সাধারণ';
    return 'কম প্রাসঙ্গিক';
  }
}

class CategoryPreference {
  const CategoryPreference({
    required this.categoryId,
    required this.affinityScore,
    required this.isTopPick,
  });

  final String categoryId;
  final double affinityScore;
  final bool isTopPick;
}

class UserReadingStats {
  const UserReadingStats({
    required this.totalArticlesRead,
    required this.totalReadingMinutes,
    required this.topCategories,
    required this.langPreference,
    required this.banglaRatio,
    required this.averageSessionArticles,
  });

  final int totalArticlesRead;
  final int totalReadingMinutes;
  final List<CategoryPreference> topCategories;
  final String langPreference;
  final double banglaRatio;
  final int averageSessionArticles;

  String get formattedReadingTime {
    if (totalReadingMinutes < 60) return '$totalReadingMinutes মিনিট';
    final hours = totalReadingMinutes ~/ 60;
    final mins = totalReadingMinutes % 60;
    return '$hours ঘণ্টা $mins মিনিট';
  }
}
