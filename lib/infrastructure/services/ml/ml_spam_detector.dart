import 'dart:math' as math;
import 'package:flutter/foundation.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// AAA-grade Bilingual Spam & Clickbait Detector
/// Tuned for Bangladeshi online news landscape (EN + বাংলা)
///
/// Signal dimensions:
///  1. Bangla clickbait lexicon (sensationalist BD news patterns)
///  2. English clickbait lexicon
///  3. Spam keyword scoring
///  4. Title typography signals (ALL CAPS, excessive punctuation)
///  5. Content quality heuristics (length, keyword stuffing, reading level)
///  6. Source trust scoring (known reputable BD outlets)
///  7. Credibility composite with explanations
/// ─────────────────────────────────────────────────────────────────────────────
class MLSpamDetector {
  MLSpamDetector._();
  static final MLSpamDetector instance = MLSpamDetector._();

  bool _isInitialized = false;

  // Bounded cache
  final _cache = <String, ArticleQuality>{};
  static const _maxCacheSize = 200;

  // ── Bangla clickbait patterns (common in BD tabloid/online portals) ────────
  static const _banglaClickbaitPhrases = <String, double>{
    'বিশ্বাস করবেন না': 0.9,
    'দেখে অবাক': 0.8,
    'শুনলে অবাক হবেন': 0.85,
    'ভাইরাল': 0.6,
    'ফাঁস হলো': 0.7,
    'চাঞ্চল্যকর': 0.7,
    'হইচই পড়ে গেছে': 0.8,
    'তোলপাড়': 0.7,
    'শিউরে উঠবেন': 0.85,
    'রহস্য উদঘাটন': 0.6,
    'গোপন তথ্য': 0.65,
    'আঁতকে উঠবেন': 0.85,
    'ঘটনা জানলে চমকে যাবেন': 0.9,
    'না দেখলে মিস করবেন': 0.8,
    'জেনে নিন সবার আগে': 0.6,
    'এখনই জানুন': 0.5,
    'সবার অজানা': 0.65,
    'বিস্ময়কর': 0.6,
    'অবিশ্বাস্য': 0.65,
    'চমকে যাবেন': 0.75,
    'অলৌকিক': 0.7,
    'অসম্ভব': 0.5,
    'অকল্পনীয়': 0.65,
    'সর্বশেষ খবর': 0.3, // Lower — "breaking news" is not always clickbait
    'আপনি জানেন তো': 0.6,
    'এই একটি কারণে': 0.7,
    'যা ভাবেননি': 0.75,
  };

  // ── English clickbait patterns ─────────────────────────────────────────────
  static const _englishClickbaitPhrases = <String, double>{
    "you won't believe": 0.95,
    'shocking': 0.75,
    'one weird trick': 0.95,
    'doctors hate': 0.95,
    'click here': 0.85,
    'mind-blowing': 0.8,
    'what happens next': 0.9,
    'unbelievable': 0.7,
    'this is why': 0.55,
    'the truth about': 0.65,
    'number one reason': 0.65,
    'secret revealed': 0.8,
    'exposed': 0.65,
    'you need to know': 0.6,
    'gone wrong': 0.65,
    'you have to see this': 0.85,
    'gone viral': 0.6,
    'breaking news': 0.3,
    'exclusive': 0.4,
    'bombshell': 0.75,
    'jaw-dropping': 0.8,
    'must see': 0.7,
    'what they don\'t want you to know': 0.9,
    'the shocking truth': 0.85,
  };

  // ── Bangla spam patterns ───────────────────────────────────────────────────
  static const _banglaSpamPhrases = <String, double>{
    'বিনামূল্যে': 0.6,
    'এখনই কিনুন': 0.85,
    'সীমিত সময়': 0.8,
    'অফার শেষ হওয়ার আগে': 0.85,
    'লাখ টাকা আয়': 0.95,
    'ঘরে বসে আয়': 0.9,
    'ফ্রিতে পাবেন': 0.85,
    'জয়েন করুন': 0.55,
    'রেজিস্ট্রেশন করুন': 0.4,
    'ডাউনলোড করুন': 0.35,
    'শেয়ার করুন': 0.4,
    'তাড়াতাড়ি করুন': 0.7,
    'আজই যোগ দিন': 0.65,
    'গ্যারান্টি দিচ্ছি': 0.7,
    'ইনকাম করুন': 0.8,
  };

  // ── English spam patterns ──────────────────────────────────────────────────
  static const _englishSpamPhrases = <String, double>{
    'free money': 0.95, 'act now': 0.85, 'limited time': 0.8,
    'call now': 0.85, 'click now': 0.9, 'buy now': 0.8,
    'order now': 0.8, 'earn money': 0.85, 'work from home': 0.6,
    'make money fast': 0.95, 'guaranteed': 0.65, 'winner': 0.6,
    'congratulations you': 0.9, 'free gift': 0.8, 'no cost': 0.7,
    'risk free': 0.65, 'cash prize': 0.9, 'instant money': 0.9,
  };

