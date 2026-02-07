import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../domain/entities/news_article.dart';
import '../../../../domain/repositories/search_repository.dart';
import '../../../providers/app_settings_providers.dart' show searchRepositoryProvider;

class SearchState {

  SearchState({
    this.recentSearches = const [],
    this.searchResults = const [],
    this.isLoading = false,
  });
  final List<String> recentSearches;
  final List<NewsArticle> searchResults;
  final bool isLoading;

  SearchState copyWith({
    List<String>? recentSearches,
    List<NewsArticle>? searchResults,
    bool? isLoading,
  }) {
    return SearchState(
      recentSearches: recentSearches ?? this.recentSearches,
      searchResults: searchResults ?? this.searchResults,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class SearchNotifier extends StateNotifier<SearchState> {

  SearchNotifier(this._repository) : super(SearchState()) {
    _loadRecentSearches();
  }
  final SearchRepository _repository;

  Future<void> _loadRecentSearches() async {
    final result = await _repository.getRecentSearches();
    state = state.copyWith(recentSearches: result.getOrElse(const []));
  }

  Future<void> search(String query) async {
    if (query.isEmpty) {
      state = state.copyWith(searchResults: []);
      return;
    }

    state = state.copyWith(isLoading: true);
    
    // Save search query
    await _repository.saveRecentSearch(query);
    await _loadRecentSearches();

    final result = await _repository.searchArticles(query);
    result.fold(
      (failure) => state = state.copyWith(isLoading: false, searchResults: []),
      (articles) => state = state.copyWith(isLoading: false, searchResults: articles),
    );
  }

  Future<void> clearHistory() async {
    await _repository.clearRecentSearches();
    state = state.copyWith(recentSearches: []);
  }
}


final searchProvider = StateNotifierProvider<SearchNotifier, SearchState>((ref) {
  final repo = ref.watch(searchRepositoryProvider);
  return SearchNotifier(repo);
});
