import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../domain/entities/news_article.dart';
import '../../../providers/news_providers.dart';
import '../../../../application/ai/ai_service.dart';
import '../../../../application/ai/ranking/user_interest_service.dart';
import '../../../../core/di/providers.dart';

class SearchIntelligenceState {

  SearchIntelligenceState({
    this.trendingTopics = const [],
    this.personalizedRecommendations = const [],
    this.isLoading = false,
  });
  final List<String> trendingTopics;
  final List<NewsArticle> personalizedRecommendations;
  final bool isLoading;

  SearchIntelligenceState copyWith({
    List<String>? trendingTopics,
    List<NewsArticle>? personalizedRecommendations,
    bool? isLoading,
  }) {
    return SearchIntelligenceState(
      trendingTopics: trendingTopics ?? this.trendingTopics,
      personalizedRecommendations: personalizedRecommendations ?? this.personalizedRecommendations,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class SearchIntelligenceNotifier extends StateNotifier<SearchIntelligenceState> {
  SearchIntelligenceNotifier(this._ref) : super(SearchIntelligenceState()) {
    _init();
  }

  final Ref _ref;

  void _init() {
    _refreshIntelligence();
  }

  Future<void> _refreshIntelligence() async {
    state = state.copyWith(isLoading: true);
    
    // 1. Get Latest Articles
    final newsState = _ref.read(newsProvider);
    final articles = newsState.getArticles('latest');

    if (articles.isEmpty) {
      state = state.copyWith(isLoading: false);
      return;
    }

    // 2. Extract Trending Topics using AIService heuristics
    final aiService = _ref.read(aiServiceProvider);
    
    // Concatenate headlines for context - use a larger sample for better NLP extraction
    final allContent = articles.take(20).map((e) => '${e.title} ${e.description ?? ''}').join(' ');
    var topics = await aiService.generateTags(allContent);

    // Filter out very short or generic strings if any
    topics = topics.where((t) => t.length > 2).toList();
    if (topics.isEmpty) {
      topics = ['Bangladesh', 'Politics', 'Sports', 'Economy', 'Global'];
    }

    // 3. Personalized Recommendations based on UserInterest
    final interestService = _ref.read(userInterestServiceProvider);
    
    // Sort all articles by interest score
    final candidates = List<NewsArticle>.from(articles);
    candidates.sort((a, b) {
       final scoreA = interestService.getInterestScore(a.source);
       final scoreB = interestService.getInterestScore(b.source);
       return scoreB.compareTo(scoreA);
    });

    state = state.copyWith(
      trendingTopics: topics,
      personalizedRecommendations: candidates.take(6).toList(),
      isLoading: false,
    );
  }
}

final searchIntelligenceProvider = StateNotifierProvider<SearchIntelligenceNotifier, SearchIntelligenceState>((ref) {
  return SearchIntelligenceNotifier(ref);
});
