import 'dart:ui';
import 'package:flutter/foundation.dart';
import '../../core/architecture/either.dart';
import '../../core/architecture/failure.dart';
import '../../core/errors/error_handler.dart';
import '../models/news_article.dart';
import '../services/rss_service.dart';
import '../services/hive_service.dart';
import '../../core/offline_handler.dart';

/// Repository responsible for fetching news from Network (RSS) or Local Cache (Hive).
/// Implements "Offline-First" logic and "Adaptive Caching".
class NewsRepository {

  NewsRepository({RssService? rssService})
    : _rssService = rssService ?? RssService();
  final RssService _rssService;

  /// Fetch news for a specific category and locale.
  /// Returns [Right] with List of [NewsArticle] or [Left] with [AppFailure].
  Future<Either<AppFailure, List<NewsArticle>>> getNews({
    required String category,
    required Locale locale,
    bool forceRefresh = false,
  }) async {
    final bool isOffline = await OfflineHandler.isOffline();
    final bool hasCache = HiveService.hasArticles(category);
    final bool isExpired = HiveService.isExpired(category);

    // 1. USE CACHE if:
    //    - We are offline (must use cache)
    //    - OR Cache is valid AND we are not forcing a refresh
    if (isOffline || (!forceRefresh && !isExpired && hasCache)) {
      if (hasCache) {
        final cachedData = HiveService.getArticles(category);
        return Right(_sortArticles(cachedData));
      } else if (isOffline) {
        // No internet and no cache
        return const Left(
          NetworkFailure(
            'No internet connection and no cached data available.',
          ),
        );
      }
    }

    // 2. FETCH FROM NETWORK
    try {
      List<NewsArticle> articles = await _rssService.fetchNews(
        category: category,
        locale: locale,
      );

      if (articles.isEmpty) {
        // Double check with preferred RSS directly
        articles = await _rssService.fetchNews(
          category: category,
          locale: locale,
          preferRss: true,
        );
      }

      if (articles.isNotEmpty) {
        // SUCCESS: Cache and return
        await HiveService.saveArticles(category, articles);
        return Right(_sortArticles(articles));
      } else {
        throw Exception('No articles found from network.');
      }
    } catch (e, stackTrace) {
      debugPrint('⚠️ Network fetch failed: $e');

      // 3. FALLBACK TO CACHE
      // If network fails, try to return stale cache gracefully
      if (hasCache) {
        final cachedData = HiveService.getArticles(category);
        // We might want to indicate it's stale, but for now just return success
        return Right(_sortArticles(cachedData));
      }

      // Propagate error if no cache exists
      return Left(ErrorHandler.handle(e, stackTrace));
    }
  }

  /// Helper to sort articles by date descending
  List<NewsArticle> _sortArticles(List<NewsArticle> articles) {
    if (articles.isEmpty) return articles;
    // Create a copy to avoid mutating cache directly
    final List<NewsArticle> sorted = List<NewsArticle>.from(articles);
    sorted.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return sorted;
  }
}
