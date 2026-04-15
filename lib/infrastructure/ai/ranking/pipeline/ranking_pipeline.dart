// lib/infrastructure/ai/ranking/pipeline/ranking_pipeline.dart
import 'package:flutter/foundation.dart';
import '../../../../domain/entities/news_article.dart';
import '../../../../domain/repositories/news_repository.dart';
import '../../../../application/ai/ranking/user_interest_service.dart';
import '../../../../infrastructure/services/ml/categorization_helper.dart';

/// Payload for background ranking computation
class _RankingPayload {
  _RankingPayload(this.articles, this.snapshot, {this.prioritizeBangladesh = false});
  final List<NewsArticle> articles;
  final UserInterestSnapshot snapshot;
  final bool prioritizeBangladesh;
}


class RankingPipeline {
  RankingPipeline(this._repository, this._interestService);

  final NewsRepository _repository;
  final UserInterestService _interestService;

  /// RESTORED: Now async to support Isolate-based background ranking
  Future<List<NewsArticle>> rank(List<NewsArticle> articles, {bool prioritizeBangladesh = false}) async {
    if (articles.isEmpty) return [];
    
    return await compute(
      _rankLogic, 
      _RankingPayload(
        articles, 
        _interestService.getSnapshot(),
        prioritizeBangladesh: prioritizeBangladesh,
      ),
    );
  }

  /// UPDATED: Fetches and ranks in one flow
  Future<List<NewsArticle>> run(String category) async {
    final result = await _repository.getNewsFeed(page: 1, limit: 100, category: category);
    
    return await result.fold(
      (fail) async => [],
      (candidates) async => await rank(candidates, prioritizeBangladesh: category == 'latest'),
    );
  }

  /// Background Isolate function (Logic moved here for thread-safety)
  static List<NewsArticle> _rankLogic(_RankingPayload payload) {
    // 1. Deduplicate
    final seen = <String>{};
    var unique = payload.articles.where((a) => seen.add(a.url)).toList();

    // 2. Score and Sort
    unique.sort((a, b) {
      final scoreA = _calculateScoreStatic(a, payload.snapshot);
      final scoreB = _calculateScoreStatic(b, payload.snapshot);
      return scoreB.compareTo(scoreA); // Descending
    });

    // 3. Inject Diversity
    if (unique.length > 10) {
      final explorationItem = unique.removeLast();
      unique.insert(5, explorationItem); // Discovery article at pos 5
    }

    // 4. Prioritize Bangladesh if requested (Moved from NewsNotifier for performance)
    if (payload.prioritizeBangladesh) {
      unique = _prioritizeBangladeshFeedStatic(unique);
    }

    return unique;
  }

  /// Static scoring logic for Isolate safety
  static double _calculateScoreStatic(NewsArticle article, UserInterestSnapshot snapshot) {
    // Freshness Factor
    final hoursOld = DateTime.now().difference(article.publishedAt).inHours;
    final freshness = 1.0 / (1.0 + hoursOld * 0.1);

    // Personalization Baseline
    double personalization = 0.5;
    
    // Category check using the snapshot's vocabulary/vector
    final index = snapshot.vocabulary.indexOf(article.category.toLowerCase());
    if (index != -1 && snapshot.interestVector != null) {
      personalization = (snapshot.interestVector![index] / 65535.0);
    }

    // Weighted blend: 60% Personalization, 40% Freshness
    return (0.6 * personalization) + (0.4 * freshness);
  }

  /// Migrated from NewsNotifier to background thread
  static List<NewsArticle> _prioritizeBangladeshFeedStatic(List<NewsArticle> articles) {
    if (articles.length < 10) return articles;

    final bangladesh = <NewsArticle>[];
    final other = <NewsArticle>[];

    for (final article in articles) {
      if (_isBangladeshFocusedStatic(article)) {
        bangladesh.add(article);
      } else {
        other.add(article);
      }
    }

    if (bangladesh.isEmpty || other.isEmpty) return articles;

    // 4:1 mix keeps the feed primarily Bangladesh-focused while still surfacing
    // some global stories.
    const bangladeshRun = 4;
    final mixed = <NewsArticle>[];
    var bdIndex = 0;
    var otherIndex = 0;

    while (bdIndex < bangladesh.length || otherIndex < other.length) {
      for (var i = 0; i < bangladeshRun && bdIndex < bangladesh.length; i++) {
        mixed.add(bangladesh[bdIndex++]);
      }
      if (otherIndex < other.length) {
        mixed.add(other[otherIndex++]);
      }
      if (bdIndex >= bangladesh.length && otherIndex < other.length) {
        mixed.addAll(other.skip(otherIndex));
        break;
      }
      if (otherIndex >= other.length && bdIndex < bangladesh.length) {
        mixed.addAll(bangladesh.skip(bdIndex));
        break;
      }
    }

    return mixed;
  }

  static bool _isBangladeshFocusedStatic(NewsArticle article) {
    if (CategorizationHelper.isBangladeshCentric(
      title: article.title,
      description: article.description,
      content: article.fullContent.isNotEmpty
          ? article.fullContent
          : article.snippet,
    )) {
      return true;
    }

    final source = article.source.toLowerCase();
    final url = article.url.toLowerCase();
    return source.contains('bangladesh') ||
        source.contains('dhaka') ||
        source.contains('bdnews') ||
        url.contains('.bd/');
  }
}