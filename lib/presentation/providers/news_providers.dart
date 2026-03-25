// lib/presentation/providers/news_providers.dart
// ENHANCED VERSION with Smart Categorization

import 'dart:async';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/news_article.dart';
import '../../domain/repositories/news_repository.dart';
import '../../core/persistence/offline_handler.dart';
import '../../infrastructure/ai/ranking/pipeline/ranking_pipeline.dart';
import '../../infrastructure/ai/engine/quantized_tfidf_engine.dart';
import '../../core/di/providers.dart';
import '../../infrastructure/services/ml/categorization_helper.dart';
// import '../../infrastructure/services/ml/enhanced_ai_categorizer.dart'; // Removed usage

@immutable
class NewsState {
  const NewsState({
    this.articles = const {},
    this.loading = const {},
    this.errors = const {},
    this.pagination = const {},
    this.pages = const {},
  });

  final Map<String, List<NewsArticle>> articles;
  final Map<String, bool> loading;
  final Map<String, String?> errors;
  final Map<String, bool> pagination;
  final Map<String, int> pages;

  List<NewsArticle> getArticles(String category) => articles[category] ?? [];
  bool isLoading(String category) => loading[category] ?? false;
  String? getError(String category) => errors[category];
  bool hasMore(String category) => pagination[category] ?? true;
  int pageFor(String category) => pages[category] ?? 1;

  NewsState copyWith({
    Map<String, List<NewsArticle>>? articles,
    Map<String, bool>? loading,
    Map<String, String?>? errors,
    Map<String, bool>? pagination,
    Map<String, int>? pages,
  }) {
    return NewsState(
      articles: articles ?? this.articles,
      loading: loading ?? this.loading,
      errors: errors ?? this.errors,
      pagination: pagination ?? this.pagination,
      pages: pages ?? this.pages,
    );
  }
}

const List<String> _kDefaultNewsCategories = <String>[
  'latest',
  'trending',
  'national',
  'international',
  'sports',
  'entertainment',
];

NewsState _buildInitialNewsState() {
  return NewsState(
    articles: {
      for (final category in _kDefaultNewsCategories) category: <NewsArticle>[],
    },
    loading: {for (final category in _kDefaultNewsCategories) category: false},
    errors: {for (final category in _kDefaultNewsCategories) category: null},
    pagination: {
      for (final category in _kDefaultNewsCategories) category: true,
    },
    pages: {for (final category in _kDefaultNewsCategories) category: 1},
  );
}

class NewsNotifier extends StateNotifier<NewsState> {
  NewsNotifier({
    required NewsRepository newsRepository,
    required RankingPipeline rankingPipeline,
    required QuantizedTfIdfEngine tfIdfEngine,
  }) : _newsRepository = newsRepository,
       _rankingPipeline = rankingPipeline,
       super(_buildInitialNewsState()) {
    _diag('instance created', <String, Object?>{'id': identityHashCode(this)});
    _initConnectivityListener();
  }

  final NewsRepository _newsRepository;
  final RankingPipeline _rankingPipeline;
  StreamSubscription<bool>? _connectivitySub;
  final Map<String, StreamSubscription<List<NewsArticle>>> _streamSubs = {};
  final Map<String, Locale> _streamLocales = {};
  Locale? _lastLocale;
  final Map<String, int> _loadTokens = <String, int>{};
  final Map<String, int> _streamSignatures = <String, int>{};
  final Set<String> _firstNonEmptyEmissionLogged = <String>{};
  final Set<String> _networkSyncInFlightKeys = <String>{};
  static const int _pageSize = 20;
  static const int _maxRankInput = 220;

  static const String _tag = '📰 NewsNotifier';

  void _diag(String message, [Map<String, Object?> context = const {}]) {
    if (!kDebugMode) return;
    debugPrint(
      '$_tag [startup_diag] $message${context.isEmpty ? '' : ' | $context'}',
    );
  }

