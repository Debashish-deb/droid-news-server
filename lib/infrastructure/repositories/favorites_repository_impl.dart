import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/drift.dart';
import '../../core/architecture/either.dart';
import '../../core/architecture/failure.dart';
import '../../domain/repositories/favorites_repository.dart';
import '../../domain/entities/news_article.dart';
import '../sync/services/sync_service.dart';
import '../../platform/persistence/app_database.dart';
import '../../core/utils/url_identity.dart';

class FavoritesRepositoryImpl implements FavoritesRepository {
  FavoritesRepositoryImpl(this._prefs, this._syncService, this._db) {
    _initCache();
  }
  final SharedPreferences? _prefs;
  final SyncService _syncService;
  final AppDatabase _db;
  final Set<String> _favoriteUrlKeys = {};

  // Debounce mechanism to prevent excessive syncs
  DateTime? _lastPushTime;
  Timer? _pushDebounceTimer;

  Future<void> _initCache() async {
    final result = await getFavoriteArticles();
    result.fold((l) => null, (articles) {
      _favoriteUrlKeys.clear();
      _favoriteUrlKeys.addAll(articles.map((a) => _urlKey(a.url)));
    });
  }

  static const String _magazineFavoritesKey = 'magazine_favorites';
  static const String _newspaperFavoritesKey = 'newspaper_favorites';

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
      // fromCache: true,
    );
  }

  @override
  Future<Either<AppFailure, List<NewsArticle>>> getFavoriteArticles() async {
    try {
      final query = _db.select(_db.articles).join([
        innerJoin(
          _db.bookmarks,
          _db.bookmarks.articleId.equalsExp(_db.articles.id),
        ),
      ]);

      final rows = await query.get();
      final articles = rows.map((row) {
        final article = row.readTable(_db.articles);
        return _mapToEntity(article);
      }).toList();

      return Right(articles);
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<AppFailure, void>> toggleArticle(NewsArticle article) async {
    try {
      final id = _articleId(article.url);
      final urlKey = _urlKey(article.url);

      // Check if exists
      final existing = await (_db.select(
        _db.bookmarks,
      )..where((t) => t.articleId.equals(id))).getSingleOrNull();

      if (existing != null) {
        // Remove
        await (_db.delete(
          _db.bookmarks,
        )..where((t) => t.articleId.equals(id))).go();
        _favoriteUrlKeys.remove(urlKey);
      } else {
        // Insert
        // Ensure article exists in Articles table too (integrity)
        await _db
            .into(_db.articles)
            .insert(
              ArticlesCompanion(
                id: Value(id),
                title: Value(article.title),
                url: Value(article.url),
                description: Value(article.description),
                source: Value(article.source),
                publishedAt: Value(article.publishedAt),
                imageUrl: Value(article.imageUrl),
                language: Value(article.language),
              ),
              mode: InsertMode.insertOrIgnore,
            );

        await _db
            .into(_db.bookmarks)
            .insert(
              BookmarksCompanion(
                articleId: Value(id),
                createdAt: Value(DateTime.now()),
              ),
            );
        _favoriteUrlKeys.add(urlKey);
      }

      // Don't await - let sync happen in background
      unawaited(_pushToCloud());
      return const Right(null);
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  @override
  bool isFavoriteArticle(String url) {
    return _favoriteUrlKeys.contains(_urlKey(url));
  }

  // ——————————————————————————————————————————————————————
  // Legacy SharedPreferences for non-Article entities
  // ——————————————————————————————————————————————————————

  @override
  Future<Either<AppFailure, List<Map<String, dynamic>>>>
  getFavoriteMagazines() async {
    try {
      if (_prefs == null) return const Right([]);
      final jsonList = _prefs.getStringList(_magazineFavoritesKey) ?? [];
      final items = jsonList
          .map((str) => Map<String, dynamic>.from(json.decode(str)))
          .toList();
      return Right(items);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<AppFailure, List<Map<String, dynamic>>>>
  getFavoriteNewspapers() async {
    try {
      if (_prefs == null) return const Right([]);
      final jsonList = _prefs.getStringList(_newspaperFavoritesKey) ?? [];
      final items = jsonList
          .map((str) => Map<String, dynamic>.from(json.decode(str)))
          .toList();
      return Right(items);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<AppFailure, void>> toggleMagazine(
    Map<String, dynamic> magazine,
  ) async {
    try {
      final currentResult = await getFavoriteMagazines();
      final current = currentResult.fold(
        (l) => <Map<String, dynamic>>[],
        (r) => r,
      );
      final id = magazine['id'].toString();
      final exists = current.any((x) => x['id'].toString() == id);

      if (exists) {
        current.removeWhere((x) => x['id'].toString() == id);
      } else {
        current.add(magazine);
      }

      if (_prefs == null) return const Right(null);
      await _prefs.setStringList(
        _magazineFavoritesKey,
        current.map((e) => json.encode(e)).toList(),
      );

      unawaited(_pushToCloud()); // Fire and forget
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  bool isFavoriteMagazine(String id) {
    if (_prefs == null) return false;
    final jsonList = _prefs.getStringList(_magazineFavoritesKey) ?? [];
    return jsonList.any(
      (str) => str.contains('"id":"$id"') || str.contains('"id":$id'),
    );
  }

  @override
  Future<Either<AppFailure, void>> toggleNewspaper(
    Map<String, dynamic> newspaper,
  ) async {
    try {
      final currentResult = await getFavoriteNewspapers();
      final current = currentResult.fold(
        (l) => <Map<String, dynamic>>[],
        (r) => r,
      );
      final id = newspaper['id'].toString();
      final exists = current.any((x) => x['id'].toString() == id);

      if (exists) {
        current.removeWhere((x) => x['id'].toString() == id);
      } else {
        current.add(newspaper);
      }

      if (_prefs == null) return const Right(null);
      await _prefs.setStringList(
        _newspaperFavoritesKey,
        current.map((e) => json.encode(e)).toList(),
      );

      unawaited(_pushToCloud()); // Fire and forget
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  bool isFavoriteNewspaper(String id) {
    if (_prefs == null) return false;
    final jsonList = _prefs.getStringList(_newspaperFavoritesKey) ?? [];
    return jsonList.any(
      (str) => str.contains('"id":"$id"') || str.contains('"id":$id'),
    );
  }

  @override
  Future<Either<AppFailure, void>> syncFavorites() async {
    try {
      // 1. Pull latest from cloud (contains merged state)
      final cloudData = await _syncService.pullFavorites();

      if (cloudData != null) {
        // 2. Update local storage to match cloud
        await _updateLocalFromCloud(cloudData);
      }

      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<void> _pushToCloud() async {
    // Debounce: Cancel any pending push
    _pushDebounceTimer?.cancel();

    // Schedule a new push after 2 seconds of inactivity
    _pushDebounceTimer = Timer(const Duration(seconds: 2), () async {
      // Check if we've pushed recently (within last 5 seconds)
      final now = DateTime.now();
      if (_lastPushTime != null &&
          now.difference(_lastPushTime!).inSeconds < 5) {
        return; // Skip if pushed too recently
      }

      _lastPushTime = now;

      try {
        final articlesResult = await getFavoriteArticles();
        final magazinesResult = await getFavoriteMagazines();
        final newspapersResult = await getFavoriteNewspapers();

        final articles = articlesResult.fold((l) => <NewsArticle>[], (r) => r);
        final magazines = magazinesResult.fold(
          (l) => <Map<String, dynamic>>[],
          (r) => r,
        );
        final newspapers = newspapersResult.fold(
          (l) => <Map<String, dynamic>>[],
          (r) => r,
        );

        await _syncService.pushFavorites(
          articles: articles,
          magazines: magazines,
          newspapers: newspapers,
        );
      } catch (e) {
        // Log error but don't crash UI
        debugPrint('Sync push failed: $e');
      }
    });
  }

  Future<void> _updateLocalFromCloud(Map<String, dynamic> data) async {
    if (_prefs == null) return;
    // Update Magazines
    if (data['magazines'] is List) {
      final mags = (data['magazines'] as List).cast<Map<String, dynamic>>();
      await _prefs.setStringList(
        _magazineFavoritesKey,
        mags.map((e) => json.encode(e)).toList(),
      );
    }

    // Update Newspapers
    if (data['newspapers'] is List) {
      final news = (data['newspapers'] as List).cast<Map<String, dynamic>>();
      await _prefs.setStringList(
        _newspaperFavoritesKey,
        news.map((e) => json.encode(e)).toList(),
      );
    }

    // Update Articles (Drift)
    if (data['articles'] is List) {
      final articlesList = (data['articles'] as List);
      final newArticleUrlKeys = <String>{};

      // Batch insert/update articles first
      await _db.batch((batch) {
        for (final item in articlesList) {
          if (item is Map<String, dynamic>) {
            final article = NewsArticle.fromMap(item);
            final canonicalUrlKey = _urlKey(article.url);
            newArticleUrlKeys.add(canonicalUrlKey);

            final id = _idFromCanonicalKey(canonicalUrlKey);

            batch.insert(
              _db.articles,
              ArticlesCompanion(
                id: Value(id),
                title: Value(article.title),
                url: Value(article.url),
                description: Value(article.description),
                source: Value(article.source),
                publishedAt: Value(article.publishedAt),
                imageUrl: Value(article.imageUrl),
                language: Value(article.language),
                content: Value(article.fullContent),
              ),
              mode: InsertMode.insertOrReplace,
            );

            // We can't batch insert into bookmarks blindly because of UNIQUE constraint maybe?
            // Or we should delete all bookmarks not in list?
          }
        }
      });

      // Update Bookmarks table
      // Strategy: Get all current bookmarks, find diff
      final currentBookmarks = await (_db.select(_db.bookmarks)).get();
      final currentIds = currentBookmarks.map((b) => b.articleId).toSet();

      final newIds = newArticleUrlKeys
          .map((urlKey) => _idFromCanonicalKey(urlKey))
          .toSet();

      final toDelete = currentIds.difference(newIds);
      final toAdd = newIds.difference(currentIds);

      if (toDelete.isNotEmpty) {
        await (_db.delete(
          _db.bookmarks,
        )..where((t) => t.articleId.isIn(toDelete))).go();
      }

      if (toAdd.isNotEmpty) {
        await _db.batch((batch) {
          for (final id in toAdd) {
            batch.insert(
              _db.bookmarks,
              BookmarksCompanion(
                articleId: Value(id),
                createdAt: Value(DateTime.now()),
              ),
              mode: InsertMode.insertOrIgnore,
            );
          }
        });
      }

      // Update cache
      _favoriteUrlKeys.clear();
      _favoriteUrlKeys.addAll(newArticleUrlKeys);
    }
  }

  String _urlKey(String rawUrl) {
    return UrlIdentity.canonicalize(rawUrl);
  }

  String _articleId(String rawUrl) {
    return UrlIdentity.idFromUrl(rawUrl);
  }

  String _idFromCanonicalKey(String canonicalUrlKey) {
    return canonicalUrlKey.hashCode.toString();
  }
}
