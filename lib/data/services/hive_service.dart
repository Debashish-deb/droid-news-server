// lib/data/services/hive_service.dart

import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/news_article.dart';

class HiveService {
  HiveService._();

  /// How long before cached articles expire.
  static const Duration cacheDuration = Duration(minutes: 30);

  /// Initialize Hive & open one articles‐box and one meta‐box per category.
  /// 
  /// Pass in exactly the list of category keys you're using (e.g. from
  /// your RSS service). Hive will register the adapter (once) and open
  /// two boxes for each category.
  static Future<void> init(List<String> categories) async {
    await Hive.initFlutter();

    // Register the adapter if not already done
    final adapterId = NewsArticleAdapter().typeId;
    if (!Hive.isAdapterRegistered(adapterId)) {
      Hive.registerAdapter(NewsArticleAdapter());
    }

    // Open a box for each category and its metadata
    for (final cat in categories) {
      final boxName = _boxName(cat);
      final metaName = _metaName(cat);

      if (!Hive.isBoxOpen(boxName)) {
        await Hive.openBox<NewsArticle>(boxName);
      }
      if (!Hive.isBoxOpen(metaName)) {
        // meta box holds a String under 'lastSaved'
        await Hive.openBox<String>(metaName);
      }
    }
  }

  static String _boxName(String category) => 'news_$category';
  static String _metaName(String category) => 'news_${category}_meta';

  static Box<NewsArticle> _articleBox(String category) =>
      Hive.box<NewsArticle>(_boxName(category));
  static Box<String> _metaBox(String category) =>
      Hive.box<String>(_metaName(category));

  /// Persist the list of articles, then stamp the time.
  static Future<void> saveArticles(
    String category,
    List<NewsArticle> articles,
  ) async {
    final box = _articleBox(category);
    await box.clear();
    for (final a in articles) {
      await box.put(a.url, a);
    }
    await _metaBox(category).put(
      'lastSaved',
      DateTime.now().toIso8601String(),
    );
  }

  /// Read back cached articles, marking them from cache.
  static List<NewsArticle> getArticles(String category) {
    return _articleBox(category)
        .values
        .map((a) => a..fromCache = true)
        .toList();
  }

  /// True if no saved timestamp or older than [cacheDuration].
  static bool isExpired(String category) {
    final savedStr = _metaBox(category).get('lastSaved');
    if (savedStr == null) return true;
    final saved = DateTime.tryParse(savedStr);
    if (saved == null) return true;
    return DateTime.now().difference(saved) > cacheDuration;
  }

  /// True if there are *any* cached articles.
  static bool hasArticles(String category) =>
      _articleBox(category).isNotEmpty;
}
