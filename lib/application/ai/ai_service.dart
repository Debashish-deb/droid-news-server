import 'package:bdnewsreader/domain/services/ai_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'package:bdnewsreader/domain/services/ai_service.dart';

class AIServiceImpl implements AIService {
  @override
  Future<String> summarizeArticle(String content) async {
    return summarize(content);
  }

  @override
  Future<String> summarize(
    String content, {
    SummaryType type = SummaryType.detailed,
  }) async {
    if (content.isEmpty) return '';

    final sentences = content
        .replaceAll(RegExp(r'\s+'), ' ')
        .split(RegExp(r'(?<=[.!?])\s+'))
        .where((s) => s.length > 20)
        .toList();

    if (sentences.isEmpty) return '';
    if (sentences.length <= 3) return content;

    switch (type) {
      case SummaryType.tldr:
        return _generateTLDR(sentences);
      case SummaryType.keyPoints:
        return _generateKeyPoints(sentences);
      case SummaryType.detailed:
        return _generateDetailedSummary(sentences);
    }
  }

  String _generateTLDR(List<String> sentences) {
    return "TL;DR: ${sentences.first}";
  }

  String _generateKeyPoints(List<String> sentences) {
    final scored = _scoreSentences(sentences);
    final topSentences = scored.take(4).map((e) => e.key).toList();
    topSentences.sort(
      (a, b) => sentences.indexOf(a).compareTo(sentences.indexOf(b)),
    );

    final buffer = StringBuffer();
    for (final s in topSentences) {
      buffer.writeln("• $s");
    }
    return buffer.toString().trim();
  }

  String _generateDetailedSummary(List<String> sentences) {
    final int targetCount = (sentences.length * 0.3).ceil().clamp(3, 8);
    final scored = _scoreSentences(sentences);
    final topSentences = scored.take(targetCount).map((e) => e.key).toList();
    topSentences.sort(
      (a, b) => sentences.indexOf(a).compareTo(sentences.indexOf(b)),
    );
    return topSentences.join(' ');
  }

  List<MapEntry<String, double>> _scoreSentences(List<String> sentences) {
    final scores = <String, double>{};
    for (int i = 0; i < sentences.length; i++) {
      final s = sentences[i];
      double score = 0;
      if (i == 0) {
        score += 2.0;
      } else if (i < 5) {
        score += 1.0;
      }
      if (s.length > 50 && s.length < 150) score += 0.5;
      scores[s] = score;
    }
    final sorted = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted;
  }

  @override
  Future<String> explainComplexTerm(String term, String context) async {
    return "Definition for '$term':\nA key concept found in the text. This term typically refers to specific entities, actions, or phenomena described in the surrounding context.";
  }

  @override
  Future<List<String>> generateTags(String content) async {
    if (content.isEmpty) return [];
    final topics = extractTrendingTopics([
      {'title': content, 'description': '', 'source': '', 'url': ''},
    ]);
    return topics.take(5).map((t) => t.label).toList();
  }

  static const _stopWordsEn = <String>{
    'the',
    'and',
    'is',
    'in',
    'to',
    'of',
    'a',
    'for',
    'on',
    'with',
    'as',
    'this',
    'that',
    'are',
    'it',
    'by',
    'an',
    'be',
    'at',
    'from',
    'but',
    'not',
    'or',
    'was',
    'were',
    'has',
    'had',
    'have',
    'been',
    'its',
    'will',
    'can',
    'may',
    'would',
    'could',
    'should',
    'do',
    'did',
    'does',
    'more',
    'than',
    'also',
    'after',
    'before',
    'about',
    'over',
    'under',
    'into',
    'most',
    'some',
    'their',
    'they',
    'them',
    'there',
    'here',
    'all',
    'any',
    'each',
    'every',
    'both',
    'few',
    'many',
    'much',
    'such',
    'other',
    'only',
    'very',
    'just',
    'even',
    'new',
    'first',
    'last',
    'next',
    'year',
    'years',
    'said',
    'says',
    'say',
    'news',
    'report',
    'reports',
    'reported',
    'one',
    'two',
    'three',
    'four',
    'five',
    'being',
    'who',
    'what',
    'when',
    'where',
    'how',
    'which',
    'while',
    'during',
    'between',
    'through',
    'still',
    'now',
    'out',
    'up',
    'no',
    'so',
    'if',
    'we',
    'our',
    'you',
    'your',
    'he',
    'she',
    'his',
    'her',
    'him',
    'my',
    'me',
    'i',
    'us',
    'per',
    'today',
    'latest',
    'breaking',
    'trending',
    'trend',
    'viral',
    'update',
    'updates',
    'read',
    'click',
    'watch',
  };

