import 'dart:async' show Timer, unawaited;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    bool scheduleLocalReclassificationBackfill = true,
    SharedPreferences? prefs,
  }) : _prefs = prefs {
    if (runBootstrap) {
      _ensureArticlesLoaded();
    }
    if (scheduleLocalReclassificationBackfill) {
      _scheduleLocalReclassificationBackfill();
    }
  }
  static const int _kTrendingWatchLimit = 30;
  final AppDatabase _db;
  final RssService _rssService;
  final StructuredLogger _logger = StructuredLogger();
  final NewsFeedCategoryClassifier _categoryClassifier;
  final SharedPreferences? _prefs;
  static const int _maxAiShadowSignalsPerSync = 6;
  static const int _maxAiShadowLogsPerSync = 0;
  static const String _disabledSourcesKey = 'disabled_news_sources';
  static const String _kReclassBackfillVersionKey =
      'ai_local_reclass_backfill_version';
  static const int _kReclassBackfillVersion = 1;
  static const Duration _kReclassBackfillDelay = Duration(seconds: 75);
  Timer? _reclassBackfillTimer;
  bool _disposed = false;
  int _aiShadowSignalsQueuedThisSync = 0;
  int _aiShadowLogsThisSync = 0;

  Future<int> countNewArticles(List<NewsArticle> articles) async {
    if (articles.isEmpty) return 0;
    // Single IN-query instead of N+1 individual lookups.
    final ids = articles
        .map((a) => NewsRepositorySyncHelper.articleIdFromUrl(a.url))
        .toList();
    final existing = await (_db.select(
      _db.articles,
    )..where((t) => t.id.isIn(ids))).get();
    final existingIdSet = existing.map((r) => r.id).toSet();
    return ids.where((id) => !existingIdSet.contains(id)).length;
  }

  void _scheduleLocalReclassificationBackfill() {
    final prefs = _prefs;
    if (prefs == null) return;
    _reclassBackfillTimer?.cancel();

    _reclassBackfillTimer = Timer(_kReclassBackfillDelay, () async {
      if (_disposed) return;
      final appliedVersion = prefs.getInt(_kReclassBackfillVersionKey) ?? 0;
      if (appliedVersion >= _kReclassBackfillVersion) return;
      try {
        final updated = await reclassifyRecentCachedArticles();
        await prefs.setInt(
          _kReclassBackfillVersionKey,
          _kReclassBackfillVersion,
        );
        _logger.info(
          'Local reclassification backfill completed (updated=$updated, version=$_kReclassBackfillVersion).',
        );
      } catch (e, s) {
        _logger.warning('Local reclassification backfill failed', e, s);
      }
    });
  }

  void dispose() {
    _disposed = true;
    _reclassBackfillTimer?.cancel();
    _reclassBackfillTimer = null;
  }

  @visibleForTesting
  Future<int> reclassifyRecentCachedArticles({
    int limit = 120,
    int batchSize = 24,
  }) async {
    final rows =
        await (_db.select(_db.articles)
              ..orderBy([
                (t) => OrderingTerm(
                  expression: t.publishedAt,
                  mode: OrderingMode.desc,
                ),
              ])
              ..limit(limit))
            .get();
    if (rows.isEmpty) return 0;

    var updatedCount = 0;
    for (var offset = 0; offset < rows.length; offset += batchSize) {
      final end = (offset + batchSize) > rows.length
          ? rows.length
          : (offset + batchSize);
      final slice = rows.sublist(offset, end);
      final updates = <({String id, String category, String tagsJson})>[];

      for (final row in slice) {
        final article = _mapToEntity(row);
        final classification = await _categoryClassifier.classify(
          title: article.title,
          description: article.description,
          content: article.fullContent,
          language: article.language,
          articleId: row.id,
          feedCategory: row.category,
          collectAiSignals: false,
        );
        final sourceCategory = (row.category ?? '').trim().isEmpty
            ? 'latest'
            : row.category!;

        final canonicalCategory =
            NewsRepositorySyncHelper.resolveCanonicalCategory(
              article: article,
              classifiedCategory: classification.category,
              matchedTags: classification.matchedTags,
              sourceCategory: sourceCategory,
            );
        final canonicalTags = NewsRepositorySyncHelper.resolveCanonicalTags(
          article: article,
          matchedTags: classification.matchedTags,
          sourceCategory: sourceCategory,
          primaryCategory: canonicalCategory,
        );

        final existingTags = _decodeStoredTags(row.tags);
        if (canonicalCategory == sourceCategory &&
            _sameTagSet(existingTags, canonicalTags)) {
          continue;
        }

        updates.add((
          id: row.id,
          category: canonicalCategory,
          tagsJson: jsonEncode(canonicalTags),
        ));
        
        // Yield to the event loop so a heavy single-article classification doesn't compound 
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }

      if (updates.isNotEmpty) {
        await _db.batch((batch) {
          for (final update in updates) {
            batch.update(
              _db.articles,
              ArticlesCompanion(
                category: Value(update.category),
                tags: Value(update.tagsJson),
              ),
              where: (t) => t.id.equals(update.id),
            );
          }
        });
        updatedCount += updates.length;
      }

      // Yield between batches so the backfill stays cooperative when the app
      // is interactive on the main isolate.
      if (end < rows.length) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    }

    return updatedCount;
  }

  List<String> _decodeStoredTags(String? raw) {
    if (raw == null || raw.isEmpty) return const <String>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <String>[];
      return decoded
          .map((item) => item.toString().trim().toLowerCase())
          .where((tag) => tag.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const <String>[];
    }
  }

  bool _sameTagSet(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    final lhs = a.toSet();
    final rhs = b.map((tag) => tag.trim().toLowerCase()).toSet();
    if (lhs.length != rhs.length) return false;
    return lhs.containsAll(rhs);
  }

  Set<String> _disabledSourceUrlsSync() {
    final prefs = _prefs;
    if (prefs == null) return const <String>{};
    final disabled =
        prefs.getStringList(_disabledSourcesKey) ?? const <String>[];
    return disabled
        .map((url) => url.trim())
        .where((url) => url.isNotEmpty)
        .toSet();
  }

  Set<String> _disabledSourceHostsSync() {
    final disabledUrls = _disabledSourceUrlsSync();
    if (disabledUrls.isEmpty) return const <String>{};

    final hosts = <String>{};
    for (final rawUrl in disabledUrls) {
      final uri = Uri.tryParse(rawUrl);
      final host = uri?.host.trim().toLowerCase();
      if (host == null || host.isEmpty) continue;
      if (host.startsWith('www.')) {
        hosts.add(host.substring(4));
      } else {
        hosts.add(host);
      }
    }
    return hosts;
  }

  bool _isArticleFromDisabledHost(Article row, Set<String> disabledHosts) {
    if (disabledHosts.isEmpty) return false;
    final url = row.url.trim().toLowerCase();
    if (url.isEmpty) return false;

    for (final host in disabledHosts) {
      if (host.isEmpty) continue;
      if (url.contains(host)) return true;
    }
    return false;
  }

  List<Article> _filterDisabledSourceRows(List<Article> rows) {
    final disabledHosts = _disabledSourceHostsSync();
    if (disabledHosts.isEmpty || rows.isEmpty) return rows;
    return rows
        .where((row) => !_isArticleFromDisabledHost(row, disabledHosts))
        .toList(growable: false);
  }

  // removed unused constants

  Future<void> _ensureArticlesLoaded() async {
    try {
      // Check for and remove stale mock articles.
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
        'Bootstrapping: fetching latest feed first for fast first paint...',
      );
      const languages = <String>['en', 'bn'];
      final disabledUrls = _disabledSourceUrlsSync();
      final disabledArg = disabledUrls.isEmpty ? null : disabledUrls;

      // ── Step 1: Fetch 'latest' for both languages first (fast first paint) ──
      for (final lang in languages) {
        final rssArticles = await _rssService.fetchNews(
          category: 'latest',
          locale: Locale(lang),
          disabledUrls: disabledArg,
        );
        if (rssArticles.isNotEmpty) {
          await _saveArticlesToDb(rssArticles, category: 'latest');
        }
      }

      // ── Step 2: Remaining categories in parallel, in background ──────────
      const remainingCategories = <String>[
        'national',
        'international',
        'sports',
        'entertainment',
      ];
      unawaited(
        Future.wait(<Future<void>>[
          for (final lang in languages)
            for (final category in remainingCategories)
              _fetchAndSaveCategory(
                category: category,
                lang: lang,
                disabledUrls: disabledArg,
              ),
        ]).then((_) {
          _logger.log('Background bootstrap complete.', level: Level.debug);
        }),
      );
    } catch (e) {
      _logger.error('Failed to initialize DB', e);
    }
  }

  Future<void> _fetchAndSaveCategory({
    required String category,
    required String lang,
    Set<String>? disabledUrls,
  }) async {
    try {
      final articles = await _rssService.fetchNews(
        category: category,
        locale: Locale(lang),
        disabledUrls: disabledUrls,
      );
      if (articles.isNotEmpty) {
        await _saveArticlesToDb(articles, category: category);
      }
    } catch (e) {
      _logger.warning('Background bootstrap failed for $category/$lang', e);
    }
  }

  /// Write articles immediately using provisional RSS source category,
  /// then run AI classification asynchronously in the background.
  /// This makes articles visible in <200ms instead of waiting for AI (2–12s).
  Future<int> _saveArticlesToDb(
    List<NewsArticle> articles, {
    String category = 'general',
  }) async {
    if (articles.isEmpty) return 0;

    // ── Step 1: Immediate batch insert with provisional category ────────────
    final Map<String, NewsArticle> idToArticle = {};
    await _db.batch((batch) {
      for (final article in articles) {
        final id = NewsRepositorySyncHelper.articleIdFromUrl(article.url);
        idToArticle[id] = article;
        batch.insert(
          _db.articles,
          ArticlesCompanion(
            id: Value(id),
            title: Value(article.title),
            description: Value(article.description),
            url: Value(article.url),
            content: Value(article.fullContent),
            imageUrl: Value(article.imageUrl),
            source: Value(article.source),
            language: Value(article.language),
            publishedAt: Value(article.publishedAt),
            // Use RSS feed category as provisional — AI will refine it later.
            category: Value(category),
            tags: Value(jsonEncode(<String>[])),
          ),
          mode: InsertMode.insertOrIgnore,
        );
      }
    });

    final inserted = idToArticle.length;

    // ── Step 2: AI classification in background — never blocks the caller ──
    unawaited(
      Future.microtask(() async {
        try {
          final updates = <({String id, String category, String tagsJson})>[];
          for (final entry in idToArticle.entries) {
            final id = entry.key;
            final article = entry.value;
            final shouldCollectSignals =
                NewsRepositorySyncHelper.homeFeedCategories.contains(
                  category,
                ) &&
                _aiShadowSignalsQueuedThisSync < _maxAiShadowSignalsPerSync;
            if (shouldCollectSignals) _aiShadowSignalsQueuedThisSync++;

            final classification = await _categoryClassifier.classify(
              title: article.title,
              description: article.description,
              content: article.fullContent,
              language: article.language,
              articleId: id,
              feedCategory: category,
              collectAiSignals: shouldCollectSignals,
              onAiInsight: shouldCollectSignals ? _queueAiShadowInsight : null,
            );

            final canonicalCategory =
                NewsRepositorySyncHelper.resolveCanonicalCategory(
                  article: article,
                  classifiedCategory: classification.category,
                  matchedTags: classification.matchedTags,
                  sourceCategory: category,
                );
            final canonicalTags = NewsRepositorySyncHelper.resolveCanonicalTags(
              article: article,
              matchedTags: classification.matchedTags,
              sourceCategory: category,
              primaryCategory: canonicalCategory,
            );
            updates.add((
              id: id,
              category: canonicalCategory,
              tagsJson: jsonEncode(canonicalTags),
            ));
            
            // Yield to the event loop to prevent UI stutter/unresponsiveness
            await Future<void>.delayed(const Duration(milliseconds: 2));
          }

          if (updates.isNotEmpty) {
            await _db.batch((batch) {
              for (final u in updates) {
                batch.update(
                  _db.articles,
                  ArticlesCompanion(
                    category: Value(u.category),
                    tags: Value(u.tagsJson),
                  ),
                  where: (t) => t.id.equals(u.id),
                );
              }
            });
          }
        } catch (e) {
          _logger.warning('Background AI classification failed', e);
        }
      }),
    );

    return inserted;
  }

  Future<void> _queueAiShadowInsight(Map<String, dynamic> insight) async {
    if (!kDebugMode) return;
    if (_maxAiShadowLogsPerSync <= 0) return;

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

  // SharedPreferences key prefix for last-synced timestamps.
  static const String _kSyncTsPrefix = 'news_sync_ts_';

  String _syncTsKey(String lang, String cat) => '$_kSyncTsPrefix${lang}_$cat';

  @override
  Future<Either<AppFailure, int>> syncNews({
    required Locale locale,
    bool force = false,
    String? category,
  }) async {
    try {
      _aiShadowLogsThisSync = 0;
      _aiShadowSignalsQueuedThisSync = 0;

      final syncCategory = NewsRepositorySyncHelper.resolveSyncCategory(
        category,
      );
      final bool isHomeLatestSync = syncCategory == 'latest';
      // Keep home startup refresh constrained to the visible feed. Expanding
      // "latest" into several categories creates a large burst of RSS work
      // during cold start and is the main source of the early startup jank.
      final categoriesToSync = isHomeLatestSync
          ? <String>['latest']
          : <String>[syncCategory];

      int totalSynced = 0;
      var sawSuccessfulRefresh = false;
      var skippedBecauseFreshCache = false;
      var attemptedFetch = false;
      final lang = locale.languageCode;
      final prefs = _prefs;
      final disabledUrls = _disabledSourceUrlsSync();
      final disabledArg = disabledUrls.isEmpty ? null : disabledUrls;

      for (final cat in categoriesToSync) {
        // ── Persistent TTL check: skip network if data is fresh ─────────────
        if (!force && prefs != null) {
          final tsKey = _syncTsKey(lang, cat);
          final lastSyncMs = prefs.getInt(tsKey);
          if (lastSyncMs != null) {
            final lastSync = DateTime.fromMillisecondsSinceEpoch(lastSyncMs);
            // Use network-aware cache duration (30 min–4 h).
            // For 'latest' always use at most 30 min to keep home feed fresh.
            final cacheDur = cat == 'latest'
                ? const Duration(minutes: 30)
                : const Duration(hours: 1);
            if (DateTime.now().difference(lastSync) < cacheDur) {
              skippedBecauseFreshCache = true;
              _logger.log(
                'Skipping sync for $cat/$lang — cache still fresh (${DateTime.now().difference(lastSync).inMinutes}m ago)',
                level: Level.debug,
              );
              continue;
            }
          }
        }

        // ── Fetch from RSS ──────────────────────────────────────────────────
        attemptedFetch = true;
        final rssArticles = await _rssService.fetchNews(
          category: cat,
          locale: locale,
          disabledUrls: disabledArg,
        );
        final fetchWasSuccessful = _rssService.wasLastFetchSuccessful(
          category: cat,
          language: lang,
        );
        sawSuccessfulRefresh = sawSuccessfulRefresh || fetchWasSuccessful;
        if (rssArticles.isNotEmpty) {
          totalSynced += await _saveArticlesToDb(rssArticles, category: cat);
        }
        // Persist successful sync timestamp, even when the feed has no new
        // articles. This prevents repeated network refreshes after 304/empty.
        if (prefs != null && fetchWasSuccessful) {
          await prefs.setInt(
            _syncTsKey(lang, cat),
            DateTime.now().millisecondsSinceEpoch,
          );
        }
      }

      if (totalSynced > 0) {
        // Purge stale articles (>7 days) while preserving bookmarks.
        final bookmarkedIds =
            await (_db.select(_db.bookmarks).map((b) => b.articleId)).get();
        final cutoff = DateTime.now().subtract(const Duration(days: 7));

        final deleteQuery = _db.delete(_db.articles)
          ..where((t) => t.language.equals(lang))
          ..where((t) => t.publishedAt.isSmallerThanValue(cutoff));

        if (bookmarkedIds.isNotEmpty) {
          deleteQuery.where((t) => t.id.isNotIn(bookmarkedIds));
        }

        await deleteQuery.go();

        _logger.info('Synced $totalSynced articles across categories.');
        return Right(totalSynced);
      }
      if (sawSuccessfulRefresh) {
        return const Right(0);
      }
      if (skippedBecauseFreshCache || attemptedFetch) {
        // Cache-hit / no-new-data should keep the UI stable rather than show a
        // fatal feed error on revisit.
        return const Right(0);
      }
      return const Left(ServerFailure('No news sources available'));
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

          final allMixed = _filterDisabledSourceRows([
            ...nationalRows,
            ...internationalRows,
          ]);
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
      final allArticles = _filterDisabledSourceRows(
        rows,
      ).map((r) => _mapToEntity(r)).toList();

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
      return Right(
        _filterDisabledSourceRows(rows).map((r) => _mapToEntity(r)).toList(),
      );
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
    final disabledHosts = _disabledSourceHostsSync();
    final bool hasDisabledSources = disabledHosts.isNotEmpty;

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
    // Latest: show full live set for the category.
    if (normalizedCategory == 'trending') {
      query.limit(
        hasDisabledSources ? _kTrendingWatchLimit * 6 : _kTrendingWatchLimit,
      );
    }

    return query.watch().map((rows) {
      var filtered = rows;
      if (hasDisabledSources && rows.isNotEmpty) {
        filtered = rows
            .where((row) => !_isArticleFromDisabledHost(row, disabledHosts))
            .toList(growable: false);
      }

      if (normalizedCategory == 'trending' &&
          filtered.length > _kTrendingWatchLimit) {
        filtered = filtered.take(_kTrendingWatchLimit).toList(growable: false);
      }

      return filtered
          .map((row) => _mapToEntity(row))
          .toList()
          .cast<NewsArticle>();
    });
  }

  @override
  Future<Either<AppFailure, void>> shareArticle(String articleId) async {
    return const Right(null);
  }
}