  void _initConnectivityListener() {
    try {
      _connectivitySub = OfflineHandler().onConnectivityChanged.listen((
        bool isOffline,
      ) {
        if (!isOffline && _lastLocale != null) {
          _refreshActiveCategories();
        }
      });
    } catch (e) {
      _diag('connectivity listener unavailable', <String, Object?>{
        'error': '$e',
      });
      _connectivitySub = null;
    }
  }

  void _refreshActiveCategories() {
    if (_lastLocale == null) return;
    final activeCategories = _streamSubs.keys.toList(growable: false);
    if (activeCategories.isEmpty) return;
    _diag('back online: auto-refreshing active categories', <String, Object?>{
      'count': activeCategories.length,
    });
    for (final category in activeCategories) {
      unawaited(loadNews(category, _lastLocale!, force: true));
    }
  }

  Future<void> loadNews(
    String category,
    Locale locale, {
    bool force = false,
    bool syncWithNetwork = true,
  }) async {
    _diag('loadNews requested', <String, Object?>{
      'category': category,
      'locale': locale.languageCode,
      'force': force,
      'syncWithNetwork': syncWithNetwork,
      'existingCount': state.getArticles(category).length,
      'isLoading': state.isLoading(category),
    });
    _lastLocale = locale;
    _ensureCategorySlot(category);

    // 1. Ensure we are watching the stream for this category
    _setupStreamSubscription(category, locale);

    // 2. Clear previous errors for this category
    final newErrors = Map<String, String?>.from(state.errors);
    newErrors[category] = null;
    if (force) {
      final newPagination = Map<String, bool>.from(state.pagination);
      final newPages = Map<String, int>.from(state.pages);
      newPagination[category] = true;
      newPages[category] = 1;
      state = state.copyWith(
        errors: newErrors,
        pagination: newPagination,
        pages: newPages,
      );
    } else {
      state = state.copyWith(errors: newErrors);
    }

    // 3. Trigger background sync
    final isLoading = state.loading[category] ?? false;
    final syncKey = '$category:${locale.languageCode}';
    if (syncWithNetwork &&
        !isLoading &&
        !_networkSyncInFlightKeys.contains(syncKey)) {
      _networkSyncInFlightKeys.add(syncKey);
      unawaited(
        _syncWithNetwork(category, locale, force: force).whenComplete(() {
          _networkSyncInFlightKeys.remove(syncKey);
        }),
      );
    }
  }

