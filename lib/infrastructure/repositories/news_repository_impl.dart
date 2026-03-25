import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:logger/logger.dart';
import '../../core/architecture/either.dart';
import '../../core/architecture/failure.dart';
import '../../domain/entities/news_article.dart';
import '../../domain/repositories/news_repository.dart';
import 'dart:convert';
import 'package:drift/drift.dart';
import '../../platform/persistence/app_database.dart';

import 'news/news_repository_sync_helper.dart';
import 'news/news_repository_mapper.dart';

import '../services/news/rss_service.dart';
import '../services/ml/news_feed_category_classifier.dart';
import '../../core/telemetry/structured_logger.dart';

/// Secure Implementation of NewsRepository using Drift (SQLite).

class NewsRepositoryImpl implements NewsRepository {
  // Cache to avoid hitting DB for every scroll frame, though Drift is fast.
  // Using Stream is better, but maintaining interface for now.

  NewsRepositoryImpl(
    this._db,
    this._rssService,
    this._categoryClassifier, {
    bool runBootstrap = true,
  }) {
    if (runBootstrap) {
      _ensureArticlesLoaded();
    }
  }
  final AppDatabase _db;
  final RssService _rssService;
  final StructuredLogger _logger = StructuredLogger();
  final NewsFeedCategoryClassifier _categoryClassifier;
  static const int _maxAiShadowLogsPerSync = 8;
  int _aiShadowLogsThisSync = 0;

  Future<int> countNewArticles(List<NewsArticle> articles) async {
    int count = 0;
    for (final article in articles) {
      final id = NewsRepositorySyncHelper.articleIdFromUrl(article.url);
      final exists = await (_db.select(
        _db.articles,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (exists == null) count++;
    }
    return count;
  }

  // removed unused constants

  Future<void> _ensureArticlesLoaded() async {
    try {
      // First, check if we have mock "Global Tech Summit" articles
      final mockCheck =
          await (_db.select(_db.articles)
                ..where((t) => t.title.contains('Global Tech Summit'))
                ..limit(1))
              .getSingleOrNull();

      if (mockCheck != null) {
        _logger.info('Detected mock articles - clearing database...');
        await _db.delete(_db.articles).go();
        _logger.info('Mock articles cleared');
      }

      final count = await _db.articles
          .count(where: (t) => const Constant(true))
          .getSingle();
      if (count > 0) {
        _logger.log('Database already has $count articles', level: Level.debug);
        return;
      }

      _logger.info(
        'Bootstrapping database with categorized articles from RSS and APIs...',
      );
      final languages = ['en', 'bn'];
      final categories = [
        'latest',
        'national',
        'international',
        'sports',
        'entertainment',
      ];

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

          // API calls are stubbed in NewsApiService to return [] as we rely on RSS.
        }
      }
      _logger.log(
        'Initialized AppDatabase with categorized news articles.',
        level: Level.debug,
      );
    } catch (e) {
      _logger.error('Failed to initialize DB', e);
    }
  }

