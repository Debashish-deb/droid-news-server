// lib/core/services/favorites_service.dart
// ========================================
// FAVORITES SERVICE (Riverpod-based)
// Manages user favorites for articles, magazines, and newspapers
// Replaces legacy FavoritesManager with StateNotifier pattern
// ========================================

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/news_article.dart';
import '../sync_service.dart';

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
  });
  final List<NewsArticle> articles;
  final List<Map<String, dynamic>> magazines;
  final List<Map<String, dynamic>> newspapers;

  FavoritesState copyWith({
    List<NewsArticle>? articles,
    List<Map<String, dynamic>>? magazines,
    List<Map<String, dynamic>>? newspapers,
  }) {
    return FavoritesState(
      articles: articles ?? this.articles,
      magazines: magazines ?? this.magazines,
      newspapers: newspapers ?? this.newspapers,
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
  FavoritesNotifier(this._prefs, this._syncService)
    : super(const FavoritesState()) {
    _loadFavorites();
    // Try syncing on startup (fire and forget)
    syncFromCloud();
  }

  final SharedPreferences _prefs;
  final SyncService _syncService;

  static const String favoritesKey = 'favorites';
  static const String magazineFavoritesKey = 'magazine_favorites';
  static const String newspaperFavoritesKey = 'newspaper_favorites';

  // ============================================
  // LOADING
  // ============================================

  void _loadFavorites() {
    final articleJson = _prefs.getStringList(favoritesKey) ?? <String>[];
    final magazineJson =
        _prefs.getStringList(magazineFavoritesKey) ?? <String>[];
    final newspaperJson =
        _prefs.getStringList(newspaperFavoritesKey) ?? <String>[];

    final articles =
        articleJson
            .map((str) => NewsArticle.fromMap(json.decode(str)))
            .toList();

    final magazines =
        magazineJson
            .map((str) => Map<String, dynamic>.from(json.decode(str)))
            .toList();

    final newspapers =
        newspaperJson
            .map((str) => Map<String, dynamic>.from(json.decode(str)))
            .toList();

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
  }

  // ============================================
  // CLOUD SYNC
  // ============================================

  /// Merges Cloud data into Local data
  Future<void> syncFromCloud() async {
    final cloudData = await _syncService.pullFavorites();
    if (cloudData == null) return;

    bool changed = false;
    final currentArticles = List<NewsArticle>.from(state.articles);
    final currentMagazines = List<Map<String, dynamic>>.from(state.magazines);
    final currentNewspapers = List<Map<String, dynamic>>.from(state.newspapers);

    // 1. Merge Articles
    if (cloudData['articles'] != null) {
      final cloudArts = cloudData['articles'] as List<dynamic>;
      for (dynamic c in cloudArts) {
        final a = NewsArticle.fromMap(c);
        if (!currentArticles.any((local) => local.url == a.url)) {
          currentArticles.add(a);
          changed = true;
        }
      }
    }

    // 2. Merge Magazines
    if (cloudData['magazines'] != null) {
      final cloudMags = cloudData['magazines'] as List<dynamic>;
      for (dynamic c in cloudMags) {
        final m = Map<String, dynamic>.from(c);
        final id = m['id'].toString();
        if (!currentMagazines.any((local) => local['id'].toString() == id)) {
          currentMagazines.add(m);
          changed = true;
        }
      }
    }

    // 3. Merge Newspapers
    if (cloudData['newspapers'] != null) {
      final cloudPapers = cloudData['newspapers'] as List<dynamic>;
      for (dynamic c in cloudPapers) {
        final n = Map<String, dynamic>.from(c);
        final id = n['id'].toString();
        if (!currentNewspapers.any((local) => local['id'].toString() == id)) {
          currentNewspapers.add(n);
          changed = true;
        }
      }
    }

    if (changed) {
      state = FavoritesState(
        articles: currentArticles,
        magazines: currentMagazines,
        newspapers: currentNewspapers,
      );
      await _saveAll();
      // Push back the unified list so cloud is up to date too
      unawaited(_syncToCloud());

      if (kDebugMode) {
        debugPrint('☁️ Synced favorites from cloud');
      }
    }
  }

  Future<void> _syncToCloud() async {
    await _syncService.pushFavorites(
      articles: state.articles,
      magazines: state.magazines,
      newspapers: state.newspapers,
    );
  }

  Future<void> _saveAll() async {
    await _saveArticles();
    await _saveMagazines();
    await _saveNewspapers();
  }

  // ============================================
  // ARTICLES
  // ============================================

  Future<void> toggleArticle(NewsArticle article) async {
    final currentArticles = List<NewsArticle>.from(state.articles);
    final exists = currentArticles.any((e) => e.url == article.url);

    if (exists) {
      currentArticles.removeWhere((e) => e.url == article.url);
    } else {
      currentArticles.add(article);
    }

    state = state.copyWith(articles: currentArticles);
    await _saveArticles();
    unawaited(_syncToCloud());

    if (kDebugMode) {
      debugPrint(
        '⭐ Toggled article favorite: ${article.title} (${exists ? 'removed' : 'added'})',
      );
    }
  }

  Future<void> toggleArticleMap(Map<String, dynamic> item) async {
    final article = NewsArticle.fromMap(item);
    await toggleArticle(article);
  }

  bool isFavoriteArticle(NewsArticle article) {
    return state.articles.any((e) => e.url == article.url);
  }

  Future<void> _saveArticles() async {
    await _prefs.setStringList(
      favoritesKey,
      state.articles.map((e) => json.encode(e.toMap())).toList(),
    );
  }

  // ============================================
  // MAGAZINES
  // ============================================

  Future<void> toggleMagazine(Map<String, dynamic> magazine) async {
    final currentMagazines = List<Map<String, dynamic>>.from(state.magazines);
    final id = magazine['id'].toString();
    final isFav = currentMagazines.any((m) => m['id'].toString() == id);

    if (isFav) {
      currentMagazines.removeWhere((m) => m['id'].toString() == id);
    } else {
      currentMagazines.add(magazine);
    }

    state = state.copyWith(magazines: currentMagazines);
    await _saveMagazines();
    unawaited(_syncToCloud());

    if (kDebugMode) {
      debugPrint(
        '⭐ Toggled magazine favorite: ${magazine['title']} (${isFav ? 'removed' : 'added'})',
      );
    }
  }

  bool isFavoriteMagazine(String id) {
    return state.magazines.any((m) => m['id'].toString() == id);
  }

  Future<void> _saveMagazines() async {
    await _prefs.setStringList(
      magazineFavoritesKey,
      state.magazines.map((m) => json.encode(m)).toList(),
    );
  }

  // ============================================
  // NEWSPAPERS
  // ============================================

  Future<void> toggleNewspaper(Map<String, dynamic> newspaper) async {
    final currentNewspapers = List<Map<String, dynamic>>.from(state.newspapers);
    final id = newspaper['id'].toString();
    final isFav = currentNewspapers.any((n) => n['id'].toString() == id);

    if (isFav) {
      currentNewspapers.removeWhere((n) => n['id'].toString() == id);
    } else {
      currentNewspapers.add(newspaper);
    }

    state = state.copyWith(newspapers: currentNewspapers);
    await _saveNewspapers();
    unawaited(_syncToCloud());

    if (kDebugMode) {
      debugPrint(
        '⭐ Toggled newspaper favorite: ${newspaper['title']} (${isFav ? 'removed' : 'added'})',
      );
    }
  }

  bool isFavoriteNewspaper(String id) {
    return state.newspapers.any((n) => n['id'].toString() == id);
  }

  Future<void> _saveNewspapers() async {
    await _prefs.setStringList(
      newspaperFavoritesKey,
      state.newspapers.map((n) => json.encode(n)).toList(),
    );
  }
}
