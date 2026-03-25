// lib/infrastructure/persistence/favorites_service.dart
// ========================================
// FAVORITES SERVICE (Riverpod-based)
// Manages user favorites for articles, magazines, and newspapers
// Replaces legacy FavoritesManager with StateNotifier pattern
// ========================================
import '../../sync/services/sync_service.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import "../../../domain/entities/news_article.dart";
import '../../../domain/repositories/favorites_repository.dart';
import '../../../core/architecture/failure.dart';

// ============================================
// STATE CLASSES
// ============================================

/// Immutable state for favorites
@immutable
class FavoritesState {
  const FavoritesState({
    this.articles = const [],
    this.magazines = const [],
    this.newspapers = const [],
    this.pendingSyncUrls = const {},
  });
  final List<NewsArticle> articles;
  final List<Map<String, dynamic>> magazines;
  final List<Map<String, dynamic>> newspapers;
  final Set<String> pendingSyncUrls;

  bool isPending(String url) => pendingSyncUrls.contains(url);

  FavoritesState copyWith({
    List<NewsArticle>? articles,
    List<Map<String, dynamic>>? magazines,
    List<Map<String, dynamic>>? newspapers,
    Set<String>? pendingSyncUrls,
  }) {
    return FavoritesState(
      articles: articles ?? this.articles,
      magazines: magazines ?? this.magazines,
      newspapers: newspapers ?? this.newspapers,
      pendingSyncUrls: pendingSyncUrls ?? this.pendingSyncUrls,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FavoritesState &&
        listEquals(other.articles, articles) &&
        listEquals(other.magazines, magazines) &&
        listEquals(other.newspapers, newspapers);
  }

  @override
  int get hashCode => Object.hash(articles, magazines, newspapers);
}

// ============================================
// STATE NOTIFIER
// ============================================

/// Manages favorites state with Riverpod
class FavoritesNotifier extends StateNotifier<FavoritesState> {
  FavoritesNotifier(this._repository, this._syncService)
    : super(const FavoritesState()) {
    _loadFavorites();
    _listenToSync();
    _initialCloudSyncTimer = Timer(const Duration(seconds: 8), () {
      if (mounted) {
        unawaited(syncFromCloud());
      }
    });
  }

  final FavoritesRepository _repository;
  final SyncService _syncService;
  StreamSubscription? _syncSub;
  Timer? _initialCloudSyncTimer;

  void _listenToSync() {
    _syncSub = _syncService.pendingFavoritesStream.listen((pending) {
      if (mounted) {
        state = state.copyWith(pendingSyncUrls: pending);
      }
    });
    // Initial load
    Future.microtask(() {
      if (mounted) {
        state = state.copyWith(
          pendingSyncUrls: _syncService.getPendingFavoritesUrls(),
        );
      }
    });
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    _initialCloudSyncTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    try {
      final articlesResult = await _repository.getFavoriteArticles();
      final magazinesResult = await _repository.getFavoriteMagazines();
      final newspapersResult = await _repository.getFavoriteNewspapers();

      final articles = articlesResult.fold((l) {
        _handleLoadError(l, 'Articles');
        return <NewsArticle>[];
      }, (r) => r);

      final magazines = magazinesResult.fold((l) {
        _handleLoadError(l, 'Magazines');
        return <Map<String, dynamic>>[];
      }, (r) => r);

      final newspapers = newspapersResult.fold((l) {
        _handleLoadError(l, 'Newspapers');
        return <Map<String, dynamic>>[];
      }, (r) => r);

      state = FavoritesState(
        articles: articles,
        magazines: magazines,
        newspapers: newspapers,
      );

      if (kDebugMode) {
        debugPrint(
          '📚 Loaded favorites: ${articles.length} articles, ${magazines.length} magazines, ${newspapers.length} newspapers',
        );
      }
    } catch (e, stack) {
      debugPrint('❌ Uncaught error during favorites load: $e');
      FirebaseCrashlytics.instance.recordError(
        e,
        stack,
        reason: 'Favorites load crash',
      );
    }
  }

  void _handleLoadError(AppFailure failure, String context) {
    debugPrint('⚠️ Favorites load error ($context): ${failure.message}');
    FirebaseCrashlytics.instance.recordError(
      failure,
      StackTrace.current,
      reason: 'Failed to load $context favorites',
    );
  }

  /// Merges Cloud data into Local data
  Future<void> syncFromCloud() async {
    try {
      await _repository.syncFavorites();
      await _loadFavorites();
    } catch (e, stack) {
      debugPrint('⚠️ Favorites cloud sync skipped: $e');
      FirebaseCrashlytics.instance.recordError(
        e,
        stack,
        reason: 'Favorites cloud sync failed',
      );
    }
  }

  Future<void> toggleArticle(NewsArticle article) async {
    await _repository.toggleArticle(article);
    await _loadFavorites();
  }

  Future<void> toggleArticleMap(Map<String, dynamic> item) async {
    final article = NewsArticle.fromMap(item);
    await toggleArticle(article);
  }

  bool isFavoriteArticle(NewsArticle article) {
    return state.articles.any((e) => e.url == article.url);
  }

  Future<void> toggleMagazine(Map<String, dynamic> magazine) async {
    await _repository.toggleMagazine(magazine);
    await _loadFavorites();
  }

  bool isFavoriteMagazine(String id) {
    return state.magazines.any((m) => m['id'].toString() == id);
  }

  Future<void> toggleNewspaper(Map<String, dynamic> newspaper) async {
    await _repository.toggleNewspaper(newspaper);
    await _loadFavorites();
  }

  bool isFavoriteNewspaper(String id) {
    return state.newspapers.any((n) => n['id'].toString() == id);
  }
}
