import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;
import "../../domain/entities/news_article.dart";
import '../observability/analytics_service.dart';

// Service for offline article storage and retrieval
class OfflineService {
  static Database? _database;
  static const String _tableName = 'offline_articles';
  static const String _imagesDir = 'offline_images';

  static Future<void> initialize() async {
    if (_database != null) return;

    final documentsDir = await getApplicationDocumentsDirectory();
    final dbPath = path.join(documentsDir.path, 'offline_articles.db');

    _database = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tableName (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            url TEXT UNIQUE NOT NULL,
            title TEXT NOT NULL,
            description TEXT,
            imageUrl TEXT,
            localImagePath TEXT,
            source TEXT,
            publishedDate TEXT,
            content TEXT,
            downloadedAt INTEGER NOT NULL,
            categoryIds TEXT,
            keywords TEXT
          )
        ''');
      },
    );
  }

  static Future<bool> downloadArticle(NewsArticle article) async {
    try {
      await initialize();

      if (await isArticleDownloaded(article.url)) {
        return true;
      }

      String? localImagePath;
      if (article.imageUrl != null && article.imageUrl!.isNotEmpty) {
        localImagePath = await _downloadImage(article.imageUrl!);
      }

      await _database!.insert(_tableName, {
        'url': article.url,
        'title': article.title,
        'description': article.description ?? '',
        'imageUrl': article.imageUrl ?? '',
        'localImagePath': localImagePath ?? '',
        'source': article.source,
        'publishedDate': article.publishedAt.toIso8601String(),
        'content': article.description ?? '',
        'downloadedAt': DateTime.now().millisecondsSinceEpoch,
        'categoryIds': '',
        'keywords': '',
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      await AnalyticsService.logEvent(
        name: 'article_downloaded',
        parameters: {'url': article.url},
      );

      return true;
    } catch (e) {
      debugPrint('Error downloading article: $e');
      return false;
    }
  }

  static Future<bool> isArticleDownloaded(String url) async {
    try {
      await initialize();
      final result = await _database!.query(
        _tableName,
        where: 'url = ?',
        whereArgs: [url],
      );
      return result.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  static Future<List<NewsArticle>> getDownloadedArticles() async {
    try {
      await initialize();
      final List<Map<String, dynamic>> maps = await _database!.query(
        _tableName,
        orderBy: 'downloadedAt DESC',
      );

      return maps.map((map) => _mapToArticle(map)).toList();
    } catch (e) {
      debugPrint('Error fetching downloaded articles: $e');
      return [];
    }
  }

  static Future<bool> deleteArticle(String url) async {
    try {
      await initialize();

      final result = await _database!.query(
        _tableName,
        where: 'url = ?',
        whereArgs: [url],
      );

      if (result.isNotEmpty) {
        final localImagePath = result.first['localImagePath'] as String;
        if (localImagePath.isNotEmpty) {
          await _deleteImage(localImagePath);
        }
      }

      await _database!.delete(_tableName, where: 'url = ?', whereArgs: [url]);

      await AnalyticsService.logEvent(
        name: 'article_deleted',
        parameters: {'url': url},
      );

      return true;
    } catch (e) {
      debugPrint('Error deleting article: $e');
      return false;
    }
  }

  static Future<bool> clearAll() async {
    try {
      await initialize();

      final documentsDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(path.join(documentsDir.path, _imagesDir));
      if (await imagesDir.exists()) {
        await imagesDir.delete(recursive: true);
      }

      await _database!.delete(_tableName);

      await AnalyticsService.logEvent(name: 'offline_cache_cleared');

      return true;
    } catch (e) {
      debugPrint('Error clearing offline cache: $e');
      return false;
    }
  }

  static Future<int> getStorageUsed() async {
    try {
      int totalSize = 0;

      final documentsDir = await getApplicationDocumentsDirectory();
      final dbPath = path.join(documentsDir.path, 'offline_articles.db');
      final dbFile = File(dbPath);
      if (await dbFile.exists()) {
        totalSize += await dbFile.length();
      }

      final imagesDir = Directory(path.join(documentsDir.path, _imagesDir));
      if (await imagesDir.exists()) {
        await for (final entity in imagesDir.list(recursive: true)) {
          if (entity is File) {
            totalSize += await entity.length();
          }
        }
      }

      return totalSize;
    } catch (e) {
      return 0;
    }
  }

  static Future<int> getDownloadedCount() async {
    try {
      await initialize();
      final result = await _database!.rawQuery(
        'SELECT COUNT(*) as count FROM $_tableName',
      );
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      return 0;
    }
  }


  static Future<String> _downloadImage(String imageUrl) async {
    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        final documentsDir = await getApplicationDocumentsDirectory();
        final imagesDir = Directory(path.join(documentsDir.path, _imagesDir));

        if (!await imagesDir.exists()) {
          await imagesDir.create(recursive: true);
        }

        final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
        final filePath = path.join(imagesDir.path, fileName);
        final file = File(filePath);

        await file.writeAsBytes(response.bodyBytes);
        return filePath;
      }
    } catch (e) {
      debugPrint('Error downloading image: $e');
    }
    return '';
  }

  static Future<void> _deleteImage(String imagePath) async {
    try {
      final file = File(imagePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Error deleting image: $e');
    }
  }

  static NewsArticle _mapToArticle(Map<String, dynamic> map) {
    return NewsArticle(
      title: map['title'] as String,
      url: map['url'] as String,
      description: map['description'] as String? ?? '',
      imageUrl: map['imageUrl'] as String?,
      source: map['source'] as String? ?? '',
      publishedAt:
          map['publishedDate'] != null &&
                  (map['publishedDate'] as String).isNotEmpty
              ? DateTime.parse(map['publishedDate'] as String)
              : DateTime.now(),
    );
  }

  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
