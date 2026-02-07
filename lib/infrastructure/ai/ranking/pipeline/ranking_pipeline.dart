import '../../../../domain/entities/news_article.dart';
import '../../../../domain/repositories/news_repository.dart';
import '../../../../application/ai/ranking/user_interest_service.dart';

// The Brain of the Feed.
// 
// Executes the 4-stage ranking process:
// 1. Candidate Generation
// 2. Filtering & Deduplication
// 3. Personal Relevance Scoring
// 4. Diversity Injection
import 'package:injectable/injectable.dart';

// The Brain of the Feed.
// 
// Executes the 4-stage ranking process:
// 1. Candidate Generation
// 2. Filtering & Deduplication
// 3. Personal Relevance Scoring
// 4. Diversity Injection
@lazySingleton
class RankingPipeline {
  RankingPipeline(this._repository, this._interestService);

  final NewsRepository _repository;
  final UserInterestService _interestService;

  List<NewsArticle> rank(List<NewsArticle> articles) {
    final unique = _deduplicate(articles);
    final ranked = _scoreAndRank(unique);
    return _injectDiversity(ranked);
  }

  Future<List<NewsArticle>> run(String category) async {
    final result = await _repository.getNewsFeed(page: 1, limit: 100, category: category);
    
    return result.fold(
      (fail) => [],
      (candidates) {
        final unique = _deduplicate(candidates);

        final ranked = _scoreAndRank(unique);

        return _injectDiversity(ranked);
      },
    );
  }

  List<NewsArticle> _deduplicate(List<NewsArticle> articles) {
    final seen = <String>{};
    return articles.where((a) => seen.add(a.url)).toList();
  }

  List<NewsArticle> _scoreAndRank(List<NewsArticle> articles) {
    articles.sort((a, b) {
      final scoreA = _calculateScore(a);
      final scoreB = _calculateScore(b);
      return scoreB.compareTo(scoreA); // Descending
    });
    return articles;
  }

  double _calculateScore(NewsArticle article) {
    // 1. Personalization Score from TF-IDF Engine
    final personalizationScore = _interestService.getPersonalizationScore(article);
    
    // 2. Freshness Score (Decay over time)
    final hoursOld = DateTime.now().difference(article.publishedAt).inHours;
    final freshness = 1.0 / (1.0 + hoursOld * 0.1);

    // 3. Source weight (Legacy support if still needed, otherwise simple blend)
    final sourceScore = _interestService.getInterestScore(article.source);

    // Weighted Blend
    return (0.5 * personalizationScore) + (0.3 * freshness) + (0.2 * sourceScore);
  }

  List<NewsArticle> _injectDiversity(List<NewsArticle> ranked) {
    if (ranked.length > 10) {
      final explorationItem = ranked.last;
      ranked.insert(5, explorationItem); // Inject at pos 5
    }
    return ranked;
  }
}
