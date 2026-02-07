import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../domain/entities/news_article.dart';
import '../../../../infrastructure/ai/features/feature_engineering_service.dart';
import '../../../providers/news_providers.dart';
import '../../../../bootstrap/di/injection_container.dart';

// ============================================================================
// SMART FEED LOGIC (ON-DEVICE AI)
// ============================================================================

// State for the Smart Feed
class SmartFeedState { 

  const SmartFeedState({
    this.articles = const [],
    this.isPersonalizing = false,
    this.interestProfile = const {},
  });
  final List<NewsArticle> articles;
  final bool isPersonalizing;
  final Map<String, double> interestProfile;
}

// Notifier that manages the personalized feed
class SmartFeedNotifier extends StateNotifier<SmartFeedState> {
  SmartFeedNotifier(this._ref) : super(const SmartFeedState()) {
    _init();
  }

  final Ref _ref;
  late final FeatureEngineeringService _featureService;

  void _init() {
    _ref.listen<NewsState>(newsProvider, (previous, next) {
      if (next.articles.isNotEmpty) {
        _personalizeFeed(next.getArticles('latest'));
      }
    });

    _featureService = sl<FeatureEngineeringService>();
    _featureService.featureStream.listen((features) {
      if (features['feature_name'] == 'topic_interest' || features['feature_name'] == 'engagement_score') {
         final topic = features['topic'] as String?;
         final score = features['value'] as double?;
         if (topic != null && score != null) {
           final updatedProfile = Map<String, double>.from(state.interestProfile);
           updatedProfile[topic] = (updatedProfile[topic] ?? 0.0) + score;
           state = SmartFeedState(
             articles: state.articles,
             isPersonalizing: state.isPersonalizing,
             interestProfile: updatedProfile,
           );
         }
      }
    });
  }

  Future<void> _personalizeFeed(List<NewsArticle> rawArticles) async {
    if (state.isPersonalizing) return;

    state = SmartFeedState(
      articles: state.articles,
      isPersonalizing: true,
      interestProfile: state.interestProfile,
    );

    // Filter articles for quality first
    final filtered = rawArticles.where((a) => a.title.length > 5).toList();

    final scoredArticles = filtered.map((article) {
       final double score = _calculateScore(article);
       return MapEntry(article, score);
    }).toList();

    scoredArticles.sort((a, b) => b.value.compareTo(a.value));

    state = SmartFeedState(
      articles: scoredArticles.map((e) => e.key).toList(),
      interestProfile: state.interestProfile,
    );
  }

  double _calculateScore(NewsArticle article) {
    double score = 1.0;

    // Recency Factor (Decay)
    final hoursOld = DateTime.now().difference(article.publishedAt).inHours;
    score -= (hoursOld * 0.05); 

    // Quality Signals
    if (article.imageUrl != null) score += 0.5;
    if (article.description.length > 100) score += 0.4;
    
    // Personalization Factor (Interest Profile)
    // We check if the article source or title matches topics in the interest profile
    state.interestProfile.forEach((topic, weight) {
      if (article.title.toLowerCase().contains(topic.toLowerCase()) ||
          article.category.toLowerCase() == topic.toLowerCase()) {
        score += (weight * 0.8);
      }
    });
    
    return score;
  }
}

// Provider for the Smart Feed
final smartFeedProvider = StateNotifierProvider<SmartFeedNotifier, SmartFeedState>((ref) {
  return SmartFeedNotifier(ref);
});
