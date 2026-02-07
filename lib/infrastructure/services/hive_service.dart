import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import '../network/app_network_service.dart'; 
import '../../bootstrap/di/injection_container.dart' show sl;
import '../persistence/models/publisher_layout_model.dart' show PublisherLayoutModelAdapter;
import '../persistence/news_article.dart';

class HiveService {
  HiveService._(); 

  static bool _initialized = false;

  static const int _CACHE_VERSION = 2; 

  static Future<void> init(List<String> categories) async {
    if (_initialized) return;

    await Hive.initFlutter();
    
    final Box versionBox = await Hive.openBox('app_version');
    final int? storedVersion = versionBox.get('cache_version');
    
    if (storedVersion != _CACHE_VERSION) {
      if (kDebugMode) debugPrint('♻️ Cache version mismatch. Clearing old data...');
      await Hive.deleteFromDisk();
      await Hive.initFlutter(); 
      
      final Box newVersionBox = await Hive.openBox('app_version');
      await newVersionBox.put('cache_version', _CACHE_VERSION);
    }

    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(NewsArticleModelAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(PublisherLayoutModelAdapter());
    }

    for (final String key in categories) {
      await Hive.openBox<NewsArticleModel>(key);
      await Hive.openBox("${key}_meta");
    }

    await Hive.openBox<NewsArticleModel>('favorites'); 
    _initialized = true;
  }

  static bool hasArticles(String key) {
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

  static List<NewsArticleModel> getArticles(String key) {
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

  static bool isExpired(String key) {
    try {
      final String metaBoxKey = "${key}_meta";
      if (!Hive.isBoxOpen(metaBoxKey)) return true;

      final Box<dynamic> meta = Hive.box(metaBoxKey);
      final int? timestamp = meta.get("time") as int?;

      if (timestamp == null) return true;

      final int age = DateTime.now().millisecondsSinceEpoch - timestamp;

      
      final Duration cacheDuration = sl<AppNetworkService>().getCacheDuration();

      return age > cacheDuration.inMilliseconds;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Error checking expiry for $key: $e');
      return true; 
    }
  }

  static Future<void> saveArticles(String key, List<NewsArticleModel> data) async {
    try {
      if (data.isEmpty) return;

      if (!Hive.isBoxOpen(key)) {
        if (kDebugMode) {
          debugPrint('⚠️ Box $key is not open, cannot save');
        }
        return;
      }

      final Box<NewsArticleModel> box = Hive.box<NewsArticleModel>(key);
      await box.clear();
      await box.addAll(data);

      final String metaBoxKey = "${key}_meta";
      if (!Hive.isBoxOpen(metaBoxKey)) {
        if (kDebugMode) {
          debugPrint(
            '⚠️ Meta box $metaBoxKey is not open, cannot save timestamp',
          );
        }
        return;
      }

      final Box<dynamic> meta = Hive.box(metaBoxKey);
      await meta.put("time", DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Error saving articles for $key: $e');
      }
    }
  }


  static Future<void> addFavorite(NewsArticleModel article) async {
    try {
      final box = Hive.box<NewsArticleModel>('favorites');
      await box.put(article.url, article);
    } catch (e) {
      debugPrint('⚠️ Error adding favorite: $e');
    }
  }

  static Future<void> removeFavorite(String articleId) async {
    try {
      final box = Hive.box<NewsArticleModel>('favorites');
      await box.delete(articleId);
    } catch (e) {
      debugPrint('⚠️ Error removing favorite: $e');
    }
  }

  static bool isFavorite(String articleId) {
    if (!Hive.isBoxOpen('favorites')) return false;
    final box = Hive.box<NewsArticleModel>('favorites');
    return box.containsKey(articleId);
  }

  static List<NewsArticleModel> getFavorites() {
    if (!Hive.isBoxOpen('favorites')) return [];
    final box = Hive.box<NewsArticleModel>('favorites');
    return box.values.toList();
  }

  static NewsArticleModel? findArticleById(String id) {
    if (isFavorite(id)) {
       return Hive.box<NewsArticleModel>('favorites').get(id);
    }
    
    const categories = [
        'latest', 'national', 'international', 'magazine', 
        'sports', 'entertainment', 'technology', 'economy'
    ];
    
    for (var cat in categories) {
      if (hasArticles(cat)) {
        final articles = getArticles(cat);
        for(var article in articles) {
            if(article.url == id) return article;
        }
      }
    }
    return null;
  }

  static void instance() {}
}
