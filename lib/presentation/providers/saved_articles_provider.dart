import 'package:flutter_riverpod/flutter_riverpod.dart';
import "../../domain/entities/news_article.dart";
import '../../infrastructure/persistence/saved_articles_service.dart';
import '../../domain/entities/news_article.dart' show NewsArticle;

import '../../core/di/providers.dart';

/// Provider for saved articles state
final savedArticlesProvider =
    StateNotifierProvider<SavedArticlesNotifier, SavedArticlesState>((ref) {
      final service = ref.watch(savedArticlesServiceProvider);
      return SavedArticlesNotifier(service: service);
    });

/// State for saved articles
class SavedArticlesState {
  SavedArticlesState({
    this.articles = const [],
    this.isLoading = false,
    this.error,
  });
  final List<NewsArticle> articles;
  final bool isLoading;
  final String? error;

  SavedArticlesState copyWith({
    List<NewsArticle>? articles,
    bool? isLoading,
    String? error,
  }) {
    return SavedArticlesState(
      articles: articles ?? this.articles,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

/// Notifier for saved articles
class SavedArticlesNotifier extends StateNotifier<SavedArticlesState> {
  SavedArticlesNotifier({required SavedArticlesService service})
    : _service = service,
      super(SavedArticlesState()) {
    _init();
  }

  final SavedArticlesService _service;

  Future<void> _init() async {
    await _service.init();
    await loadSavedArticles();
  }

  /// Load all saved articles
  Future<void> loadSavedArticles() async {
    state = state.copyWith(isLoading: true);
    try {
      final articles = _service.getSavedArticles();
      state = state.copyWith(articles: articles, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Save an article for offline reading
  Future<bool> saveArticle(NewsArticle article) async {
    state = state.copyWith(isLoading: true);
    try {
      final success = await _service.saveArticle(article);
      if (success) {
        await loadSavedArticles();
      }
      state = state.copyWith(isLoading: false);
      return success;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Remove a saved article
  Future<bool> removeArticle(String url) async {
    state = state.copyWith(isLoading: true);
    try {
      final success = await _service.removeArticle(url);
      if (success) {
        await loadSavedArticles();
      }
      state = state.copyWith(isLoading: false);
      return success;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Toggle save state for an article
  Future<bool> toggleSave(NewsArticle article) async {
    if (isSaved(article.url)) {
      return await removeArticle(article.url);
    } else {
      return await saveArticle(article);
    }
  }

  /// Check if an article is saved
  bool isSaved(String url) {
    return _service.isSaved(url);
  }

  /// Get saved article by URL
  NewsArticle? getSavedArticle(String url) {
    return _service.getSavedArticle(url);
  }

  /// Get saved count
  int get savedCount => _service.savedCount;

  /// Get storage usage in MB
  double get storageUsageMB => _service.storageUsageMB;

  /// Clear all saved articles
  Future<void> clearAll() async {
    await _service.clearAll();
    await loadSavedArticles();
  }
}
