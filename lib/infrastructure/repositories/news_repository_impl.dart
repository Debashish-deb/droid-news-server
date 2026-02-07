// For rootBundle
import 'package:flutter/widgets.dart';
import '../../core/architecture/either.dart';
import '../../core/architecture/failure.dart';
import '../../domain/entities/news_article.dart';
import '../../domain/repositories/news_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/drift.dart';
import '../../platform/persistence/app_database.dart';
import '../../bootstrap/di/injection_container.dart' show sl;
import '../services/rss_service.dart';
import 'package:injectable/injectable.dart';
import '../../core/telemetry/structured_logger.dart';

/// Secure Implementation of NewsRepository using Drift (SQLite).
@LazySingleton(as: NewsRepository)
class NewsRepositoryImpl implements NewsRepository {
  
  // Cache to avoid hitting DB for every scroll frame, though Drift is fast.
  // Using Stream is better, but maintaining interface for now.

  NewsRepositoryImpl(this._prefs, this._db, this._rssService) {
    _ensureArticlesLoaded();
  }
  final SharedPreferences _prefs;
  final AppDatabase _db;
  final RssService _rssService;
  final _logger = StructuredLogger();


  Future<void> _ensureArticlesLoaded() async {
    try {
      // First, check if we have mock "Global Tech Summit" articles
      final mockCheck = await (_db.select(_db.articles)
            ..where((t) => t.title.contains('Global Tech Summit'))
            ..limit(1))
          .getSingleOrNull();
      
      if (mockCheck != null) {
        _logger.info('Detected mock articles - clearing database...');
        await _db.delete(_db.articles).go();
        _logger.info('Mock articles cleared');
      }
      
      final count = await _db.articles.count(where: (t) => const Constant(true)).getSingle();
      if (count > 0) {
        _logger.info('Database already has $count articles');
        return;
      }

      // Fetch real news from RSS feeds
      _logger.info('Fetching initial news from RSS feeds...');
      final articles = await _fetchNewsFromRss();
      
      
      if (articles.isEmpty) {
        _logger.warn('No articles fetched from RSS');
        return;
      }

      await _saveArticlesToDb(articles);
      _logger.info('Initialized AppDatabase with ${articles.length} real articles from RSS.');
    } catch (e) {
      _logger.error('Failed to initialize DB', e);
    }
  }

