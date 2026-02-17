// lib/infrastructure/ai/ranking/pipeline/ranking_pipeline.dart
import 'package:flutter/foundation.dart';
import '../../../../domain/entities/news_article.dart';
import '../../../../domain/repositories/news_repository.dart';
import '../../../../application/ai/ranking/user_interest_service.dart';

/// Payload for background ranking computation
class _RankingPayload {
  final List<NewsArticle> articles;
  final UserInterestSnapshot snapshot;
  _RankingPayload(this.articles, this.snapshot);
}


class RankingPipeline {
  RankingPipeline(this._repository, this._interestService);

  final NewsRepository _repository;
  final UserInterestService _interestService;

  /// RESTORED: Now async to support Isolate-based background ranking
  Future<List<NewsArticle>> rank(List<NewsArticle> articles) async {
    if (articles.isEmpty) return [];
    
    return await compute(
      _rankLogic, 
      _RankingPayload(articles, _interestService.getSnapshot()),
    );
  }

  /// UPDATED: Fetches and ranks in one flow
  Future<List<NewsArticle>> run(String category) async {
    final result = await _repository.getNewsFeed(page: 1, limit: 100, category: category);
    
    return result.fold(
      (fail) => [],
      (candidates) async {
        return await rank(candidates);
      },
    );
  }

  /// Background Isolate function (Logic moved here for thread-safety)
  static List<NewsArticle> _rankLogic(_RankingPayload payload) {
    // 1. Deduplicate
    final seen = <String>{};
    final unique = payload.articles.where((a) => seen.add(a.url)).toList();

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
}