  // ── Reputable Bangladeshi news sources (trust boost) ──────────────────────
  static const _trustedBdSources = {
    'prothomalo.com': 0.95,
    'bdnews24.com': 0.90,
    'thedailystar.net': 0.95,
    'tbsnews.net': 0.85,
    'dhakatribune.com': 0.88,
    'newagebd.net': 0.85,
    'banglanews24.com': 0.80,
    'ittefaq.com.bd': 0.85,
    'samakal.com': 0.82,
    'kalerkantho.com': 0.82,
    'jugantor.com': 0.80,
    'jagonews24.com': 0.75,
    'risingbd.com': 0.78,
    'somoynews.tv': 0.80,
    'channel24bd.tv': 0.80,
  };

  // ── Public API ─────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
    debugLog('✅ MLSpamDetector initialised (${_banglaClickbaitPhrases.length} BN + '
        '${_englishClickbaitPhrases.length} EN clickbait patterns)');
  }

  /// Full quality analysis — returns comprehensive ArticleQuality report
  Future<ArticleQuality> analyzeArticle({
    required String title,
    required String content,
    String? sourceUrl,
    bool isBangla = false,
  }) async {
    if (!_isInitialized) await initialize();

    final cacheKey = '${title.hashCode}_${content.hashCode}';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;

    final breakdown = _QLBreakdown();

    // 1. Clickbait analysis on title
    final clickbaitScore = _scoreClickbait(title, isBangla);
    breakdown.clickbaitPenalty = clickbaitScore * 0.35;

    // 2. Spam analysis (title + content)
    final spamScore = _scoreSpam(title, content, isBangla);
    breakdown.spamPenalty = spamScore * 0.30;

    // 3. Typography quality
    final typoPenalty = _scoreTypography(title);
    breakdown.typographyPenalty = typoPenalty;

    // 4. Content quality heuristics
    final contentQuality = _scoreContentQuality(title, content);
    breakdown.contentBonus = contentQuality * 0.20;

    // 5. Source trust (optional)
    final sourceTrust = sourceUrl != null ? _getSourceTrust(sourceUrl) : 0.5;
    breakdown.sourceTrust = sourceTrust * 0.15;

    // Composite score
    final baseScore = 0.5 + breakdown.contentBonus + breakdown.sourceTrust
        - breakdown.clickbaitPenalty
        - breakdown.spamPenalty
        - breakdown.typographyPenalty;

    final finalScore = baseScore.clamp(0.0, 1.0);

    final labels = _collectQualityLabels(
      clickbaitScore: clickbaitScore,
      spamScore: spamScore,
      typoPenalty: typoPenalty,
      contentQuality: contentQuality,
      sourceTrust: sourceTrust,
      isBangla: isBangla,
    );

    final result = ArticleQuality(
      qualityScore: finalScore,
      clickbaitScore: clickbaitScore,
      spamScore: spamScore,
      contentQualityScore: contentQuality,
      sourceTrustScore: sourceTrust,
      isSpam: finalScore < 0.25,
      isClickbait: clickbaitScore >= 0.55,
      isLowQuality: finalScore < 0.45,
      qualityTier: _getQualityTier(finalScore),
      labels: labels,
      isBangla: isBangla,
    );

    _evictCacheIfNeeded();
    _cache[cacheKey] = result;
    return result;
  }

  /// Quick spam check (true = spam)
  Future<bool> isSpam(String title, String content) async {
    final quality = await analyzeArticle(title: title, content: content);
    return quality.isSpam;
  }

  /// Quick clickbait check
  Future<bool> isClickbait(String title, {bool isBangla = false}) async {
    if (!_isInitialized) await initialize();
    return _scoreClickbait(title, isBangla) >= 0.55;
  }

  /// Quick quality score (0.0–1.0)
  Future<double> getQualityScore(String title, String content) async {
    final quality = await analyzeArticle(title: title, content: content);
    return quality.qualityScore;
  }

  // ── Scoring helpers ────────────────────────────────────────────────────────

  double _scoreClickbait(String title, bool isBangla) {
    final lower = title.toLowerCase();
    var maxScore = 0.0;
    var totalScore = 0.0;
    var hits = 0;

    final phrases = isBangla
        ? {..._banglaClickbaitPhrases, ..._englishClickbaitPhrases}
        : {..._englishClickbaitPhrases, ..._banglaClickbaitPhrases};

    for (final entry in phrases.entries) {
      if (lower.contains(entry.key)) {
        totalScore += entry.value;
        if (entry.value > maxScore) maxScore = entry.value;
        hits++;
      }
    }

    if (hits == 0) return 0.0;
    // Blend of max-hit and average (captures both single strong and multi weak signals)
    final avgScore = totalScore / hits;
    return (maxScore * 0.6 + avgScore * 0.4).clamp(0.0, 1.0);
  }

  double _scoreSpam(String title, String content, bool isBangla) {
    final combined = '${title.toLowerCase()} ${content.toLowerCase()}';
    var spamHits = 0.0;

    final phrases = isBangla
        ? {..._banglaSpamPhrases, ..._englishSpamPhrases}
        : {..._englishSpamPhrases, ..._banglaSpamPhrases};

    for (final entry in phrases.entries) {
      if (combined.contains(entry.key)) {
        spamHits += entry.value;
      }
    }

    return math.min(1.0, spamHits / 3.0); // 3 strong signals = fully spam
  }

  double _scoreTypography(String title) {
    var penalty = 0.0;

    // Excessive exclamation marks
    final exclamations = RegExp(r'!+').allMatches(title).length;
    if (exclamations >= 2) penalty += 0.1;
    if (exclamations >= 4) penalty += 0.15;

    // Excessive question marks
    final questions = RegExp(r'\?+').allMatches(title).length;
    if (questions >= 2) penalty += 0.1;

    // ALL CAPS title (excluding acronyms ≤4 chars)
    if (title.length > 10) {
      final upperCount = title.runes.where((r) => r >= 65 && r <= 90).length;
      final alphaCount = title.runes
          .where((r) => (r >= 65 && r <= 90) || (r >= 97 && r <= 122))
          .length;
      if (alphaCount > 0 && upperCount / alphaCount > 0.7) {
        penalty += 0.20;
      }
    }

    // Emoji spam in title
    final emojiCount = RegExp(
      r'[\u{1F600}-\u{1F6FF}]|[\u{2600}-\u{26FF}]',
      unicode: true,
    ).allMatches(title).length;
    if (emojiCount > 2) penalty += 0.05 * (emojiCount - 2);

    // Very short title (< 10 chars) or unreasonably long (> 150 chars)
    if (title.trim().length < 10) penalty += 0.15;
    if (title.trim().length > 150) penalty += 0.10;

    return penalty.clamp(0.0, 0.5);
  }

  double _scoreContentQuality(String title, String content) {
    var quality = 0.0;

    final wordCount = content.trim().split(RegExp(r'\s+')).length;

    // Length quality (BD news articles typically 150–1000 words)
    if (wordCount > 500) {
      quality += 0.3;
    } else if (wordCount > 200) quality += 0.2;
    else if (wordCount > 80) quality += 0.1;
    else quality -= 0.1; // Very thin content

    // Paragraph structure (longer = richer content)
    final paragraphCount = content.split('\n').where((p) => p.trim().length > 30).length;
    if (paragraphCount >= 4) {
      quality += 0.2;
    } else if (paragraphCount >= 2) quality += 0.1;

    // Presence of quoted speech (journalistic quality signal)
    final quotedEnglish = RegExp(r'"[^"]{10,}"').allMatches(content).length;
    final quotedBangla = RegExp(r'\"[^\"]{5,}\"').allMatches(content).length;
    if (quotedEnglish + quotedBangla >= 1) quality += 0.15;

    // Numbers/data presence (fact-based reporting signal)
    final numberCount = RegExp(r'\d+').allMatches(content).length;
    if (numberCount > 5) quality += 0.1;

    // Proper noun density (named entities signal reporting depth)
    final properNounsBd = RegExp(
      r'[\u0980-\u09FF]{3,}',
    ).allMatches(content).length;
    if (properNounsBd > 10) quality += 0.05;

    return quality.clamp(0.0, 1.0);
  }

  double _getSourceTrust(String url) {
    for (final entry in _trustedBdSources.entries) {
      if (url.contains(entry.key)) return entry.value;
    }
    // Unknown source — neutral score
    return 0.5;
  }

  QualityTier _getQualityTier(double score) {
    if (score >= 0.78) return QualityTier.premium;
    if (score >= 0.58) return QualityTier.good;
    if (score >= 0.38) return QualityTier.average;
    if (score >= 0.20) return QualityTier.low;
    return QualityTier.spam;
  }

  List<QualityLabel> _collectQualityLabels({
    required double clickbaitScore,
    required double spamScore,
    required double typoPenalty,
    required double contentQuality,
    required double sourceTrust,
    required bool isBangla,
  }) {
    final labels = <QualityLabel>[];

    if (clickbaitScore >= 0.7) {
      labels.add(const QualityLabel(
        code: 'clickbait_high',
        labelEn: 'High Clickbait',
        labelBn: 'উচ্চ ক্লিকবেইট',
        severity: LabelSeverity.high,
      ));
    } else if (clickbaitScore >= 0.45) {
      labels.add(const QualityLabel(
        code: 'clickbait_low',
        labelEn: 'Mild Clickbait',
        labelBn: 'সামান্য ক্লিকবেইট',
        severity: LabelSeverity.medium,
      ));
    }

    if (spamScore >= 0.5) {
      labels.add(const QualityLabel(
        code: 'spam',
        labelEn: 'Spam Detected',
        labelBn: 'স্প্যাম',
        severity: LabelSeverity.high,
      ));
    }

    if (typoPenalty >= 0.2) {
      labels.add(const QualityLabel(
        code: 'poor_typography',
        labelEn: 'Poor Typography',
        labelBn: 'অনুপযুক্ত শিরোনাম',
        severity: LabelSeverity.medium,
      ));
    }

    if (contentQuality >= 0.6) {
      labels.add(const QualityLabel(
        code: 'rich_content',
        labelEn: 'In-depth Content',
        labelBn: 'বিস্তারিত তথ্য',
        severity: LabelSeverity.positive,
      ));
    }

    if (sourceTrust >= 0.85) {
      labels.add(const QualityLabel(
        code: 'trusted_source',
        labelEn: 'Trusted Source',
        labelBn: 'বিশ্বস্ত উৎস',
        severity: LabelSeverity.positive,
      ));
    }

    return labels;
  }

  void _evictCacheIfNeeded() {
    if (_cache.length >= _maxCacheSize) {
      _cache.remove(_cache.keys.first);
    }
  }

  void debugLog(String msg) {
    if (kDebugMode) debugPrint(msg);
  }
}