  void _setupStreamSubscription(String category, Locale locale) {
    final hasSubscription = _streamSubs.containsKey(category);
    final cacheLocale = _streamLocales[category];

    if (hasSubscription && cacheLocale?.languageCode == locale.languageCode) {
      return;
    }

    // Cancel old subscription if exists
    if (hasSubscription) {
      _streamSubs[category]?.cancel();
      _streamSignatures.remove(category);
    }

    _streamLocales[category] = locale;
    final subscriptionLanguageCode = locale.languageCode;
    _diag('stream subscription active', <String, Object?>{
      'category': category,
      'locale': subscriptionLanguageCode,
      'hadSubscription': hasSubscription,
    });

    _streamSubs[category] = _newsRepository.watchArticles(category, locale).listen((
      articles,
    ) async {
      // Ignore late emissions from an older locale subscription.
      if (_streamLocales[category]?.languageCode != subscriptionLanguageCode) {
        return;
      }

      final signature = _buildStreamSignature(articles);
      if (_streamSignatures[category] == signature) return;

      // Guard: Don't replace a populated feed with an empty stream emission.
      // This prevents the race condition where rapid DB writes during sync
      // cause intermediate empty states to clear the UI.
      final existingArticles = state.getArticles(category);
      if (articles.isEmpty && existingArticles.isNotEmpty) {
        _diag('skipping empty stream emission', <String, Object?>{
          'category': category,
          'existingCount': existingArticles.length,
        });
        return;
      }

      final nextToken = (_loadTokens[category] ?? 0) + 1;
      _loadTokens[category] = nextToken;

      // Apply AI ranking pipeline with error handling to prevent
      // isolate crashes from clearing the feed.
      List<NewsArticle> ranked;
      final rankingInput = articles.length > _maxRankInput
          ? articles.take(_maxRankInput).toList(growable: false)
          : articles;
      try {
        ranked = await _rankingPipeline.rank(rankingInput);
      } catch (e) {
        _diag('ranking failed', <String, Object?>{
          'category': category,
          'error': '$e',
        });
        ranked = rankingInput; // Fallback: use unranked articles
      }

      if (_isHomeLatestFeed(category)) {
        ranked = _prioritizeBangladeshFeed(ranked);
      }

      if (!mounted) return;

      final isStaleEmission = _loadTokens[category] != nextToken;
      if (isStaleEmission) {
        final existing = state.getArticles(category);
        final canRescueColdStart = ranked.isNotEmpty && existing.isEmpty;
        if (!canRescueColdStart) return;
        _diag(
          'applying stale non-empty stream emission to avoid startup empty-state race',
          <String, Object?>{'category': category, 'rankedCount': ranked.length},
        );
      }

      if (ranked.isNotEmpty &&
          !_firstNonEmptyEmissionLogged.contains(category)) {
        _firstNonEmptyEmissionLogged.add(category);
        _diag('first non-empty stream emission', <String, Object?>{
          'category': category,
          'locale': subscriptionLanguageCode,
          'count': ranked.length,
          'staleEmission': isStaleEmission,
          'newestPublishedAt': ranked.first.publishedAt.toIso8601String(),
        });
      }
      _streamSignatures[category] = signature;

      final newArticles = Map<String, List<NewsArticle>>.from(state.articles);
      newArticles[category] = ranked;

      state = state.copyWith(articles: newArticles);
    });
  }

  @override
  void dispose() {
    _diag('instance disposed', <String, Object?>{'id': identityHashCode(this)});
    _connectivitySub?.cancel();
    for (final sub in _streamSubs.values) {
      sub.cancel();
    }
    super.dispose();
  }

  Future<void> _syncWithNetwork(
    String category,
    Locale locale, {
    bool force = false,
  }) async {
    final offline = await OfflineHandler.isOffline();
    if (offline) {
      _diag('network sync skipped (offline)', <String, Object?>{
        'category': category,
        'locale': locale.languageCode,
        'force': force,
      });
      if (mounted && state.getArticles(category).isEmpty) {
        final newErrors = Map<String, String?>.from(state.errors);
        newErrors[category] = 'Offline mode: showing cached news.';
        state = state.copyWith(errors: newErrors);
      }
      return;
    }

    _diag('network sync start', <String, Object?>{
      'category': category,
      'locale': locale.languageCode,
      'force': force,
    });
    final newLoading = Map<String, bool>.from(state.loading);
    newLoading[category] = true;
    state = state.copyWith(loading: newLoading);
    var syncedCount = 0;

    try {
      final syncScopeCategory = category.toLowerCase() == 'all'
          ? null
          : category;
      final result = await _newsRepository.syncNews(
        locale: locale,
        force: force,
        category: syncScopeCategory,
      );
      if (!mounted) return;
      result.fold((failure) {
        if (state.getArticles(category).isNotEmpty) return;
        final newErrors = Map<String, String?>.from(state.errors);
        newErrors[category] = failure.userMessage;
        state = state.copyWith(errors: newErrors);
      }, (count) => syncedCount = count);
    } catch (e) {
      _diag('sync failed', <String, Object?>{
        'category': category,
        'error': '$e',
      });
      if (mounted && state.getArticles(category).isEmpty) {
        final newErrors = Map<String, String?>.from(state.errors);
        newErrors[category] = 'Failed to refresh news. Please try again.';
        state = state.copyWith(errors: newErrors);
      }
    } finally {
      if (mounted) {
        final resetLoading = Map<String, bool>.from(state.loading);
        resetLoading[category] = false;
        state = state.copyWith(loading: resetLoading);
        _diag('network sync end', <String, Object?>{
          'category': category,
          'locale': locale.languageCode,
          'streamCount': state.getArticles(category).length,
          'syncedCount': syncedCount,
          'error': state.getError(category),
        });
      }
    }
  }

