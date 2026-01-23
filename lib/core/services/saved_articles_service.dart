import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../../data/models/news_article.dart';
import 'article_scraper_service.dart';

/// Service to manage articles saved for offline reading with full content
class SavedArticlesService {
  SavedArticlesService._();
  static final SavedArticlesService _instance = SavedArticlesService._();
  static SavedArticlesService get instance => _instance;

  static const String _boxName = 'saved_articles';
  static const int _maxSavedArticles = 50; // Storage limit

  Box<NewsArticle>? _box;
  final ArticleScraperService _scraper = ArticleScraperService.instance;

  /// Initialize the service and open Hive box
  Future<void> init() async {
    if (_box != null && _box!.isOpen) return;

    try {
      if (!Hive.isBoxOpen(_boxName)) {
        _box = await Hive.openBox<NewsArticle>(_boxName);
      } else {
        _box = Hive.box<NewsArticle>(_boxName);
      }
      debugPrint('✅ SavedArticlesService initialized');
    } catch (e) {
      debugPrint('❌ Failed to initialize SavedArticlesService: $e');
    }
  }

  /// Save an article for offline reading (downloads full content)
  Future<bool> saveArticle(NewsArticle article) async {
    try {
      await init();
      if (_box == null) {
        debugPrint('⚠️ Box not initialized');
        return false;
      }

      // Check storage limit
      if (_box!.length >= _maxSavedArticles && !isSaved(article.url)) {
        debugPrint('⚠️ Storage limit reached ($maxSavedArticles articles)');
        // Auto-remove oldest
        await _removeOldest();
      }

      debugPrint(
        '💾 Saving article: ${article.title.substring(0, article.title.length > 40 ? 40 : article.title.length)}...',
      );

      // Download full content if not already available
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

      // Create saved article copy
      final savedArticle = NewsArticle(
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
        fromCache: true, // Mark as from cache since it's saved offline
      );

      // Save to box (use URL as key for easy lookup)
      await _box!.put(article.url, savedArticle);
      debugPrint('   ✅ Article saved successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Error saving article: $e');
      return false;
    }
  }

  /// Remove an article from saved articles
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

  /// Get all saved articles (sorted by savedAt, newest first)
  List<NewsArticle> getSavedArticles() {
    try {
      if (_box == null || !_box!.isOpen) {
        debugPrint('⚠️ Box not open');
        return [];
      }

      final articles = _box!.values.toList();

      // Sort by publishedAt (newest first)
      articles.sort((a, b) {
        return b.publishedAt.compareTo(a.publishedAt);
      });

      return articles;
    } catch (e) {
      debugPrint('❌ Error getting saved articles: $e');
      return [];
    }
  }

  /// Check if an article is saved
  bool isSaved(String url) {
    try {
      if (_box == null || !_box!.isOpen) return false;
      return _box!.containsKey(url);
    } catch (e) {
      debugPrint('❌ Error checking if saved: $e');
      return false;
    }
  }

  /// Get a specific saved article by URL
  NewsArticle? getSavedArticle(String url) {
    try {
      if (_box == null || !_box!.isOpen) return null;
      return _box!.get(url);
    } catch (e) {
      debugPrint('❌ Error getting saved article: $e');
      return null;
    }
  }

  /// Get count of saved articles
  int get savedCount {
    try {
      if (_box == null || !_box!.isOpen) return 0;
      return _box!.length;
    } catch (e) {
      return 0;
    }
  }

  /// Get max storage limit
  int get maxSavedArticles => _maxSavedArticles;

  /// Remove oldest saved article
  Future<void> _removeOldest() async {
    try {
      final articles = getSavedArticles();
      if (articles.isEmpty) return;

      // Get oldest (last in sorted list)
      final oldest = articles.last;
      await removeArticle(oldest.url);
      debugPrint('🗑️ Auto-removed oldest article to free space');
    } catch (e) {
      debugPrint('❌ Error removing oldest: $e');
    }
  }

  /// Clear all saved articles
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

  /// Get storage usage estimate (in MB)
  double get storageUsageMB {
    try {
      if (_box == null || !_box!.isOpen) return 0.0;

      int totalChars = 0;
      for (final article in _box!.values) {
        totalChars += article.fullContent.length;
        totalChars += article.description.length;
        totalChars += article.title.length;
      }

      // Rough estimate: 1 char ≈ 2 bytes (UTF-8), plus metadata overhead
      final bytes = totalChars * 2 * 1.5; // 1.5x for metadata
      return bytes / (1024 * 1024); // Convert to MB
    } catch (e) {
      return 0.0;
    }
  }
}