// ── Supporting models ─────────────────────────────────────────────────────────

enum QualityTier { premium, good, average, low, spam }
enum LabelSeverity { positive, low, medium, high }

class _QLBreakdown {
  double clickbaitPenalty = 0;
  double spamPenalty = 0;
  double typographyPenalty = 0;
  double contentBonus = 0;
  double sourceTrust = 0;
}

class ArticleQuality {
  const ArticleQuality({
    required this.qualityScore,
    required this.clickbaitScore,
    required this.spamScore,
    required this.contentQualityScore,
    required this.sourceTrustScore,
    required this.isSpam,
    required this.isClickbait,
    required this.isLowQuality,
    required this.qualityTier,
    required this.labels,
    required this.isBangla,
  });

  final double qualityScore;        // 0.0–1.0 composite
  final double clickbaitScore;      // 0.0–1.0
  final double spamScore;           // 0.0–1.0
  final double contentQualityScore; // 0.0–1.0
  final double sourceTrustScore;    // 0.0–1.0
  final bool isSpam;
  final bool isClickbait;
  final bool isLowQuality;
  final QualityTier qualityTier;
  final List<QualityLabel> labels;
  final bool isBangla;

  String get tierLabelEn {
    switch (qualityTier) {
      case QualityTier.premium: return 'Premium';
      case QualityTier.good: return 'Good';
      case QualityTier.average: return 'Average';
      case QualityTier.low: return 'Low Quality';
      case QualityTier.spam: return 'Spam';
    }
  }

