import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import '../../core/services/app_network_service.dart'; // Unified network service
import '../models/news_article.dart';

class HiveService {
  HiveService._(); // Private constructor prevents instantiation

  static bool _initialized = false;

  static const int _CACHE_VERSION = 2; // Increment when NewsArticle schema changes

  static Future<void> init(List<String> categories) async {
    if (_initialized) return;

    await Hive.initFlutter();
    
    // Check version and clear if needed
    final Box versionBox = await Hive.openBox('app_version');
    final int? storedVersion = versionBox.get('cache_version');
    
    if (storedVersion != _CACHE_VERSION) {
      if (kDebugMode) debugPrint('♻️ Cache version mismatch. Clearing old data...');
      await Hive.deleteFromDisk(); // Nuclear option for safety
      await Hive.initFlutter(); // Re-init after delete
      
      final Box newVersionBox = await Hive.openBox('app_version');
      await newVersionBox.put('cache_version', _CACHE_VERSION);
    }

    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(NewsArticleAdapter());
    }

    for (final String key in categories) {
      await Hive.openBox<NewsArticle>(key);
      await Hive.openBox("${key}_meta");
    }

    _initialized = true;
  }

  static bool hasArticles(String key) {
    try {
      if (!Hive.isBoxOpen(key)) return false;
      final Box<NewsArticle> box = Hive.box<NewsArticle>(key);
      return box.isNotEmpty;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Error checking articles for $key: $e');
      }
      return false;
    }
  }

  static List<NewsArticle> getArticles(String key) {
    try {
      if (!Hive.isBoxOpen(key)) return <NewsArticle>[];
      return Hive.box<NewsArticle>(key).values.toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Error getting articles for $key: $e');
      }
      return <NewsArticle>[];
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

      // ⚡ ADAPTIVE CACHE for Bangladesh: Longer cache on poor connections
      // WiFi/4G: 20min, 3G: 1hr, 2G: 3hrs
      final Duration cacheDuration = AppNetworkService().getCacheDuration();

      return age > cacheDuration.inMilliseconds;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Error checking expiry for $key: $e');
      return true; // Assume expired on error
    }
  }

  static Future<void> saveArticles(String key, List<NewsArticle> data) async {
    try {
      // 🚨 NEVER overwrite valid cache with empty list
      if (data.isEmpty) return;

      if (!Hive.isBoxOpen(key)) {
        if (kDebugMode) {
          debugPrint('⚠️ Box $key is not open, cannot save');
        }
        return;
      }

      final Box<NewsArticle> box = Hive.box<NewsArticle>(key);
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

  static void instance() {}
}