  Future<void> _saveArticlesToDb(List<NewsArticle> articles) async {
    await _db.batch((batch) {
      for (final article in articles) {
        batch.insert(
          _db.articles,
          ArticlesCompanion(
            id: Value(article.url.hashCode.toString()),
            title: Value(article.title),
            description: Value(article.description),
            url: Value(article.url),
            content: Value(article.fullContent),
            imageUrl: Value(article.imageUrl),
            source: Value(article.source),
            language: Value(article.language),
            publishedAt: Value(article.publishedAt),
            category: const Value('general'), // Default
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  @override
  Future<Either<AppFailure, void>> syncNews({required Locale locale}) async {
    try {
      _logger.info('Syncing news for locale: ${locale.languageCode}...');
      
      // 1. Clear stale cache for this language (excluding bookmarks)
      // This ensures we don't show old or mis-tagged articles from previous bugs
      final bookmarkedIds = await (_db.select(_db.bookmarks).map((b) => b.articleId)).get();
      
      await (_db.delete(_db.articles)
        ..where((t) => t.language.equals(locale.languageCode))
        ..where((t) => t.id.isNotIn(bookmarkedIds))
      ).go();
      
      // 2. Fetch fresh news
      final articles = await _fetchNewsFromRss(locale: locale);
      
      if (articles.isNotEmpty) {
        await _saveArticlesToDb(articles);
        _logger.info('Synced ${articles.length} articles.');
        return const Right(null);
      } else {
        return const Left(ServerFailure('No new articles found'));
      }
    } catch (e) {
      return Left(ServerFailure('Failed to sync news: $e'));
    }
  }

  Future<List<NewsArticle>> _fetchNewsFromRss({Locale? locale}) async {
    try {
      final List<NewsArticle> articles = [];
      
      // If locale is specific, prioritize it but maybe fetch others too?
      // For now, let's fetch based on requested locale or all if null (init)
      
      if (locale == null || locale.languageCode == 'en') {
         articles.addAll(await _rssService.fetchNews(
          category: 'latest',
          locale: const Locale('en'),
        ));
      }
      
      if (locale == null || locale.languageCode == 'bn') {
        articles.addAll(await _rssService.fetchNews(
          category: 'latest',
          locale: const Locale('bn'),
        ));
      }
      
      articles.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
      
      return articles.take(50).toList();
    } catch (e) {
      _logger.error('Error fetching from RSS', e);
      return [];
    }
  }

  NewsArticle _mapToEntity(Article row) {
    return NewsArticle(
      title: row.title,
      description: row.description,
      url: row.url,
      source: row.source,
      imageUrl: row.imageUrl,
      language: row.language,
      fullContent: row.content ?? '',
      publishedAt: row.publishedAt,
      // snippet: row.content, // Not in entity?
      fromCache: true,
      // isBookmarked: isBookmarked, // Not in entity, handled by separate list/state
    );
  }

  @override
  Future<Either<AppFailure, List<NewsArticle>>> getNewsFeed({
    required int page,
    required int limit,
    String? category,
    String? language,
  }) async {
    try {
      final offset = (page - 1) * limit;
      
      // Dynamic Query Construction
      final query = _db.select(_db.articles)
        ..orderBy([(t) => OrderingTerm(expression: t.publishedAt, mode: OrderingMode.desc)])
        ..limit(limit, offset: offset);

      if (language != null) {
        query.where((t) => t.language.equals(language));
      }
      
      if (category != null && category.toLowerCase() != 'all' && category.toLowerCase() != 'latest') {
        // Simple text match simulation for category since we don't have tags yet
        final term = category.toLowerCase();
        query.where((t) => t.title.contains(term) | t.description.contains(term));
      }

      final rows = await query.get();
      final articles = rows.map((r) => _mapToEntity(r)).toList();
      
      return Right(articles);
    } catch (e) {
      return Left(ServerFailure('Failed to fetch news: $e'));
    }
  }

  @override
  Future<Either<AppFailure, NewsArticle>> getArticleById(String id) async {
    try {
      // ID in DB is hash of URL, but sometimes we pass URL itself.
      // We try both.
      final query = _db.select(_db.articles)
        ..where((t) => t.id.equals(id) | t.url.equals(id))
        ..limit(1);
      
      final row = await query.getSingleOrNull();
      if (row == null) {
         return const Left(NotFoundFailure('Article not found'));
      }
      return Right(_mapToEntity(row));
    } catch (e) {
       return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<AppFailure, void>> bookmarkArticle(String articleId) async {
    try {
      await _db.into(_db.bookmarks).insert(
        BookmarksCompanion(
           articleId: Value(articleId),
           createdAt: Value(DateTime.now()),
        ),
        mode: InsertMode.insertOrIgnore,
      );
      return const Right(null);
    } catch (e) {
      return Left(StorageFailure('Failed to bookmark: $e'));
    }
  }

  @override
  Future<Either<AppFailure, void>> unbookmarkArticle(String articleId) async {
    try {
      await (_db.delete(_db.bookmarks)..where((t) => t.articleId.equals(articleId))).go();
      return const Right(null);
    } catch (e) {
      return Left(StorageFailure('Failed to unbookmark: $e'));
    }
  }

  @override
  Future<Either<AppFailure, List<NewsArticle>>> getBookmarkedArticles() async {
    try {
      // Join Articles and Bookmarks
      final query = _db.select(_db.articles).join([
        innerJoin(_db.bookmarks, _db.bookmarks.articleId.equalsExp(_db.articles.id))
      ]);
      
      final rows = await query.get();
      // map returns List<TypedResult>
      final articles = rows.map((row) {
        final article = row.readTable(_db.articles);
        return _mapToEntity(article);
      }).toList();
      
      return Right(articles);
    } catch (e) {
      return Left(StorageFailure('Failed to fetch bookmarks: $e'));
    }
  }

  @override
  Future<Either<AppFailure, void>> markAsRead(String articleId) async {
    // Current implementation: Just persist to ReadingHistory
    try {
       await _db.into(_db.readingHistory).insert(
        ReadingHistoryCompanion(
          articleId: Value(articleId),
          readAt: Value(DateTime.now()),
        ),
        mode: InsertMode.insertOrIgnore
       );
       return const Right(null);
    } catch (e) {
       return Left(StorageFailure('Failed to mark read: $e'));
    }
  }

  @override
  Future<Either<AppFailure, List<NewsArticle>>> searchArticles({
    required String query,
    int limit = 20,
  }) async {
    try {
      final q = query.toLowerCase();
      final dbQuery = _db.select(_db.articles)
        ..where((t) => t.title.contains(q) | t.description.contains(q))
        ..limit(limit);
        
      final rows = await dbQuery.get();
      return Right(rows.map((r) => _mapToEntity(r)).toList());
    } catch (e) {
      return Left(ServerFailure('Search failed: $e'));
    }
  }

  @override
  Future<Either<AppFailure, List<NewsArticle>>> getArticlesByCategory(
    String category, {
    int page = 1,
    int limit = 20,
    String? language,
  }) {
    return getNewsFeed(page: page, limit: limit, category: category, language: language);
  }

  @override
  Future<Either<AppFailure, void>> shareArticle(String articleId) async {
    return const Right(null);
  }
}
