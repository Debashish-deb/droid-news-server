import 'package:flutter/foundation.dart'; // For compute
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../domain/entities/news_article.dart';
import '../../../../infrastructure/ai/features/feature_engineering_service.dart';
import '../../../providers/news_providers.dart';
import '../../../../core/di/providers.dart';

// ============================================================================
// SMART FEED LOGIC (ON-DEVICE AI)
// ============================================================================

/// Helper class for Isolate communication
class _PersonalizationParams {
  _PersonalizationParams(this.rawArticles, this.interestProfile);
  final List<NewsArticle> rawArticles;
  final Map<String, double> interestProfile;
}

/// State for the Smart Feed
class SmartFeedState {
  const SmartFeedState({
    this.articles = const [],
    this.isPersonalizing = false,
    this.interestProfile = const {},
  });

  final List<NewsArticle> articles;
  final bool isPersonalizing;
  final Map<String, double> interestProfile;

  /// Added copyWith for cleaner state updates
  SmartFeedState copyWith({
    List<NewsArticle>? articles,
    bool? isPersonalizing,
    Map<String, double>? interestProfile,
  }) {
    return SmartFeedState(
      articles: articles ?? this.articles,
      isPersonalizing: isPersonalizing ?? this.isPersonalizing,
      interestProfile: interestProfile ?? this.interestProfile,
    );
  }
}

/// Notifier that manages the personalized feed
class SmartFeedNotifier extends StateNotifier<SmartFeedState> {
  SmartFeedNotifier(this._ref) : super(const SmartFeedState()) {
    _init();
  }

  final Ref _ref;
  late final FeatureEngineeringService _featureService;

  void _init() {
    // Listen for new articles from the primary news feed
    _ref.listen<NewsState>(newsProvider, (previous, next) {
      if (next.articles.isNotEmpty) {
        _personalizeFeed(next.getArticles('latest'));
      }
    });

    // Listen for real-time user behavior signals
    _featureService = _ref.read(featureEngineeringServiceProvider);
    _featureService.featureStream.listen((features) {
      if (features['feature_name'] == 'topic_interest' || features['feature_name'] == 'engagement_score') {
        final topic = features['topic'] as String?;
        final score = features['value'] as double?;
        if (topic != null && score != null) {
          final updatedProfile = Map<String, double>.from(state.interestProfile);
          updatedProfile[topic] = (updatedProfile[topic] ?? 0.0) + score;
          state = state.copyWith(interestProfile: updatedProfile);
        }
      }
    });
  }

  /// Refactored to use [compute] to protect UI thread responsiveness
  Future<void> _personalizeFeed(List<NewsArticle> rawArticles) async {
    if (state.isPersonalizing) return;

    state = state.copyWith(isPersonalizing: true);

    try {
      // Offload heavy ranking logic to a background Isolate
      final personalizedArticles = await compute(
        _personalizeInIsolate,
        _PersonalizationParams(rawArticles, state.interestProfile),
      );

      state = state.copyWith(
        articles: personalizedArticles,
        isPersonalizing: false,
      );
    } catch (e) {
      // In case of error, revert personalization flag
      state = state.copyWith(isPersonalizing: false);
    }
  }

  /// Pure function that executes within the Isolate to sort and score articles
  static List<NewsArticle> _personalizeInIsolate(_PersonalizationParams params) {
    // Basic quality filtering
    final filtered = params.rawArticles.where((a) => a.title.length > 5).toList();

    // Generate scores based on profile and metadata
    final scoredArticles = filtered.map((article) {
      final double score = _calculateScoreStatic(article, params.interestProfile);
      return MapEntry(article, score);
    }).toList();

    // Sort descending by calculated relevance score
    scoredArticles.sort((a, b) => b.value.compareTo(a.value));

    return scoredArticles.map((e) => e.key).toList();
  }

  /// Static scoring logic for Isolate safety
  static double _calculateScoreStatic(NewsArticle article, Map<String, double> profile) {
    double score = 1.0;

    // 1. Recency Decay (Freshness)
    final hoursOld = DateTime.now().difference(article.publishedAt).inHours;
    score -= (hoursOld * 0.05);

    // 2. Quality & Engagement Signals
    if (article.imageUrl != null) score += 0.5;
    if (article.description.length > 100) score += 0.4;

    // 3. Personalized Interest Matching
    profile.forEach((topic, weight) {
      final String title = article.title.toLowerCase();
      final String category = article.category.toLowerCase();
      final String matchTopic = topic.toLowerCase();

      if (title.contains(matchTopic) || category == matchTopic) {
        score += (weight * 0.8);
      }
    });

    return score;
  }
}

/// Provider for the Smart Feed
final smartFeedProvider = StateNotifierProvider<SmartFeedNotifier, SmartFeedState>((ref) {
  return SmartFeedNotifier(ref);
});