  Future<void> loadMoreNews(String category, Locale locale) async {
    if (state.loading[category] == true || !state.hasMore(category)) return;

    final updatedLoading = Map<String, bool>.from(state.loading);
    updatedLoading[category] = true;
    state = state.copyWith(loading: updatedLoading);

    final currentArticles = state.getArticles(category);
    final nextPage = state.pageFor(category) + 1;

    final result = await _newsRepository.getArticlesByCategory(
      category,
      page: nextPage,
      language: locale.languageCode,
    );
    if (!mounted) return;

    await result.fold<Future<void>>(
      (failure) async {
        final newLoading = Map<String, bool>.from(state.loading);
        newLoading[category] = false;
        final newErrors = Map<String, String?>.from(state.errors);
        newErrors[category] = failure.userMessage;
        state = state.copyWith(loading: newLoading, errors: newErrors);
      },
      (newArticles) async {
        if (newArticles.isEmpty) {
          final updatedPagination = Map<String, bool>.from(state.pagination);
          updatedPagination[category] = false;

          final newLoading = Map<String, bool>.from(state.loading);
          newLoading[category] = false;

          state = state.copyWith(
            loading: newLoading,
            pagination: updatedPagination,
          );
          return;
        }

        // Rank new batch
        var ranked = await _rankingPipeline.rank(newArticles);
        if (_isHomeLatestFeed(category)) {
          ranked = _prioritizeBangladeshFeed(ranked);
        }

        // Prevent duplicates
        final Set<String> existingUrls = currentArticles
            .map((a) => a.url)
            .toSet();
        final List<NewsArticle> uniqueNew = ranked
            .where((a) => !existingUrls.contains(a.url))
            .toList();

        final allArticles = Map<String, List<NewsArticle>>.from(state.articles);
        allArticles[category] = [...currentArticles, ...uniqueNew];

        final newLoading = Map<String, bool>.from(state.loading);
        newLoading[category] = false;

        final updatedPagination = Map<String, bool>.from(state.pagination);
        updatedPagination[category] = newArticles.length >= _pageSize;
        final updatedPages = Map<String, int>.from(state.pages);
        updatedPages[category] = nextPage;

        state = state.copyWith(
          articles: allArticles,
          loading: newLoading,
          pagination: updatedPagination,
          pages: updatedPages,
        );
      },
    );
  }

  void _ensureCategorySlot(String category) {
    bool updated = false;

    Map<String, List<NewsArticle>>? articlesMap;
    if (!state.articles.containsKey(category)) {
      articlesMap = Map<String, List<NewsArticle>>.from(state.articles)
        ..[category] = <NewsArticle>[];
      updated = true;
    }

    Map<String, bool>? loadingMap;
    if (!state.loading.containsKey(category)) {
      loadingMap = Map<String, bool>.from(state.loading)..[category] = false;
      updated = true;
    }

    Map<String, String?>? errorsMap;
    if (!state.errors.containsKey(category)) {
      errorsMap = Map<String, String?>.from(state.errors)..[category] = null;
      updated = true;
    }

    Map<String, bool>? paginationMap;
    if (!state.pagination.containsKey(category)) {
      paginationMap = Map<String, bool>.from(state.pagination)
        ..[category] = true;
      updated = true;
    }

    Map<String, int>? pagesMap;
    if (!state.pages.containsKey(category)) {
      pagesMap = Map<String, int>.from(state.pages)..[category] = 1;
      updated = true;
    }

    if (updated) {
      state = state.copyWith(
        articles: articlesMap ?? state.articles,
        loading: loadingMap ?? state.loading,
        errors: errorsMap ?? state.errors,
        pagination: paginationMap ?? state.pagination,
        pages: pagesMap ?? state.pages,
      );
    }
  }

