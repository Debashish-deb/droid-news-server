// lib/infrastructure/persistence/favorites_service.dart
// ========================================
// FAVORITES SERVICE (Riverpod-based)
// Manages user favorites for articles, magazines, and newspapers
// Replaces legacy FavoritesManager with StateNotifier pattern
// ========================================

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import "../../domain/entities/news_article.dart";
import '../../domain/repositories/favorites_repository.dart';

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
  FavoritesNotifier(this._repository)
    : super(const FavoritesState()) {
    _loadFavorites();
    syncFromCloud();
  }

  final FavoritesRepository _repository;


  Future<void> _loadFavorites() async {
    final articlesResult = await _repository.getFavoriteArticles();
    final magazinesResult = await _repository.getFavoriteMagazines();
    final newspapersResult = await _repository.getFavoriteNewspapers();

    final articles = articlesResult.fold((l) => <NewsArticle>[], (r) => r);
    final magazines = magazinesResult.fold((l) => <Map<String, dynamic>>[], (r) => r);
    final newspapers = newspapersResult.fold((l) => <Map<String, dynamic>>[], (r) => r);

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


  /// Merges Cloud data into Local data
  Future<void> syncFromCloud() async {
    await _repository.syncFavorites();
    await _loadFavorites(); 
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
