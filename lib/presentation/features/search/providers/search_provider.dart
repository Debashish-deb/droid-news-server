import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/providers.dart' as di;
import '../../../../domain/entities/news_article.dart';
import '../../../../domain/repositories/search_repository.dart';
import '../../../providers/app_settings_providers.dart'
    show searchRepositoryProvider;
import '../../../providers/feature_providers.dart'
    show localLearningEngineProvider;

class SearchState {
  SearchState({
    this.recentSearches = const [],
    this.searchResults = const [],
    this.isLoading = false,
    this.showGoogleFallback = false,
    this.activeTopicQuery,
  });
  final List<String> recentSearches;
  final List<NewsArticle> searchResults;
  final bool isLoading;
  final bool showGoogleFallback;
  final String? activeTopicQuery;

  SearchState copyWith({
    List<String>? recentSearches,
    List<NewsArticle>? searchResults,
    bool? isLoading,
    bool? showGoogleFallback,
    String? activeTopicQuery,
  }) {
    return SearchState(
      recentSearches: recentSearches ?? this.recentSearches,
      searchResults: searchResults ?? this.searchResults,
      isLoading: isLoading ?? this.isLoading,
      showGoogleFallback: showGoogleFallback ?? this.showGoogleFallback,
      activeTopicQuery: activeTopicQuery ?? this.activeTopicQuery,
    );
  }
}

class SearchNotifier extends StateNotifier<SearchState> {
  SearchNotifier(this._repository, this._ref) : super(SearchState()) {
    _loadRecentSearches();
  }
  final SearchRepository _repository;
  final Ref _ref;
  int _activeSearchToken = 0;

  Future<void> _loadRecentSearches() async {
    final result = await _repository.getRecentSearches();
    state = state.copyWith(recentSearches: result.getOrElse(const []));
  }

  Future<void> search(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) {
      _activeSearchToken++;
      state = state.copyWith(
        searchResults: [],
        isLoading: false,
        showGoogleFallback: false,
      );
      return;
    }

    final int token = ++_activeSearchToken;
    state = state.copyWith(isLoading: true, showGoogleFallback: false);

    // Save search query
    await _repository.saveRecentSearch(normalized);
    _ref.read(localLearningEngineProvider).trackSearchSubmit(normalized);
    if (token != _activeSearchToken) return;
    await _loadRecentSearches();
    if (token != _activeSearchToken) return;

    final result = await _repository.searchArticles(normalized);
    if (token != _activeSearchToken) return;
    result.fold(
      (failure) => state = state.copyWith(
        isLoading: false,
        searchResults: [],
        showGoogleFallback: true,
        activeTopicQuery: normalized,
      ),
      (articles) => state = state.copyWith(
        isLoading: false,
        searchResults: articles,
        showGoogleFallback: articles.isEmpty,
        activeTopicQuery: articles.isEmpty ? normalized : null,
      ),
    );
  }

  /// Search triggered by tapping a trending topic.
  /// Sets activeTopicQuery and showGoogleFallback if no internal results.
  Future<void> searchByTopic(String topic) async {
    final int token = ++_activeSearchToken;
    _ref.read(localLearningEngineProvider).trackSuggestionClick(topic);
    state = state.copyWith(
      isLoading: true,
      showGoogleFallback: false,
      activeTopicQuery: topic,
    );

    final result = await _repository.searchArticles(topic);
    if (token != _activeSearchToken) return;

    result.fold(
      (failure) => state = state.copyWith(
        isLoading: false,
        searchResults: [],
        showGoogleFallback: true,
      ),
      (articles) => state = state.copyWith(
        isLoading: false,
        searchResults: articles,
        showGoogleFallback: articles.isEmpty,
      ),
    );
  }

  void clearTopicSearch() {
    _activeSearchToken++;
    state = state.copyWith(
      searchResults: [],
      showGoogleFallback: false,
    );
  }

  Future<void> clearHistory() async {
    await _repository.clearRecentSearches();
    state = state.copyWith(recentSearches: []);
  }
}

final searchProvider = StateNotifierProvider<SearchNotifier, SearchState>((
  ref,
) {
  final repo = ref.watch(searchRepositoryProvider);
  return SearchNotifier(repo, ref);
});

final searchControllerProvider = StateProvider<String>((ref) => '');

final publisherSuggestionsProvider = Provider<List<MapEntry<String, String>>>((
  ref,
) {
  final query = ref.watch(searchControllerProvider).toLowerCase().trim();
  if (query.isEmpty) return const [];

  return ref
      .watch(di.publisherLogoMapProvider)
      .entries
      .where((e) => e.key.toLowerCase().contains(query))
      .take(6)
      .toList();
});