  Future<int> _saveArticlesToDb(
    List<NewsArticle> articles, {
    String category = 'general',
  }) async {
    final List<
      ({
        NewsArticle article,
        TagDrivenCategorizationResult classification,
        String id,
      })
    >
    results = [];

    for (final article in articles) {
      final canonicalId = NewsRepositorySyncHelper.articleIdFromUrl(
        article.url,
      );
      final classification = await _categoryClassifier.classify(
        title: article.title,
        description: article.description,
        content: article.fullContent,
        language: article.language,
        articleId: canonicalId,
        feedCategory: category,
        collectAiSignals: NewsRepositorySyncHelper.homeFeedCategories.contains(
          category,
        ),
        onAiInsight: _queueAiShadowInsight,
      );
      results.add((
        article: article,
        classification: classification,
        id: canonicalId,
      ));
    }

    int inserted = 0;
    await _db.batch((batch) {
      for (final res in results) {
        inserted++;
        final canonicalCategory =
            NewsRepositorySyncHelper.resolveCanonicalCategory(
              article: res.article,
              classifiedCategory: res.classification.category,
              matchedTags: res.classification.matchedTags,
              sourceCategory: category,
            );
        final canonicalTags = NewsRepositorySyncHelper.resolveCanonicalTags(
          article: res.article,
          matchedTags: res.classification.matchedTags,
          sourceCategory: category,
        );
        batch.insert(
          _db.articles,
          ArticlesCompanion(
            id: Value(res.id),
            title: Value(res.article.title),
            description: Value(res.article.description),
            url: Value(res.article.url),
            content: Value(res.article.fullContent),
            imageUrl: Value(res.article.imageUrl),
            source: Value(res.article.source),
            language: Value(res.article.language),
            publishedAt: Value(res.article.publishedAt),
            category: Value(canonicalCategory),
            tags: Value(jsonEncode(canonicalTags)),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
    return inserted;
  }

  Future<void> _queueAiShadowInsight(Map<String, dynamic> insight) async {
    if (!kDebugMode) return;

    _aiShadowLogsThisSync++;
    if (_aiShadowLogsThisSync <= _maxAiShadowLogsPerSync) {
      _logger.log('AI Shadow Insight: $insight', level: Level.debug);
      return;
    }

    if (_aiShadowLogsThisSync == _maxAiShadowLogsPerSync + 1) {
      _logger.log(
        'AI Shadow Insight logs truncated for this sync batch to reduce startup jank.',
        level: Level.debug,
      );
    }
  }

  @override
  Future<Either<AppFailure, int>> syncNews({
    required Locale locale,
    bool force = false,
    String? category,
  }) async {
    try {
      _aiShadowLogsThisSync = 0;
      _logger.info('Syncing news for locale: ${locale.languageCode}...');

      // 2. Fetch fresh news
      final syncCategory = NewsRepositorySyncHelper.resolveSyncCategory(
        category,
      );
      final bool isHomeLatestSync = syncCategory == 'latest';
      final categoriesToSync = isHomeLatestSync
          ? (force
                ? <String>[
                    'latest',
                    'national',
                    'international',
                    'sports',
                    'entertainment',
                  ]
                : <String>['latest'])
          : <String>[syncCategory];

      int totalSynced = 0;

      for (final cat in categoriesToSync) {
        // 2a. Fetch from RSS
        final rssArticles = await _rssService.fetchNews(
          category: cat,
          locale: locale,
        );
        if (rssArticles.isNotEmpty) {
          totalSynced += await _saveArticlesToDb(rssArticles, category: cat);
        }

        // API calls are stubbed in NewsApiService to return [] as we rely on RSS.
      }

      if (totalSynced > 0) {
        // Purge only stale articles (>7 days old) after successful fetch.
        // This keeps offline/unstable sessions from losing usable cache.
        final bookmarkedIds =
            await (_db.select(_db.bookmarks).map((b) => b.articleId)).get();
        final cutoff = DateTime.now().subtract(const Duration(days: 7));
        await (_db.delete(_db.articles)
              ..where((t) => t.language.equals(locale.languageCode))
              ..where((t) => t.publishedAt.isSmallerThanValue(cutoff))
              ..where((t) => t.id.isNotIn(bookmarkedIds)))
            .go();

        _logger.info('Synced $totalSynced articles across categories.');
        return Right(totalSynced);
      } else {
        return const Left(ServerFailure('No new articles found'));
      }
    } catch (e) {
      return Left(ServerFailure('Failed to sync news: $e'));
    }
  }

  // This method is now legacy or used for combined view if needed
  // Removing it to avoid confusion or potential category loss.

  NewsArticle _mapToEntity(Article row) => row.toDomainEntity();

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
        ..orderBy([
          (t) =>
              OrderingTerm(expression: t.publishedAt, mode: OrderingMode.desc),
        ])
        ..limit(limit, offset: offset);

      if (language != null) {
        query.where((t) => t.language.equals(language));
      }

      if (category != null && category.toLowerCase() != 'all') {
        final normalizedCategory = category.toLowerCase();
        final effectiveCategory = NewsRepositorySyncHelper.resolveSyncCategory(
          normalizedCategory,
        );
        if (normalizedCategory != effectiveCategory) {
          // If the category was resolved to a different one, we might need to adjust the query
          // For now, we'll just use the effective category in the query.
          // This block is primarily for logging or future complex routing.
          _logger.info(
            'Category "$normalizedCategory" resolved to "$effectiveCategory"',
          );
        }

        if (normalizedCategory == 'mixed') {
          // Special logic for 70% Bangladesh (national) and 30% World (international)
          final nationalLimit = (limit * 0.7).ceil();
          final internationalLimit = limit - nationalLimit;

          final nationalOffset = (page - 1) * nationalLimit;
          final internationalOffset = (page - 1) * internationalLimit;

          final nationalQuery = _db.select(_db.articles)
            ..where((t) => t.category.equals('national'))
            ..orderBy([
              (t) => OrderingTerm(
                expression: t.publishedAt,
                mode: OrderingMode.desc,
              ),
            ])
            ..limit(nationalLimit, offset: nationalOffset);

          final internationalQuery = _db.select(_db.articles)
            ..where((t) => t.category.equals('international'))
            ..orderBy([
              (t) => OrderingTerm(
                expression: t.publishedAt,
                mode: OrderingMode.desc,
              ),
            ])
            ..limit(
              internationalLimit.toInt(),
              offset: internationalOffset.toInt(),
            );

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
        if (normalizedCategory == 'trending') {
          // Trending = curated top stories across ALL categories.
          // No category filter needed; recency + language is sufficient.
        } else {
          query.where((t) => t.category.equals(effectiveCategory));
        }
      }

      final rows = await query.get();
      final allArticles = rows.map((r) => _mapToEntity(r)).toList();

      // Secondary filter to ensure quality and prevent miscategorized noise in strict feeds
      final articles = (category != null && category.toLowerCase() != 'all')
          ? allArticles
                .where(
                  (a) => NewsRepositorySyncHelper.matchesStrictCategory(
                    a,
                    category,
                  ),
                )
                .toList()
          : allArticles;

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
      await _db
          .into(_db.bookmarks)
          .insert(
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
      await (_db.delete(
        _db.bookmarks,
      )..where((t) => t.articleId.equals(articleId))).go();
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
        innerJoin(
          _db.bookmarks,
          _db.bookmarks.articleId.equalsExp(_db.articles.id),
        ),
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
      await _db
          .into(_db.readingHistory)
          .insert(
            ReadingHistoryCompanion(
              articleId: Value(articleId),
              readAt: Value(DateTime.now()),
            ),
            mode: InsertMode.insertOrIgnore,
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
    return getNewsFeed(
      page: page,
      limit: limit,
      category: category,
      language: language,
    );
  }

  @override
  Stream<List<NewsArticle>> watchArticles(String category, Locale locale) {
    final normalizedCategory = category.toLowerCase();

    final query = _db.select(_db.articles)
      ..where((t) {
        final langMatch = t.language.equals(locale.languageCode);
        if (normalizedCategory == 'latest' ||
            normalizedCategory == 'trending' ||
            NewsRepositorySyncHelper.homeFeedCategories.contains(
              normalizedCategory,
            )) {
          // Both latest and trending show all-language articles;
          // trending is differentiated by limiting results below.
          return langMatch;
        }
        return langMatch & t.category.equals(normalizedCategory);
      })
      ..orderBy([
        (t) => OrderingTerm(expression: t.publishedAt, mode: OrderingMode.desc),
      ]);

    // Trending: curated top-30 most recent articles.
    // Latest: unlimited (all articles).
    if (normalizedCategory == 'trending') {
      query.limit(30);
    }

    return query.watch().map((rows) {
      return rows.map((row) => _mapToEntity(row)).toList().cast<NewsArticle>();
    });
  }

  @override
  Future<Either<AppFailure, void>> shareArticle(String articleId) async {
    return const Right(null);
  }
}