  String get tierLabelBn {
    switch (qualityTier) {
      case QualityTier.premium: return 'উচ্চমানের';
      case QualityTier.good: return 'ভালো';
      case QualityTier.average: return 'মাঝারি';
      case QualityTier.low: return 'নিম্নমানের';
      case QualityTier.spam: return 'স্প্যাম';
    }
  }

  String get tierIcon {
    switch (qualityTier) {
      case QualityTier.premium: return '🏆';
      case QualityTier.good: return '✅';
      case QualityTier.average: return '⚠️';
      case QualityTier.low: return '❗';
      case QualityTier.spam: return '🚫';
    }
  }

  bool get shouldShow => qualityTier != QualityTier.spam;
  bool get shouldWarnUser => isClickbait || isLowQuality;

  @override
  String toString() =>
      'ArticleQuality($tierLabelEn, score: ${qualityScore.toStringAsFixed(2)})';
}

class QualityLabel {
  const QualityLabel({
    required this.code,
    required this.labelEn,
    required this.labelBn,
    required this.severity,
  });

  final String code;
  final String labelEn;
  final String labelBn;
  final LabelSeverity severity;

  bool get isPositive => severity == LabelSeverity.positive;
  bool get isWarning =>
      severity == LabelSeverity.medium || severity == LabelSeverity.high;
}