  static const _stopWordsBn = <String>{
    'এবং',
    'একটি',
    'একজন',
    'করে',
    'করা',
    'করেন',
    'হয়',
    'হয়েছে',
    'থেকে',
    'এই',
    'তার',
    'সেই',
    'যে',
    'কিন্তু',
    'আর',
    'ও',
    'পর',
    'জন্য',
    'সব',
    'নিয়ে',
    'দিয়ে',
    'বলে',
    'বলেন',
    'জানা',
    'জানান',
    'জানিয়েছেন',
    'গেছে',
    'রয়েছে',
    'হবে',
    'হলে',
    'পারে',
    'ছিল',
    'ছিলেন',
    'আছে',
    'আছেন',
  };

  // Phrases to exclude entirely from trending
  static const _stopPhrases = <String>{
    'breaking news',
    'latest news',
    'read more',
    'click here',
    'news update',
    'news today',
    'top stories',
    'just in',
    'trending now',
    'latest updates',
    'live updates',
    'trending news',
  };

  @override
  List<ExtractedTopic> extractTrendingTopics(
    List<Map<String, String>> articles,
  ) {
    if (articles.isEmpty) return [];

    // Phase 1: Extract candidate n-grams from all articles
    final ngramFrequency = <String, int>{};
    final ngramScore = <String, double>{};
    final ngramSources = <String, Set<String>>{};
    final ngramArticleUrls = <String, Set<String>>{};

    for (final article in articles) {
      final title = article['title'] ?? '';
      final desc = article['description'] ?? '';
      final source = article['source'] ?? '';
      final url = article['url'] ?? '';
      final category = (article['category'] ?? '').toLowerCase().trim();
      final tags = (article['tags'] ?? '').toLowerCase().trim();
      final publishedAt = DateTime.tryParse(article['publishedAt'] ?? '');
      final text = '$title $desc';
      final recencyBoost = _freshnessBoost(publishedAt);
      final categoryBoost = _feedCategoryBoost(category: category, tags: tags);
      final headlineBoost = _headlineTrendBoost(title);
      final mentionBoost = recencyBoost + categoryBoost + headlineBoost;

      // Extract n-grams from the ORIGINAL text (preserving case for proper noun detection)
      final candidates = _extractCandidateNgrams(text);

      for (final candidate in candidates) {
        final normalized = candidate.toLowerCase().trim();
        if (normalized.length < 3) continue;
        if (_stopPhrases.contains(normalized)) continue;

        ngramFrequency[normalized] = (ngramFrequency[normalized] ?? 0) + 1;
        ngramScore[normalized] =
            (ngramScore[normalized] ?? 0.0) + 1.0 + mentionBoost;
        ngramSources.putIfAbsent(normalized, () => <String>{}).add(source);
        if (url.isNotEmpty) {
          ngramArticleUrls.putIfAbsent(normalized, () => <String>{}).add(url);
        }
      }
    }

    // Phase 2: Filter and rank
    // Keep topics with either true repetition OR strong latest/trending signal.
    ngramFrequency.removeWhere((key, value) {
      final score = ngramScore[key] ?? value.toDouble();
      return value < 2 && score < 2.4;
    });

    // Phase 3: Deduplicate
    final deduped = _deduplicateTopics(ngramFrequency);

    // Phase 4: Sort by weighted score, then frequency.
    final sorted = deduped.entries.toList()
      ..sort((a, b) {
        final scoreA = ngramScore[a.key] ?? a.value.toDouble();
        final scoreB = ngramScore[b.key] ?? b.value.toDouble();
        final scoreCmp = scoreB.compareTo(scoreA);
        if (scoreCmp != 0) return scoreCmp;
        return b.value.compareTo(a.value);
      });

    return sorted.take(12).map((entry) {
      return ExtractedTopic(
        label: _titleCase(entry.key),
        frequency: entry.value,
        sourceArticleUrls: (ngramArticleUrls[entry.key] ?? <String>{}).toList(),
      );
    }).toList();
  }

