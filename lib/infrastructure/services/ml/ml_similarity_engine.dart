import 'package:flutter/foundation.dart';

/// Similarity engine for finding related articles
class MLSimilarityEngine {
  MLSimilarityEngine._();
  static final MLSimilarityEngine instance = MLSimilarityEngine._();

  bool _isInitialized = false;
  final Map<String, List<String>> _articleIndex = {};

  /// Initialize similarity engine
  Future<void> initialize() async {
    if (_isInitialized) return;

    _isInitialized = true;
    if (kDebugMode) {
      debugPrint('✅ MLSimilarityEngine initialized');
    }
  }

  /// Index an article for similarity search
  Future<void> indexArticle(
    String url,
    String title,
    String content,
    String? category,
  ) async {
    if (!_isInitialized) await initialize();

    final keywords = _extractKeywords(title, content);
    _articleIndex[url] = keywords;
  }

  /// Find similar articles based on keyword overlap
  Future<List<Map<String, dynamic>>> findSimilar(
    String currentUrl,
    String title,
    String content,
    String? category, {
    int limit = 5,
  }) async {
    if (!_isInitialized) await initialize();

    final currentKeywords = _extractKeywords(title, content);
    final scores = <String, double>{};

    for (final entry in _articleIndex.entries) {
      final url = entry.key;
      if (url == currentUrl) continue;

      final keywords = entry.value;
      final similarity = _calculateSimilarity(currentKeywords, keywords);

      if (similarity > 0.1) {
        scores[url] = similarity;
      }
    }

    final sorted =
        scores.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return sorted
        .take(limit)
        .map((e) => {'url': e.key, 'similarity': e.value})
        .toList();
  }

  /// Calculate similarity between two keyword sets
  double _calculateSimilarity(List<String> keywords1, List<String> keywords2) {
    if (keywords1.isEmpty || keywords2.isEmpty) return 0.0;

    final set1 = keywords1.toSet();
    final set2 = keywords2.toSet();

    final intersection = set1.intersection(set2).length;
    final union = set1.union(set2).length;

    return union > 0 ? intersection / union : 0.0;
  }

  /// Extract keywords from text
  List<String> _extractKeywords(String title, String content) {
    final text = '$title $content'.toLowerCase();

    final stopWords = {
      'the',
      'a',
      'an',
      'and',
      'or',
      'but',
      'in',
      'on',
      'at',
      'to',
      'for',
      'of',
      'with',
      'by',
      'from',
      'as',
      'is',
      'was',
      'are',
      'been',
      'be',
      'this',
      'that',
      'these',
      'those',
      'it',
      'its',
      'which',
      'who',
      'when',
    };

    final words =
        text
            .split(RegExp(r'\W+'))
            .where((w) => w.length > 3 && !stopWords.contains(w))
            .toList();

    final frequency = <String, int>{};
    for (final word in words) {
      frequency[word] = (frequency[word] ?? 0) + 1;
    }

    final sorted =
        frequency.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(20).map((e) => e.key).toList();
  }

  /// Clear index
  void clearIndex() {
    _articleIndex.clear();
  }

  /// Get index stats
  Map<String, dynamic> getStats() {
    return {'indexed_articles': _articleIndex.length};
  }
}
