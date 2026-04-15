import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../domain/entities/news_article.dart';
import '../../../providers/news_providers.dart';
import '../../../../application/ai/ai_service.dart';
import '../../../providers/feature_providers.dart'
    show localLearningEngineProvider;

import '../../../../core/utils/source_logos.dart';

// ───────────────────────────────────────────────────────────────
//  DATA MODELS
// ───────────────────────────────────────────────────────────────

/// A publisher that covers a trending topic.
class PublisherHit {
  const PublisherHit({
    required this.name,
    required this.articleCount,
    this.logoPath,
  });
  final String name;
  final String? logoPath;
  final int articleCount;
}

/// A trending topic with metadata and publisher associations.
class TrendingTopic {
  const TrendingTopic({
    required this.label,
    required this.articleCount,
    this.publishers = const [],
  });
  final String label;
  final int articleCount;
  final List<PublisherHit> publishers;
}

// ───────────────────────────────────────────────────────────────
//  STATE
// ───────────────────────────────────────────────────────────────

class SearchIntelligenceState {
  SearchIntelligenceState({
    this.trendingTopics = const [],
    this.suggestedQueries = const [],
    this.isLoading = false,
    this.lastRefresh,
  });

  final List<TrendingTopic> trendingTopics;
  final List<String> suggestedQueries;
  final bool isLoading;
  final DateTime? lastRefresh;

  /// Convenience: flat list of labels for backward compatibility.
  List<String> get topicLabels => trendingTopics.map((t) => t.label).toList();

  List<String> filterSuggestions(String query, {int limit = 8}) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return suggestedQueries.take(limit).toList(growable: false);
    }
    return suggestedQueries
        .where((s) => s.toLowerCase().contains(normalized))
        .take(limit)
        .toList(growable: false);
  }

  SearchIntelligenceState copyWith({
    List<TrendingTopic>? trendingTopics,
    List<String>? suggestedQueries,
    bool? isLoading,
    DateTime? lastRefresh,
  }) {
    return SearchIntelligenceState(
      trendingTopics: trendingTopics ?? this.trendingTopics,
      suggestedQueries: suggestedQueries ?? this.suggestedQueries,
      isLoading: isLoading ?? this.isLoading,
      lastRefresh: lastRefresh ?? this.lastRefresh,
    );
  }
}

// ───────────────────────────────────────────────────────────────
//  NOTIFIER
// ───────────────────────────────────────────────────────────────

class SearchIntelligenceNotifier
    extends StateNotifier<SearchIntelligenceState> {
  SearchIntelligenceNotifier(this._ref) : super(SearchIntelligenceState()) {
    _init();
  }

  final Ref _ref;
  Timer? _refreshTimer;

  static const _refreshInterval = Duration(minutes: 15);

  void _init() {
    _refreshIntelligence();
    // Periodic refresh
    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      _refreshIntelligence();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshIntelligence() async {
    state = state.copyWith(isLoading: true);

    try {
      // 1. Gather articles from ALL categories
      final newsState = _ref.read(newsProvider);
      final allArticles = <NewsArticle>[];

      for (final category in <String>[
        'latest',
        'trending',
        'national',
        'international',
        'sports',
        'entertainment',
      ]) {
        allArticles.addAll(newsState.getArticles(category));
      }

      if (allArticles.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          suggestedQueries: const <String>[
            'latest',
            'trending',
            'latest news',
            'trending now',
          ],
        );
        return;
      }

      // Deduplicate by URL
      final seen = <String>{};
      final uniqueArticles = <NewsArticle>[];
      for (final a in allArticles) {
        if (seen.add(a.url)) uniqueArticles.add(a);
      }

      // Take most recent 100 articles for analysis
      uniqueArticles.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
      final sample = uniqueArticles.take(100).toList();

      // 2. Build article maps for the AI service
      final articleMaps = sample
          .map(
            (a) => <String, String>{
              'title': a.title,
              'description': a.description,
              'source': a.source,
              'url': a.url,
              'publishedAt': a.publishedAt.toIso8601String(),
              'category': a.category,
              'tags': (a.tags ?? const <String>[]).join(','),
            },
          )
          .toList();

      // 3. Extract trending topics
      final aiService = _ref.read(aiServiceProvider);
      final extracted = aiService.extractTrendingTopics(articleMaps);

      // 4. Build publisher associations
      final trendingTopics = extracted.map((topic) {
        return _buildTrendingTopic(topic, sample);
      }).toList();
      final suggestedQueries = _buildSuggestedQueries(trendingTopics);

      state = state.copyWith(
        trendingTopics: trendingTopics,
        suggestedQueries: suggestedQueries,
        isLoading: false,
        lastRefresh: DateTime.now(),
      );
    } catch (e) {
      debugPrint('⚠️ Trending refresh failed: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  List<String> _buildSuggestedQueries(List<TrendingTopic> topics) {
    final seeded = <String>[
      'latest',
      'trending',
      'latest news',
      'trending now',
    ];
    seeded.insertAll(0, _ref.read(localLearningEngineProvider).topQueries(limit: 6));

    for (final topic in topics) {
      final label = topic.label.trim();
      if (label.length < 3) continue;
      seeded.add(label);
      if (label.split(' ').length <= 3) {
        seeded.add('$label latest');
      }
    }

    final seen = <String>{};
    final unique = <String>[];
    for (final value in seeded) {
      final normalized = value.toLowerCase().trim();
      if (normalized.isEmpty || !seen.add(normalized)) continue;
      unique.add(value);
      if (unique.length >= 14) break;
    }
    return unique;
  }

  TrendingTopic _buildTrendingTopic(
    ExtractedTopic topic,
    List<NewsArticle> articles,
  ) {
    // Find all articles matching this topic
    final topicLower = topic.label.toLowerCase();
    final matchingArticles = articles.where((a) {
      final text = '${a.title} ${a.description}'.toLowerCase();
      return text.contains(topicLower);
    }).toList();

    // Group by publisher
    final publisherCounts = <String, int>{};
    for (final a in matchingArticles) {
      final source = a.source;
      publisherCounts[source] = (publisherCounts[source] ?? 0) + 1;
    }

    // Build publisher hits with logos
    final publishers = publisherCounts.entries.map((entry) {
      final logoPath = _resolvePublisherLogo(entry.key);
      return PublisherHit(
        name: entry.key,
        logoPath: logoPath,
        articleCount: entry.value,
      );
    }).toList()..sort((a, b) => b.articleCount.compareTo(a.articleCount));

    return TrendingTopic(
      label: topic.label,
      articleCount: matchingArticles.length,
      publishers: publishers.take(5).toList(),
    );
  }

  String? _resolvePublisherLogo(String sourceName) {
    // Direct match
    if (SourceLogos.logos.containsKey(sourceName)) {
      return SourceLogos.logos[sourceName];
    }
    // Fuzzy match: check if source name is contained in any key
    final lower = sourceName.toLowerCase();
    for (final entry in SourceLogos.logos.entries) {
      if (entry.key.toLowerCase().contains(lower) ||
          lower.contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }
    return null;
  }

  /// Force refresh (e.g., when user pulls-to-refresh or locale changes).
  void forceRefresh() => _refreshIntelligence();
}

final searchIntelligenceProvider =
    StateNotifierProvider<SearchIntelligenceNotifier, SearchIntelligenceState>((
      ref,
    ) {
      return SearchIntelligenceNotifier(ref);
    });
