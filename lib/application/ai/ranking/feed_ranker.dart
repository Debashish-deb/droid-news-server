import '../../../domain/entities/news_thread.dart';
import 'user_interest_service.dart';

// Re-ranks a list of [NewsThread]s based on the user's interest profile.
class FeedRanker {

  FeedRanker(this._interestService);
  final UserInterestService _interestService;

  List<NewsThread> rankFeed(List<NewsThread> threads) {
    final ranked = List<NewsThread>.from(threads);

    ranked.sort((a, b) {
      final scoreA = _calculateThreadScore(a);
      final scoreB = _calculateThreadScore(b);
      return scoreB.compareTo(scoreA);
    });

    return ranked;
  }

  double _calculateThreadScore(NewsThread thread) {
    final hoursOld = DateTime.now().difference(thread.mainArticle.publishedAt).inHours;
    double freshnessScore = 10.0 - (hoursOld * 0.1); 
    if (freshnessScore < 0) freshnessScore = 0;

    // 2. Personalization Weight using TF-IDF Engine
    final double interestScore = _interestService.getPersonalizationScore(thread.mainArticle);

    // 3. Category Boosts (making previously unused methods useful)
    double categoryBoost = 1.0;
    if (_isTech(thread)) categoryBoost *= 1.5;
    if (_isSports(thread)) categoryBoost *= 1.3;

    final double clusterBonus = thread.relatedArticles.isNotEmpty ? 1.2 : 1.0;

    return freshnessScore * interestScore * clusterBonus * categoryBoost;
  }

  bool _isSports(NewsThread thread) {
    final text = thread.mainArticle.title.toLowerCase();
    return text.contains('cricket') || text.contains('football') || text.contains('score');
  }

  bool _isTech(NewsThread thread) {
    final text = thread.mainArticle.title.toLowerCase();
    return text.contains('tech') || text.contains('ai') || text.contains('google') || text.contains('apple');
  }
}
