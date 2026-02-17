// For rootBundle
import 'package:flutter/widgets.dart';
import '../../core/architecture/either.dart';
import '../../core/architecture/failure.dart';
import '../../domain/entities/news_article.dart';
import '../../domain/repositories/news_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/drift.dart';
import '../../platform/persistence/app_database.dart';

import '../services/rss_service.dart';
import '../services/news_api_service.dart';
import '../../core/telemetry/structured_logger.dart';

/// Secure Implementation of NewsRepository using Drift (SQLite).

class NewsRepositoryImpl implements NewsRepository {
  
  // Cache to avoid hitting DB for every scroll frame, though Drift is fast.
  // Using Stream is better, but maintaining interface for now.

  NewsRepositoryImpl(this._prefs, this._db, this._rssService, this._apiService) {
    _ensureArticlesLoaded();
  }
  final SharedPreferences _prefs;
  final AppDatabase _db;
  final RssService _rssService;
  final NewsApiService _apiService;
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

      _logger.info('Bootstrapping database with categorized articles from RSS and APIs...');
      final languages = ['en', 'bn'];
      final categories = ['latest', 'national', 'international', 'sports', 'entertainment'];

      for (final lang in languages) {
        final locale = Locale(lang);
        for (final category in categories) {
          // 1. Fetch from RSS
          final rssArticles = await _rssService.fetchNews(
            category: category,
            locale: locale,
          );
          if (rssArticles.isNotEmpty) {
            await _saveArticlesToDb(rssArticles, category: category);
          }

          // 2. Fetch from APIs
          final apiArticles = <NewsArticle>[];
          apiArticles.addAll(await _apiService.fetchFromNewsData(
            category: category,
            language: lang,
          ));
          apiArticles.addAll(await _apiService.fetchFromGNews(
            category: category,
            language: lang,
          ));

          if (apiArticles.isNotEmpty) {
            await _saveArticlesToDb(apiArticles, category: category);
          }
        }
      }
      _logger.info('Initialized AppDatabase with categorized news articles.');
    } catch (e) {
      _logger.error('Failed to initialize DB', e);
    }
  }

  Future<void> _saveArticlesToDb(List<NewsArticle> articles, {String category = 'general'}) async {
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
            category: Value(category), // Use provided category
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
      
      // 2. Fetch fresh news for all categories
      final categories = ['latest', 'national', 'international', 'sports', 'entertainment'];
      int totalSynced = 0;

      for (final category in categories) {
        // 2a. Fetch from RSS
        final rssArticles = await _rssService.fetchNews(
          category: category,
          locale: locale,
        );
        if (rssArticles.isNotEmpty) {
          await _saveArticlesToDb(rssArticles, category: category);
          totalSynced += rssArticles.length;
        }

        // 2b. Fetch from APIs (if not offline)
        final apiArticles = <NewsArticle>[];
        apiArticles.addAll(await _apiService.fetchFromNewsData(
          category: category,
          language: locale.languageCode,
        ));
        apiArticles.addAll(await _apiService.fetchFromGNews(
          category: category,
          language: locale.languageCode,
        ));

        if (apiArticles.isNotEmpty) {
          await _saveArticlesToDb(apiArticles, category: category);
          totalSynced += apiArticles.length;
        }
      }
      
      if (totalSynced > 0) {
        _logger.info('Synced $totalSynced articles across categories.');
        return const Right(null);
      } else {
        return const Left(ServerFailure('No new articles found'));
      }
    } catch (e) {
      return Left(ServerFailure('Failed to sync news: $e'));
    }
  }

  // This method is now legacy or used for combined view if needed
  // Removing it to avoid confusion or potential category loss.

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

      if (category != null && category.toLowerCase() != 'all') {
        final term = category.toLowerCase();
        
        if (term == 'mixed') {
          // Special logic for 70% Bangladesh (national) and 30% World (international)
          final nationalLimit = (limit * 0.7).ceil();
          final internationalLimit = limit - nationalLimit;
          
          final nationalOffset = (page - 1) * nationalLimit;
          final internationalOffset = (page - 1) * internationalLimit;

          final nationalQuery = _db.select(_db.articles)
            ..where((t) => t.category.equals('national'))
            ..orderBy([(t) => OrderingTerm(expression: t.publishedAt, mode: OrderingMode.desc)])
            ..limit(nationalLimit, offset: nationalOffset);

          final internationalQuery = _db.select(_db.articles)
            ..where((t) => t.category.equals('international'))
            ..orderBy([(t) => OrderingTerm(expression: t.publishedAt, mode: OrderingMode.desc)])
            ..limit(internationalLimit, offset: internationalOffset);

          if (language != null) {
            nationalQuery.where((t) => t.language.equals(language));
            internationalQuery.where((t) => t.language.equals(language));
          }

          final nationalRows = await nationalQuery.get();
          final internationalRows = await internationalQuery.get();
          
          final allMixed = [...nationalRows, ...internationalRows];
          allMixed.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
          
          return Right(allMixed.map((r) => _mapToEntity(r)).toList());
        }

        // Standard category filtering
        query.where((t) => t.category.equals(term));
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
