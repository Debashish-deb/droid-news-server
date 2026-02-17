import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/news_article.dart';
import '../../domain/repositories/news_repository.dart';
import '../../core/offline_handler.dart';
import '../../infrastructure/ai/ranking/pipeline/ranking_pipeline.dart';
import '../../infrastructure/ai/engine/quantized_tfidf_engine.dart';
import '../../core/di/providers.dart';
import '../../infrastructure/services/ml/enhanced_ai_categorizer.dart' show EnhancedAICategorizer;


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
    required QuantizedTfIdfEngine tfIdfEngine,
  }) : _newsRepository = newsRepository,
       _rankingPipeline = rankingPipeline,
       _tfIdfEngine = tfIdfEngine,
       super(const NewsState()) {
    _initConnectivityListener();
  }

  final NewsRepository _newsRepository;
  final RankingPipeline _rankingPipeline;
  final QuantizedTfIdfEngine _tfIdfEngine;
  final EnhancedAICategorizer _aiCategorizer = EnhancedAICategorizer.instance;
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

    var result = await _newsRepository.getArticlesByCategory(
      category,
      language: locale.languageCode,
    );

    // If initial fetch is empty and not force-refreshed, trigger background sync
    await result.fold(
      (failure) async => null,
      (articles) async {
        if (articles.isEmpty && !force) {
          debugPrint('📭 Category $category is empty. Triggering auto-sync...');
          await _newsRepository.syncNews(locale: locale);
          
          // Re-fetch after sync
          result = await _newsRepository.getArticlesByCategory(
            category,
            language: locale.languageCode,
          );
        }
      },
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
        
        // Categorize articles with AI
        final categorizedArticles = await _categorizeArticles(baseArticles, locale);
        
        // STRICT FILTERING: Only keep articles that match the target category
        // (unless special 'mixed' or 'all' flows)
        final List<NewsArticle> filteredArticles;
        if (category == 'mixed' || category == 'all') {
          filteredArticles = categorizedArticles;
        } else {
          filteredArticles = categorizedArticles.where((a) => a.category == category).toList();
        }

        final newArticles = Map<String, List<NewsArticle>>.from(state.articles);
        newArticles[category] = filteredArticles;

        // Populate other categories if we loaded "mixed" or "all"
        if (category == 'mixed' || category == 'all') {
          newArticles['national'] = categorizedArticles.where((a) => a.category == 'national').toList();
          newArticles['international'] = categorizedArticles.where((a) => a.category == 'international').toList();
          newArticles['sports'] = categorizedArticles.where((a) => a.category == 'sports').toList();
          newArticles['entertainment'] = categorizedArticles.where((a) => a.category == 'entertainment').toList();
        }

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

        // FIX: Marked task as async and added await for Isolate-based ranking
        SchedulerBinding.instance.scheduleTask(() async {
          if (!mounted || _loadTokens[category] != token) return;
          final current = state.articles[category];
          if (!identical(current, filteredArticles)) return;
          
          _tfIdfEngine.updateIdfCache(filteredArticles);
          
          // Wait for background isolate ranking to complete
          final ranked = await _rankingPipeline.rank(List<NewsArticle>.from(filteredArticles));
          
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
    );

    result.fold(
      (failure) {
        final newLoading = Map<String, bool>.from(state.loading);
        newLoading[category] = false;
        state = state.copyWith(loading: newLoading);
      },
      // FIX: Success callback marked async to await ranking
      (newArticles) async {
        if (newArticles.isEmpty) {
          final updatedPagination = Map<String, bool>.from(state.pagination);
          updatedPagination[category] = false;
          
          final newLoading = Map<String, bool>.from(state.loading);
          newLoading[category] = false;
          
          state = state.copyWith(loading: newLoading, pagination: updatedPagination);
          return;
        }

        // Categorize new articles
        final categorizedNew = await _categorizeArticles(newArticles, locale);

        // STRICT FILTERING: Only keep articles that match the target category
        final List<NewsArticle> filteredNew;
        if (category == 'mixed' || category == 'all') {
          filteredNew = categorizedNew;
        } else {
          filteredNew = categorizedNew.where((a) => a.category == category).toList();
        }

        // Rank the new batch using the background Isolate
        final ranked = await _rankingPipeline.rank(filteredNew);
        
        // Prevent duplicates
        final Set<String> existingUrls = currentArticles.map((a) => a.url).toSet();
        final List<NewsArticle> uniqueNew = ranked.where((a) => !existingUrls.contains(a.url)).toList();

        final allArticles = Map<String, List<NewsArticle>>.from(state.articles);
        allArticles[category] = [...currentArticles, ...uniqueNew];

        // If we are in "mixed" or "all", update the specific categories as well
        if (category == 'mixed' || category == 'all') {
          for (final article in uniqueNew) {
            final cat = article.category;
            if (['national', 'international', 'sports', 'entertainment'].contains(cat)) {
              allArticles[cat] = [...(allArticles[cat] ?? []), article];
            }
          }
        }

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

  /// Categorize articles using AI
  Future<List<NewsArticle>> _categorizeArticles(
    List<NewsArticle> articles,
    Locale locale,
  ) async {
    final categorizedArticles = <NewsArticle>[];
    final language = locale.languageCode;

    // Process in parallel batches
    const batchSize = 10;
    for (var i = 0; i < articles.length; i += batchSize) {
      final batch = articles.skip(i).take(batchSize).toList();
      
      final categorizedBatch = await Future.wait(
        batch.map((article) async {
          try {
            // Categorize with AI
            final category = await _aiCategorizer.categorizeArticle(
              title: article.title,
              description: article.description,
              content: article.fullContent.isNotEmpty 
                  ? article.fullContent 
                  : article.snippet,
              language: language,
            );

            // Return article with updated category
            return article.copyWith(category: category);
          } catch (e) {
            debugPrint('❌ Failed to categorize article: ${article.title}');
            // Fallback to 'national' for Bangladesh-based app
            return article.copyWith(category: 'national');
          }
        }),
      );

      categorizedArticles.addAll(categorizedBatch);
      
      // Small delay between batches to respect rate limits
      if (i + batchSize < articles.length) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }

    return categorizedArticles;
  }
}


/// Main news provider
final newsProvider = StateNotifierProvider<NewsNotifier, NewsState>((ref) {
  final repo = ref.watch(newsRepositoryProvider);
  final pipeline = ref.watch(rankingPipelineProvider);
  final engine = ref.watch(tfIdfEngineProvider);
  return NewsNotifier(
    newsRepository: repo,
    rankingPipeline: pipeline,
    tfIdfEngine: engine,
  );
});

/// Provider for Home screen category
final homeCategoryProvider = StateProvider<String>((ref) => 'national');

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