  int _buildStreamSignature(List<NewsArticle> articles) {
    var hash = articles.length;
    for (final article in articles) {
      hash = Object.hash(
        hash,
        article.url,
        article.publishedAt.microsecondsSinceEpoch,
      );
    }
    return hash;
  }

  bool _isHomeLatestFeed(String category) => category == 'latest';

  List<NewsArticle> _prioritizeBangladeshFeed(List<NewsArticle> articles) {
    if (articles.length < 10) return articles;

    final bangladesh = <NewsArticle>[];
    final other = <NewsArticle>[];

    for (final article in articles) {
      if (_isBangladeshFocused(article)) {
        bangladesh.add(article);
      } else {
        other.add(article);
      }
    }

    if (bangladesh.isEmpty || other.isEmpty) return articles;

    // 4:1 mix keeps the feed primarily Bangladesh-focused while still surfacing
    // some global stories.
    const bangladeshRun = 4;
    final mixed = <NewsArticle>[];
    var bdIndex = 0;
    var otherIndex = 0;

    while (bdIndex < bangladesh.length || otherIndex < other.length) {
      for (var i = 0; i < bangladeshRun && bdIndex < bangladesh.length; i++) {
        mixed.add(bangladesh[bdIndex++]);
      }
      if (otherIndex < other.length) {
        mixed.add(other[otherIndex++]);
      }
      if (bdIndex >= bangladesh.length && otherIndex < other.length) {
        mixed.addAll(other.skip(otherIndex));
        break;
      }
      if (otherIndex >= other.length && bdIndex < bangladesh.length) {
        mixed.addAll(bangladesh.skip(bdIndex));
        break;
      }
    }

    return mixed;
  }

  bool _isBangladeshFocused(NewsArticle article) {
    if (CategorizationHelper.isBangladeshCentric(
      title: article.title,
      description: article.description,
      content: article.fullContent.isNotEmpty
          ? article.fullContent
          : article.snippet,
    )) {
      return true;
    }

    final source = article.source.toLowerCase();
    final url = article.url.toLowerCase();
    return source.contains('bangladesh') ||
        source.contains('dhaka') ||
        source.contains('bdnews') ||
        url.contains('.bd/');
  }
}

/// Main news provider
final newsProvider = StateNotifierProvider<NewsNotifier, NewsState>((ref) {
  // Keep a stable notifier instance; dependencies are long-lived services and
  // should not trigger NewsNotifier recreation through unrelated provider
  // updates (e.g., network-quality ChangeNotifier ticks).
  final repo = ref.read(newsRepositoryProvider);
  final pipeline = ref.read(rankingPipelineProvider);
  final engine = ref.read(tfIdfEngineProvider);
  return NewsNotifier(
    newsRepository: repo,
    rankingPipeline: pipeline,
    tfIdfEngine: engine,
  );
});

/// Key for persisting home category
const String _kHomeCategoryKey = 'selected_home_category';

/// Provider for Home screen category with persistence
final homeCategoryProvider =
    StateNotifierProvider<HomeCategoryNotifier, String>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return HomeCategoryNotifier(prefs);
    });

class HomeCategoryNotifier extends StateNotifier<String> {
  HomeCategoryNotifier(this._prefs)
    : super(_prefs?.getString(_kHomeCategoryKey) ?? 'latest');

  final SharedPreferences? _prefs;

  void setCategory(String category) {
    if (state != category) {
      state = category;
      _prefs?.setString(_kHomeCategoryKey, category);
    }
  }
}

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
