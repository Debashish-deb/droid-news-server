import '../../core/telemetry/structured_logger.dart';
import 'package:injectable/injectable.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import "../../domain/entities/news_article.dart";
import '../external_apis/article_scraper_service.dart';
import 'news_article.dart';

import 'news_article.dart' show NewsArticleModel; 

// Service to manage articles saved for offline reading with full content
@lazySingleton
class SavedArticlesService {

  SavedArticlesService(this._scraper, this._logger);
  final ArticleScraperService _scraper;
  final StructuredLogger _logger;

  static const String _boxName = 'saved_articles';
  static const int _maxSavedArticles = 50;

  Box<NewsArticleModel>? _box;

  Future<void> init() async {
    if (_box != null && _box!.isOpen) return;

    try {
      await Hive.initFlutter();
      if (!Hive.isBoxOpen(_boxName)) {
        _box = await Hive.openBox<NewsArticleModel>(_boxName);
      } else {
        _box = Hive.box<NewsArticleModel>(_boxName);
      }
      _logger.info('✅ SavedArticlesService initialized with NewsArticleModel');
    } catch (e) {
      _logger.error('❌ Failed to initialize SavedArticlesService', e);
    }
  }

  Future<bool> saveArticle(NewsArticle article) async {
    try {
      await init();
      if (_box == null) {
        debugPrint('⚠️ Box not initialized');
        return false;
      }

      if (_box!.length >= _maxSavedArticles && !isSaved(article.url)) {
        debugPrint('⚠️ Storage limit reached ($maxSavedArticles articles)');
        await _removeOldest();
      }

      debugPrint(
        '💾 Saving article: ${article.title.substring(0, article.title.length > 40 ? 40 : article.title.length)}...',
      );

      String? fullContent = article.fullContent;
      if (fullContent.isEmpty) {
        debugPrint('   📥 Downloading full content...');
        fullContent = await _scraper.extractArticleContent(article.url);

        if (fullContent == null || fullContent.isEmpty) {
          debugPrint('   ⚠️ Failed to extract content, saving without it');
        } else {
          debugPrint('   ✅ Content downloaded (${fullContent.length} chars)');
        }
      }

      final newsModel = NewsArticleModel(
        title: article.title,
        url: article.url,
        source: article.source,
        publishedAt: article.publishedAt,
        description: article.description,
        imageUrl: article.imageUrl,
        language: article.language,
        snippet: article.snippet,
        fullContent: fullContent ?? article.fullContent,
        sourceOverride: article.sourceOverride,
        sourceLogo: article.sourceLogo,
        fromCache: true,
      );

      await _box!.put(article.url, newsModel);
      debugPrint('   ✅ Article saved successfully to Hive');
      return true;
    } catch (e) {
      debugPrint('❌ Error saving article: $e');
      return false;
    }
  }

  Future<bool> removeArticle(String url) async {
    try {
      await init();
      if (_box == null) return false;

      if (_box!.containsKey(url)) {
        await _box!.delete(url);
        debugPrint('🗑️ Removed saved article: $url');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error removing article: $e');
      return false;
    }
  }

  List<NewsArticle> getSavedArticles() {
    try {
      if (_box == null || !_box!.isOpen) {
        debugPrint('⚠️ Box not open');
        return [];
      }

      final models = _box!.values.toList();
      final articles = models.map((m) => m.toDomain()).toList();

      articles.sort((a, b) {
        return b.publishedAt.compareTo(a.publishedAt);
      });

      return articles;
    } catch (e) {
      debugPrint('❌ Error getting saved articles: $e');
      return [];
    }
  }

  bool isSaved(String url) {
    try {
      if (_box == null || !_box!.isOpen) return false;
      return _box!.containsKey(url);
    } catch (e) {
      debugPrint('❌ Error checking if saved: $e');
      return false;
    }
  }

  NewsArticle? getSavedArticle(String url) {
    try {
      if (_box == null || !_box!.isOpen) return null;
      return _box!.get(url)?.toDomain();
    } catch (e) {
      debugPrint('❌ Error getting saved article: $e');
      return null;
    }
  }

  int get savedCount {
    try {
      if (_box == null || !_box!.isOpen) return 0;
      return _box!.length;
    } catch (e) {
      return 0;
    }
  }

  int get maxSavedArticles => _maxSavedArticles;

  Future<void> _removeOldest() async {
    try {
      final articles = getSavedArticles();
      if (articles.isEmpty) return;

      final oldest = articles.last;
      await removeArticle(oldest.url);
      debugPrint('🗑️ Auto-removed oldest article to free space');
    } catch (e) {
      debugPrint('❌ Error removing oldest: $e');
    }
  }

  Future<void> clearAll() async {
    try {
      await init();
      if (_box != null) {
        await _box!.clear();
        debugPrint('🗑️ Cleared all saved articles');
      }
    } catch (e) {
      debugPrint('❌ Error clearing saved articles: $e');
    }
  }

  double get storageUsageMB {
    try {
      if (_box == null || !_box!.isOpen) return 0.0;

      int totalChars = 0;
      for (final article in _box!.values) {
        totalChars += article.fullContent.length;
        totalChars += article.description.length;
        totalChars += article.title.length;
      }

      final bytes = totalChars * 2 * 1.5; 
      return bytes / (1024 * 1024);
    } catch (e) {
      return 0.0;
    }
  }
}
