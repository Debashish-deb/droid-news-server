// lib/presentation/providers/favorites_providers.dart
// ==========================================
// RIVERPOD PROVIDERS FOR FAVORITES SERVICE
// ==========================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/providers.dart';
import '../../infrastructure/persistence/favorites/favorites_service.dart';
import "../../domain/entities/news_article.dart";

// ============================================
// MAIN PROVIDER
// ============================================

/// Main favorites state provider
final favoritesProvider =
    StateNotifierProvider<FavoritesNotifier, FavoritesState>((ref) {
      final repo = ref.watch(favoritesRepositoryProvider);
      final sync = ref.watch(syncServiceProvider);
      return FavoritesNotifier(repo, sync);
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

// ============================================
// FILTERED PROVIDERS (Optimized for Screen)
// ============================================

/// Current category filter for the favorites screen
final favoriteCategoryFilterProvider = StateProvider<String>((ref) => 'All');

/// Current time filter for the favorites screen
final favoriteTimeFilterProvider = StateProvider<String>((ref) => 'All');

/// Memoized list of filtered favorites to prevent expensive build-time calculations
final filteredFavoritesProvider = Provider<List<Map<String, dynamic>>>((ref) {
  final categoryFilter = ref.watch(favoriteCategoryFilterProvider);
  final timeFilter = ref.watch(favoriteTimeFilterProvider);

  final articles = ref.watch(favoriteArticlesProvider);
  final magazines = ref.watch(favoriteMagazinesProvider);
  final newspapers = ref.watch(favoriteNewspapersProvider);

  List<Map<String, dynamic>> items = [];

  // 1. Initial Category Filtering
  if (categoryFilter == 'All') {
    items = [
      ...articles.map((a) => a.toMap()),
      ...magazines,
      ...newspapers,
    ];
  } else if (categoryFilter == 'Articles') {
    items = articles.map((a) => a.toMap()).toList();
  } else if (categoryFilter == 'Magazines') {
    items = List.from(magazines);
  } else if (categoryFilter == 'Newspapers') {
    items = List.from(newspapers);
  }

  // 2. Time Filtering
  if (timeFilter == 'All') return items;

  final now = DateTime.now();
  return items.where((item) {
    final savedAtStr = item['savedAt'] as String?;
    if (savedAtStr == null) return false;
    final savedAt = DateTime.tryParse(savedAtStr);
    if (savedAt == null) return false;

    final diff = now.difference(savedAt);
    switch (timeFilter) {
      case 'Today':
        return diff.inDays == 0;
      case 'This Week':
        return diff.inDays <= 7;
      case 'Older':
        return diff.inDays > 7;
      default:
        return true;
    }
  }).toList();
});

