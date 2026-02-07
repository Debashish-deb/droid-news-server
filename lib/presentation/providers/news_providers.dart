
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/news_article.dart';
import '../../domain/repositories/news_repository.dart';
import '../../core/offline_handler.dart';
import '../../infrastructure/ai/ranking/pipeline/ranking_pipeline.dart';
import '../../infrastructure/ai/engine/quantized_tfidf_engine.dart';
import '../../bootstrap/di/injection_container.dart' show sl;
import '../../bootstrap/di/providers.dart' show newsRepositoryProvider;


@immutable
class NewsState {
  const NewsState({
    this.articles = const {},
    this.loading = const {},
    this.errors = const {},
    this.pagination = const {},
  });
  final Map<String, List<NewsArticle>> articles;
  final Map<String, bool> loading;
  final Map<String, String?> errors;
  final Map<String, bool> pagination; // Truly has more?

  List<NewsArticle> getArticles(String category) => articles[category] ?? [];
  bool isLoading(String category) => loading[category] ?? false;
  String? getError(String category) => errors[category];
  bool hasMore(String category) => pagination[category] ?? true;

  NewsState copyWith({
    Map<String, List<NewsArticle>>? articles,
    Map<String, bool>? loading,
    Map<String, String?>? errors,
    Map<String, bool>? pagination,
  }) {
    return NewsState(
      articles: articles ?? this.articles,
      loading: loading ?? this.loading,
      errors: errors ?? this.errors,
      pagination: pagination ?? this.pagination,
    );
  }
}


class NewsNotifier extends StateNotifier<NewsState> {
  NewsNotifier({
    required NewsRepository newsRepository,
    required RankingPipeline rankingPipeline,
  }) : _newsRepository = newsRepository,
       _rankingPipeline = rankingPipeline,
       super(const NewsState()) {
    _initConnectivityListener();
  }

  final NewsRepository _newsRepository;
  final RankingPipeline _rankingPipeline;
  StreamSubscription<bool>? _connectivitySub;
  Locale? _lastLocale;
  final Map<String, int> _loadTokens = <String, int>{};

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
    }
  }

  /// Load news for a category
  Future<void> loadNews(
    String category,
    Locale locale, {
    bool force = false,
  }) async {
    final int token = (_loadTokens[category] ?? 0) + 1;
    _loadTokens[category] = token;
    _lastLocale = locale;

    if (state.loading[category] == true && !force) return;

    final newLoading = Map<String, bool>.from(state.loading);
    newLoading[category] = true;
    state = state.copyWith(loading: newLoading);

    // If force refresh is requested, sync with remote sources first
    if (force) {
      debugPrint('🔄 Force refresh requested for $category');
      final syncResult = await _newsRepository.syncNews(locale: locale);
      syncResult.fold(
        (failure) => debugPrint('⚠️ Sync warning: ${failure.message}'),
        (_) => debugPrint('✅ Sync complete'),
      );
    }

    final result = await _newsRepository.getArticlesByCategory(
      category,
      language: locale.languageCode,
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
      (articles) async {
        final List<NewsArticle> baseArticles = List<NewsArticle>.from(articles);
        final newArticles = Map<String, List<NewsArticle>>.from(state.articles);
        newArticles[category] = baseArticles;

        final updatedLoading = Map<String, bool>.from(state.loading);
        updatedLoading[category] = false;

        final newErrors = Map<String, String?>.from(state.errors);
        newErrors[category] = null;

        final updatedPagination = Map<String, bool>.from(state.pagination);
        updatedPagination[category] = articles.length >= 10; // Simple threshold

        state = state.copyWith(
          articles: newArticles,
          loading: updatedLoading,
          errors: newErrors,
          pagination: updatedPagination,
        );

        SchedulerBinding.instance.scheduleTask(() {
          if (!mounted || _loadTokens[category] != token) return;
          final current = state.articles[category];
          if (!identical(current, baseArticles)) return;
          sl<QuantizedTfIdfEngine>().updateIdfCache(baseArticles);
          final ranked = _rankingPipeline.rank(List<NewsArticle>.from(baseArticles));
          if (!mounted || _loadTokens[category] != token) return;
          final rankedArticles = Map<String, List<NewsArticle>>.from(state.articles);
          rankedArticles[category] = ranked;
          state = state.copyWith(articles: rankedArticles);
        }, Priority.idle);
      },
    );
  }

  /// Load more articles for pagination
  Future<void> loadMoreNews(String category, Locale locale) async {
    if (state.loading[category] == true || !state.hasMore(category)) return;

    final updatedLoading = Map<String, bool>.from(state.loading);
    updatedLoading[category] = true;
    state = state.copyWith(loading: updatedLoading);

    final currentArticles = state.getArticles(category);
    
    final result = await _newsRepository.getArticlesByCategory(
      category,
      language: locale.languageCode,
      // Pass last article date or ID if repository supports it
    );

    result.fold(
      (failure) {
        final newLoading = Map<String, bool>.from(state.loading);
        newLoading[category] = false;
        state = state.copyWith(loading: newLoading);
      },
      (newArticles) {
        if (newArticles.isEmpty) {
          final updatedPagination = Map<String, bool>.from(state.pagination);
          updatedPagination[category] = false;
          
          final newLoading = Map<String, bool>.from(state.loading);
          newLoading[category] = false;
          
          state = state.copyWith(loading: newLoading, pagination: updatedPagination);
          return;
        }

        // Rank the new batch
        final ranked = _rankingPipeline.rank(newArticles);
        
        // Prevent duplicates
        final Set<String> existingUrls = currentArticles.map((a) => a.url).toSet();
        final List<NewsArticle> uniqueNew = ranked.where((a) => !existingUrls.contains(a.url)).toList();

        final allArticles = Map<String, List<NewsArticle>>.from(state.articles);
        allArticles[category] = [...currentArticles, ...uniqueNew];

        final newLoading = Map<String, bool>.from(state.loading);
        newLoading[category] = false;

        final updatedPagination = Map<String, bool>.from(state.pagination);
        updatedPagination[category] = uniqueNew.length >= 5;

        state = state.copyWith(
          articles: allArticles,
          loading: newLoading,
          pagination: updatedPagination,
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


/// Main news provider
final newsProvider = StateNotifierProvider<NewsNotifier, NewsState>((ref) {
  final repo = ref.watch(newsRepositoryProvider);
  final pipeline = sl<RankingPipeline>();
  return NewsNotifier(
    newsRepository: repo,
    rankingPipeline: pipeline,
  );
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