  double _freshnessBoost(DateTime? publishedAt) {
    if (publishedAt == null) return 0.0;
    final hoursOld = DateTime.now().difference(publishedAt).inHours;
    if (hoursOld <= 3) return 0.85;
    if (hoursOld <= 12) return 0.65;
    if (hoursOld <= 24) return 0.45;
    if (hoursOld <= 48) return 0.2;
    return 0.0;
  }

  double _feedCategoryBoost({required String category, required String tags}) {
    double boost = 0.0;
    if (category.contains('latest')) boost += 0.45;
    if (category.contains('trending')) boost += 0.7;
    if (tags.contains('trending')) boost += 0.7;
    return boost;
  }

  double _headlineTrendBoost(String title) {
    final text = title.toLowerCase();
    if (text.contains('breaking') ||
        text.contains('just in') ||
        text.contains('viral')) {
      return 0.4;
    }
    return 0.0;
  }

  /// Extract bigrams and trigrams, plus single proper nouns.
  List<String> _extractCandidateNgrams(String text) {
    final candidates = <String>[];

    // Split into words, preserving original casing
    final words = text
        .replaceAll(RegExp(r'[^\w\s\u0980-\u09FF]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();

    // Single words: Only proper nouns (capitalized)
    for (int i = 0; i < words.length; i++) {
      final w = words[i];
      final lower = w.toLowerCase();

      // Skip stop words
      if (_stopWordsEn.contains(lower) || _stopWordsBn.contains(lower)) {
        continue;
      }

      // Bengali words (always include if > 3 chars)
      if (_isBengali(w) && w.length > 3) {
        candidates.add(w);
        continue;
      }

      // English proper nouns: capitalized and not first word
      if (i > 0 &&
          w.length > 2 &&
          w[0] == w[0].toUpperCase() &&
          w[0] != w[0].toLowerCase()) {
        if (!_stopWordsEn.contains(lower)) {
          candidates.add(lower);
        }
      }
    }

    // Bigrams
    for (int i = 0; i < words.length - 1; i++) {
      final w1 = words[i].toLowerCase();
      final w2 = words[i + 1].toLowerCase();
      if (_stopWordsEn.contains(w1) && _stopWordsEn.contains(w2)) continue;
      if (w1.length < 2 || w2.length < 2) continue;

      final bigram = '$w1 $w2';
      if (bigram.length >= 5 && !_stopPhrases.contains(bigram)) {
        candidates.add(bigram);
      }
    }

    // Trigrams
    for (int i = 0; i < words.length - 2; i++) {
      final w1 = words[i].toLowerCase();
      final w2 = words[i + 1].toLowerCase();
      final w3 = words[i + 2].toLowerCase();

      // At least 2 of 3 words should be non-stop-words
      int nonStop = 0;
      if (!_stopWordsEn.contains(w1)) nonStop++;
      if (!_stopWordsEn.contains(w2)) nonStop++;
      if (!_stopWordsEn.contains(w3)) nonStop++;
      if (nonStop < 2) continue;

      final trigram = '$w1 $w2 $w3';
      if (trigram.length >= 8) {
        candidates.add(trigram);
      }
    }

    return candidates;
  }

  bool _isBengali(String text) {
    return RegExp(r'[\u0980-\u09FF]').hasMatch(text);
  }

  Map<String, int> _deduplicateTopics(Map<String, int> topics) {
    final keys = topics.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    final result = <String, int>{};
    final absorbed = <String>{};

    for (final key in keys) {
      if (absorbed.contains(key)) continue;
      result[key] = topics[key]!;

      for (final other in keys) {
        if (other == key || absorbed.contains(other)) continue;
        if (key.contains(other) && topics[other]! <= topics[key]!) {
          absorbed.add(other);
        }
      }
    }

    return result;
  }

  String _titleCase(String input) {
    if (input.isEmpty) return input;
    if (_isBengali(input)) return input;
    return input
        .split(' ')
        .map((word) {
          if (word.isEmpty) return word;
          if (_stopWordsEn.contains(word) && word != input.split(' ').first) {
            return word;
          }
          return '${word[0].toUpperCase()}${word.substring(1)}';
        })
        .join(' ');
  }
}

final aiServiceProvider = Provider<AIService>((ref) => AIServiceImpl());
