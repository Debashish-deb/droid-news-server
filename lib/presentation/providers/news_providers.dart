// lib/presentation/providers/news_providers.dart
// ================================================
// RIVERPOD PROVIDERS FOR NEWS
// ================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/news_article.dart';
import '../../data/repositories/news_repository.dart';
import '../../core/offline_handler.dart';

// ============================================
// NEWS STATE
// ============================================

@immutable
class NewsState {
  const NewsState({
    this.articles = const {},
    this.loading = const {},
    this.errors = const {},
  });
  final Map<String, List<NewsArticle>> articles;
  final Map<String, bool> loading;
  final Map<String, String?> errors;

  List<NewsArticle> getArticles(String category) => articles[category] ?? [];
  bool isLoading(String category) => loading[category] ?? false;
  String? getError(String category) => errors[category];

  NewsState copyWith({
    Map<String, List<NewsArticle>>? articles,
    Map<String, bool>? loading,
    Map<String, String?>? errors,
  }) {
    return NewsState(
      articles: articles ?? this.articles,
      loading: loading ?? this.loading,
      errors: errors ?? this.errors,
    );
  }
}

// ============================================
// NEWS NOTIFIER
// ============================================

class NewsNotifier extends StateNotifier<NewsState> {
  NewsNotifier({NewsRepository? newsRepository})
    : _newsRepository = newsRepository ?? NewsRepository(),
      super(const NewsState()) {
    _initConnectivityListener();
  }

  final NewsRepository _newsRepository;
  StreamSubscription<bool>? _connectivitySub;
  Locale? _lastLocale;

  void _initConnectivityListener() {
    _connectivitySub = OfflineHandler().onConnectivityChanged.listen((
      bool isOffline,
    ) {
      if (!isOffline && _lastLocale != null) {
        _refreshActiveCategories();
      }
    });
  }

  void _refreshActiveCategories() {
    if (_lastLocale == null) return;
    if (state.errors.isNotEmpty) {
      debugPrint('⚡ Back Online: Auto-refreshing news...');
      // In a real app we might retry all active categories
    }
  }

  /// Load news for a category
  Future<void> loadNews(
    String category,
    Locale locale, {
    bool force = false,
  }) async {
    _lastLocale = locale;

    // Skip if already loading
    if (state.loading[category] == true && !force) return;

    // Optimistic Cache Check for immediate UI Feedback (Optional but good UX)
    // We let the Repository handle the logic, but we can verify cache existence
    // to avoid flickering loading states if data exists.
    // For now, let's trust the Repository to return fast if cached.

    // Set loading
    final newLoading = Map<String, bool>.from(state.loading);
    newLoading[category] = true;
    state = state.copyWith(loading: newLoading);

    final result = await _newsRepository.getNews(
      category: category,
      locale: locale,
      forceRefresh: force,
    );

    result.fold(
      (failure) {
        final updatedLoading = Map<String, bool>.from(state.loading);
        updatedLoading[category] = false;

        final newErrors = Map<String, String?>.from(state.errors);
        newErrors[category] = failure.userMessage;

        state = state.copyWith(loading: updatedLoading, errors: newErrors);
        debugPrint('❌ Error loading $category: ${failure.message}');
      },
      (articles) {
        // Update state
        final newArticles = Map<String, List<NewsArticle>>.from(state.articles);
        newArticles[category] = articles;

        final updatedLoading = Map<String, bool>.from(state.loading);
        updatedLoading[category] = false;

        final newErrors = Map<String, String?>.from(state.errors);
        newErrors[category] = null;

        state = state.copyWith(
          articles: newArticles,
          loading: updatedLoading,
          errors: newErrors,
        );
      },
    );
  }

  /// Clear articles for a category
  void clearCategory(String category) {
    final newArticles = Map<String, List<NewsArticle>>.from(state.articles);
    newArticles.remove(category);
    state = state.copyWith(articles: newArticles);
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }
}

// ============================================
// PROVIDERS
// ============================================

/// Main news provider
final newsProvider = StateNotifierProvider<NewsNotifier, NewsState>((ref) {
  return NewsNotifier();
});

/// Convenience: get articles for a specific category
final newsByCategoryProvider = Provider.family<List<NewsArticle>, String>((
  ref,
  category,
) {
  return ref.watch(newsProvider.select((state) => state.getArticles(category)));
});

/// Convenience: check if a category is loading
final newsLoadingProvider = Provider.family<bool, String>((ref, category) {
  return ref.watch(newsProvider.select((state) => state.isLoading(category)));
});

/// Convenience: get error for a category
final newsErrorProvider = Provider.family<String?, String>((ref, category) {
  return ref.watch(newsProvider.select((state) => state.getError(category)));
});
