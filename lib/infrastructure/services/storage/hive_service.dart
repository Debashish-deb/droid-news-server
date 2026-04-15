import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import '../../network/app_network_service.dart';

import '../../persistence/models/publisher_layout_model.dart'
    show PublisherLayoutModelAdapter;
import '../../persistence/models/news_article.dart';

class HiveService {
  HiveService(this._networkService) {
    _singleton ??= this;
  }
  final AppNetworkService _networkService;

  static HiveService? _singleton;
  static bool _initialized = false;
  static Future<void>? _initFuture;

  static const int _cacheVersion = 2;
  final Set<String> _knownCategories = <String>{};

  Future<void> init(
    List<String> categories, {
    int eagerCategoryCount = 0,
    bool openFavorites = true,
  }) async {
    _knownCategories.addAll(categories);
    await _ensureInitialized();

    if (openFavorites) {
      await _ensureFavoritesBoxOpen();
    }

    final eagerCategories = categories.take(eagerCategoryCount);
    for (final key in eagerCategories) {
      await _ensureCategoryBoxesOpen(key);
    }
  }

  Future<void> prewarmCategories(
    Iterable<String> categories, {
    Duration pauseBetweenBoxes = Duration.zero,
  }) async {
    await _ensureInitialized();
    for (final key in categories) {
      await _ensureCategoryBoxesOpen(key);
      if (pauseBetweenBoxes > Duration.zero) {
        await Future<void>.delayed(pauseBetweenBoxes);
      }
    }
  }

  bool hasArticles(String key) {
    try {
      if (!Hive.isBoxOpen(key)) return false;
      final Box<NewsArticleModel> box = Hive.box<NewsArticleModel>(key);
      return box.isNotEmpty;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Error checking articles for $key: $e');
      }
      return false;
    }
  }

  List<NewsArticleModel> getArticles(String key) {
    try {
      if (!Hive.isBoxOpen(key)) return <NewsArticleModel>[];
      return Hive.box<NewsArticleModel>(key).values.toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Error getting articles for $key: $e');
      }
      return <NewsArticleModel>[];
    }
  }

  bool isExpired(String key) {
    try {
      final String metaBoxKey = "${key}_meta";
      if (!Hive.isBoxOpen(metaBoxKey)) return true;

      final Box<dynamic> meta = Hive.box(metaBoxKey);
      final int? timestamp = meta.get("time") as int?;

      if (timestamp == null) return true;

      final int age = DateTime.now().millisecondsSinceEpoch - timestamp;

      final Duration cacheDuration = _networkService.getCacheDuration();

      return age > cacheDuration.inMilliseconds;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Error checking expiry for $key: $e');
      return true;
    }
  }

  Future<void> saveArticles(String key, List<NewsArticleModel> data) async {
    try {
      if (data.isEmpty) return;
      await _ensureCategoryBoxesOpen(key);

      final Box<NewsArticleModel> box = Hive.box<NewsArticleModel>(key);
      await box.clear();
      await box.addAll(data);

      final String metaBoxKey = "${key}_meta";
      final Box<dynamic> meta = Hive.box(metaBoxKey);
      await meta.put("time", DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Error saving articles for $key: $e');
      }
    }
  }

  Future<void> addFavorite(NewsArticleModel article) async {
    try {
      await _ensureFavoritesBoxOpen();
      final box = Hive.box<NewsArticleModel>('favorites');
      await box.put(article.url, article);
    } catch (e) {
      debugPrint('⚠️ Error adding favorite: $e');
    }
  }

  Future<void> removeFavorite(String articleId) async {
    try {
      await _ensureFavoritesBoxOpen();
      final box = Hive.box<NewsArticleModel>('favorites');
      await box.delete(articleId);
    } catch (e) {
      debugPrint('⚠️ Error removing favorite: $e');
    }
  }

  bool isFavorite(String articleId) {
    if (!Hive.isBoxOpen('favorites')) return false;
    final box = Hive.box<NewsArticleModel>('favorites');
    return box.containsKey(articleId);
  }

  List<NewsArticleModel> getFavorites() {
    if (!Hive.isBoxOpen('favorites')) return [];
    final box = Hive.box<NewsArticleModel>('favorites');
    return box.values.toList();
  }

  Future<List<NewsArticleModel>> getArticlesPreview(
    String key, {
    int limit = 5,
  }) async {
    await _ensureCategoryBoxesOpen(key);
    final box = Hive.box<NewsArticleModel>(key);
    return box.values.take(limit).toList(growable: false);
  }

  NewsArticleModel? findArticleById(String id) {
    if (isFavorite(id)) {
      return Hive.box<NewsArticleModel>('favorites').get(id);
    }

    const categories = [
      'latest',
      'national',
      'international',
      'magazine',
      'sports',
      'entertainment',
      'technology',
      'economy',
    ];

    for (var cat in categories) {
      if (hasArticles(cat)) {
        final articles = getArticles(cat);
        for (var article in articles) {
          if (article.url == id) return article;
        }
      }
    }
    return null;
  }

  static HiveService instance() {
    final service = _singleton;
    if (service == null) {
      throw StateError(
        'HiveService.instance() was used before the service was initialized. '
        'Use hiveServiceProvider or construct HiveService first.',
      );
    }
    return service;
  }

  Future<void> _resetStorage() async {
    await Hive.close();
    await Hive.deleteFromDisk();
    await Hive.initFlutter();
    _initialized = false;
    _initFuture = null;
  }

  Future<void> _ensureInitialized() {
    if (_initialized) return Future<void>.value();
    final inFlight = _initFuture;
    if (inFlight != null) return inFlight;

    final future = _initializeCore();
    _initFuture = future;
    return future;
  }

  Future<void> _initializeCore() async {
    await Hive.initFlutter();

    final Box versionBox = await Hive.openBox('app_version');
    final int? storedVersion = versionBox.get('cache_version');

    if (storedVersion != _cacheVersion) {
      if (kDebugMode) {
        debugPrint('♻️ Cache version mismatch. Clearing old data...');
      }
      await _resetStorage();

      final Box newVersionBox = await Hive.openBox('app_version');
      await newVersionBox.put('cache_version', _cacheVersion);
    }

    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(NewsArticleModelAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(PublisherLayoutModelAdapter());
    }

    _initialized = true;
  }

  Future<void> _ensureCategoryBoxesOpen(String key) async {
    await _ensureInitialized();
    _knownCategories.add(key);
    if (!Hive.isBoxOpen(key)) {
      await Hive.openBox<NewsArticleModel>(key);
    }
    final metaKey = '${key}_meta';
    if (!Hive.isBoxOpen(metaKey)) {
      await Hive.openBox(metaKey);
    }
  }

  Future<void> _ensureFavoritesBoxOpen() async {
    await _ensureInitialized();
    if (!Hive.isBoxOpen('favorites')) {
      await Hive.openBox<NewsArticleModel>('favorites');
    }
  }
}
