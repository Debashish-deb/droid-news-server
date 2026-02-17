// lib/presentation/providers/favorites_providers.dart
// ==========================================
// RIVERPOD PROVIDERS FOR FAVORITES SERVICE
// ==========================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/providers.dart';
import '../../infrastructure/persistence/favorites_service.dart';
import "../../domain/entities/news_article.dart";

// ============================================
// MAIN PROVIDER
// ============================================

/// Main favorites state provider
final favoritesProvider =
    StateNotifierProvider<FavoritesNotifier, FavoritesState>((ref) {
      final repo = ref.watch(favoritesRepositoryProvider);
      return FavoritesNotifier(repo);
    });

// ============================================
// CONVENIENCE PROVIDERS
// ============================================

/// List of favorite articles
final favoriteArticlesProvider = Provider<List<NewsArticle>>((ref) {
  return ref.watch(favoritesProvider).articles;
});

/// List of favorite magazines
final favoriteMagazinesProvider = Provider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(favoritesProvider).magazines;
});

/// List of favorite newspapers
final favoriteNewspapersProvider = Provider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(favoritesProvider).newspapers;
});

/// Count of all favorites
final favoritesCountProvider = Provider<int>((ref) {
  final state = ref.watch(favoritesProvider);
  return state.articles.length +
      state.magazines.length +
      state.newspapers.length;
});

/// Check if a specific article is favorited
Provider<bool> isFavoriteArticleProvider(NewsArticle article) {
  return Provider<bool>((ref) {
    return ref
        .watch(favoritesProvider)
        .articles
        .any((a) => a.url == article.url);
  });
}

/// Check if a specific magazine is favorited
Provider<bool> isFavoriteMagazineProvider(String id) {
  return Provider<bool>((ref) {
    return ref
        .watch(favoritesProvider)
        .magazines
        .any((m) => m['id'].toString() == id);
  });
}

/// Check if a specific newspaper is favorited
Provider<bool> isFavoriteNewspaperProvider(String id) {
  return Provider<bool>((ref) {
    return ref
        .watch(favoritesProvider)
        .newspapers
        .any((n) => n['id'].toString() == id);
  });
}
