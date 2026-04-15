import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/telemetry/structured_logger.dart';
import '../../../domain/entities/news_article.dart';
import '../../external_apis/article_scraper_service.dart';
import '../models/news_article.dart' show NewsArticleModel;

// Service to manage articles saved for offline reading with full content.
class SavedArticlesService {
  SavedArticlesService(this._scraper, this._logger);

  final ArticleScraperService _scraper;
  final StructuredLogger _logger;

  static const String _boxName = 'saved_articles';
  static const String _metaBoxName = 'saved_articles_meta_v1';

  static const String _maintenanceLastRunMsKey = '_maintenance_last_run_ms';
  static const String _staleReminderLastSentMsKey =
      '_stale_reminder_last_sent_ms';
  static const String _savedAtMsKey = 'saved_at_ms';
  static const String _sourceReachableKey = 'source_reachable';
  static const String _sourceLastCheckedMsKey = 'source_last_checked_ms';
  static const String _sourceUrlKey = 'source_url';

  static const int _maxSavedArticles = 50;
  static const int _maxSourceChecksPerRun = 6;

  static const Duration _staleAge = Duration(days: 90); // ~3 months
  static const Duration _maintenanceInterval = Duration(hours: 24);
  static const Duration _sourceCheckInterval = Duration(days: 7);
  static const Duration _staleReminderCooldown = Duration(days: 7);

  Box<NewsArticleModel>? _box;
  Box<dynamic>? _metaBox;

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  bool _notificationsReady = false;

  Future<void> init() async {
    if (_box != null && _box!.isOpen && _metaBox != null && _metaBox!.isOpen) {
      return;
    }

    try {
      await Hive.initFlutter();
      _box = Hive.isBoxOpen(_boxName)
          ? Hive.box<NewsArticleModel>(_boxName)
          : await Hive.openBox<NewsArticleModel>(_boxName);
      _metaBox = Hive.isBoxOpen(_metaBoxName)
          ? Hive.box<dynamic>(_metaBoxName)
          : await Hive.openBox<dynamic>(_metaBoxName);

      await _ensureMetaForExistingArticles();
      _logger.info('SavedArticlesService initialized');

      unawaited(runMaintenance());
    } catch (e, s) {
      _logger.error('Failed to initialize SavedArticlesService', e, s);
    }
  }

  Future<bool> saveArticle(NewsArticle article) async {
    try {
      await init();
      if (_box == null) {
        debugPrint('⚠️ Saved articles box not initialized');
        return false;
      }

      if (_box!.length >= _maxSavedArticles && !isSaved(article.url)) {
        await _removeOldest();
      }

      final previewLen = article.title.length > 40 ? 40 : article.title.length;
      debugPrint(
        '💾 Saving article: ${article.title.substring(0, previewLen)}...',
      );

      String fullContent = article.fullContent;
      if (fullContent.trim().isEmpty) {
        debugPrint('   📥 Downloading full content...');
        final extracted = await _scraper.extractArticleContent(article.url);
        if (extracted != null && extracted.trim().isNotEmpty) {
          fullContent = extracted;
          debugPrint('   ✅ Content downloaded (${fullContent.length} chars)');
        } else {
          debugPrint(
            '   ⚠️ Failed to extract content, keeping partial snapshot',
          );
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
        fullContent: fullContent,
        sourceOverride: article.sourceOverride,
        sourceLogo: article.sourceLogo,
        fromCache: true,
      );

      await _box!.put(article.url, newsModel);
      await _upsertMetaForSavedArticle(article.url);

      debugPrint('   ✅ Article saved successfully to Hive');
      unawaited(runMaintenance());
      return true;
    } catch (e, s) {
      _logger.error('Error saving article', e, s);
      return false;
    }
  }

  Future<bool> removeArticle(String url) async {
    try {
      await init();
      if (_box == null) return false;

      if (_box!.containsKey(url)) {
        await _box!.delete(url);
        await _metaBox?.delete(url);
        debugPrint('🗑️ Removed saved article: $url');
        return true;
      }
      return false;
    } catch (e, s) {
      _logger.error('Error removing saved article', e, s);
      return false;
    }
  }

  List<NewsArticle> getSavedArticles() {
    try {
      if (_box == null || !_box!.isOpen) {
        return [];
      }

      final models = _box!.values.toList();
      final articles = models.map((m) => m.toDomain()).toList();

      articles.sort((a, b) {
        final bSaved = getSavedAt(b.url) ?? b.publishedAt;
        final aSaved = getSavedAt(a.url) ?? a.publishedAt;
        return bSaved.compareTo(aSaved);
      });

      return articles;
    } catch (e, s) {
      _logger.error('Error getting saved articles', e, s);
      return [];
    }
  }

  bool isSaved(String url) {
    try {
      if (_box == null || !_box!.isOpen) return false;
      return _box!.containsKey(url);
    } catch (e, s) {
      _logger.warning('Error checking saved state', e, s);
      return false;
    }
  }

  NewsArticle? getSavedArticle(String url) {
    try {
      if (_box == null || !_box!.isOpen) return null;
      return _box!.get(url)?.toDomain();
    } catch (e, s) {
      _logger.warning('Error getting saved article', e, s);
      return null;
    }
  }

  int get savedCount {
    try {
      if (_box == null || !_box!.isOpen) return 0;
      return _box!.length;
    } catch (_) {
      return 0;
    }
  }

  int get staleArticlesCount {
    final now = DateTime.now().toUtc();
    var stale = 0;
    for (final article in getSavedArticles()) {
      final savedAt = getSavedAt(article.url) ?? article.publishedAt.toUtc();
      if (now.difference(savedAt) >= _staleAge) {
        stale++;
      }
    }
    return stale;
  }

  DateTime? getSavedAt(String url) {
    final meta = _metaFor(url);
    final ms = meta[_savedAtMsKey];
    return _dateFromMs(ms);
  }

  bool isSourceLinkReachable(String url) {
    final meta = _metaFor(url);
    final v = meta[_sourceReachableKey];
    if (v is bool) return v;
    return true;
  }

  int get maxSavedArticles => _maxSavedArticles;

  Future<void> clearAll() async {
    try {
      await init();
      await _box?.clear();
      await _metaBox?.clear();
      debugPrint('🗑️ Cleared all saved articles');
    } catch (e, s) {
      _logger.error('Error clearing saved articles', e, s);
    }
  }

  double get storageUsageMB {
    try {
      if (_box == null || !_box!.isOpen) return 0.0;

      var totalChars = 0;
      for (final article in _box!.values) {
        totalChars += article.fullContent.length;
        totalChars += article.description.length;
        totalChars += article.title.length;
      }

      final bytes = totalChars * 2 * 1.5;
      return bytes / (1024 * 1024);
    } catch (_) {
      return 0.0;
    }
  }

  Future<void> runMaintenance({bool force = false}) async {
    try {
      await init();
      if (_box == null || _metaBox == null) return;
      if (!force && !_shouldRunMaintenanceNow()) return;

      await _cleanupOrphanMetaRecords();
      await _ensureMetaForExistingArticles();
      await _updateSourceLinkHealth();
      await _notifyAboutStaleArticlesIfNeeded();

      await _setMetaValue(
        _maintenanceLastRunMsKey,
        DateTime.now().toUtc().millisecondsSinceEpoch,
      );
    } catch (e, s) {
      _logger.warning('Saved articles maintenance failed', e, s);
    }
  }

  Future<void> _removeOldest() async {
    try {
      final articles = getSavedArticles();
      if (articles.isEmpty) return;
      final oldest = articles.last;
      await removeArticle(oldest.url);
      debugPrint('🗑️ Auto-removed oldest article to free space');
    } catch (e, s) {
      _logger.warning('Error removing oldest saved article', e, s);
    }
  }

  bool _shouldRunMaintenanceNow() {
    final lastRun = _dateFromMs(_metaBox?.get(_maintenanceLastRunMsKey));
    if (lastRun == null) return true;
    return DateTime.now().toUtc().difference(lastRun) >= _maintenanceInterval;
  }

  Future<void> _ensureMetaForExistingArticles() async {
    if (_box == null || _metaBox == null) return;
    for (final dynamic key in _box!.keys) {
      if (key is! String) continue;
      final meta = _metaFor(key);
      if (meta.isEmpty) {
        await _metaBox!.put(key, <String, dynamic>{
          _savedAtMsKey: DateTime.now().toUtc().millisecondsSinceEpoch,
          _sourceUrlKey: key,
          _sourceReachableKey: true,
        });
      } else if (!meta.containsKey(_sourceUrlKey)) {
        meta[_sourceUrlKey] = key;
        await _metaBox!.put(key, meta);
      }
    }
  }

  Future<void> _cleanupOrphanMetaRecords() async {
    if (_box == null || _metaBox == null) return;
    final validKeys = _box!.keys.whereType<String>().toSet();
    final metaKeys = _metaBox!.keys.whereType<String>().toList();
    for (final key in metaKeys) {
      if (!validKeys.contains(key)) {
        await _metaBox!.delete(key);
      }
    }
  }

  Future<void> _upsertMetaForSavedArticle(String url) async {
    if (_metaBox == null) return;
    final existing = _metaFor(url);
    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    await _metaBox!.put(url, <String, dynamic>{
      _savedAtMsKey: existing[_savedAtMsKey] ?? nowMs,
      _sourceUrlKey: url,
      _sourceReachableKey: existing[_sourceReachableKey] ?? true,
      _sourceLastCheckedMsKey: existing[_sourceLastCheckedMsKey],
    });
  }

  Future<void> _updateSourceLinkHealth() async {
    if (_box == null || _metaBox == null) return;

    final now = DateTime.now().toUtc();
    final articles = getSavedArticles();
    final candidates = <NewsArticle>[];

    for (final article in articles) {
      final meta = _metaFor(article.url);
      final lastChecked = _dateFromMs(meta[_sourceLastCheckedMsKey]);
      final due =
          lastChecked == null ||
          now.difference(lastChecked) >= _sourceCheckInterval;
      if (due) {
        candidates.add(article);
      }
    }

    candidates.sort((a, b) {
      final aChecked = _dateFromMs(_metaFor(a.url)[_sourceLastCheckedMsKey]);
      final bChecked = _dateFromMs(_metaFor(b.url)[_sourceLastCheckedMsKey]);
      final aMs = aChecked?.millisecondsSinceEpoch ?? 0;
      final bMs = bChecked?.millisecondsSinceEpoch ?? 0;
      return aMs.compareTo(bMs);
    });

    for (final article in candidates.take(_maxSourceChecksPerRun)) {
      final reachable = await _isSourceUrlReachable(article.url);
      final meta = _metaFor(article.url);
      meta[_sourceReachableKey] = reachable;
      meta[_sourceLastCheckedMsKey] = now.millisecondsSinceEpoch;
      meta[_sourceUrlKey] = article.url;
      await _metaBox!.put(article.url, meta);
    }
  }

  Future<bool> _isSourceUrlReachable(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      return false;
    }

    Future<bool> probe(String method) async {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 6);
      try {
        final request = await client
            .openUrl(method, uri)
            .timeout(const Duration(seconds: 6));
        request.followRedirects = true;
        request.headers.set(HttpHeaders.userAgentHeader, 'BDNewsReader/1.0');
        final response = await request.close().timeout(
          const Duration(seconds: 6),
        );
        return response.statusCode >= 200 && response.statusCode < 400;
      } catch (_) {
        return false;
      } finally {
        client.close(force: true);
      }
    }

    final headOk = await probe('HEAD');
    if (headOk) return true;
    return probe('GET');
  }

  Future<void> _notifyAboutStaleArticlesIfNeeded() async {
    final staleCount = staleArticlesCount;
    if (staleCount == 0) return;

    final lastReminder = _dateFromMs(
      _metaBox?.get(_staleReminderLastSentMsKey),
    );
    if (lastReminder != null &&
        DateTime.now().toUtc().difference(lastReminder) <
            _staleReminderCooldown) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final notificationsEnabled = prefs.getBool('push_notif') ?? true;
    if (!notificationsEnabled) return;

    await _ensureNotificationsInitialized();

    await _localNotifications.show(
      id: 7301,
      title: 'Offline library cleanup',
      body:
          '$staleCount saved article${staleCount == 1 ? '' : 's'} are older than 3 months. Review and delete outdated copies.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'offline_maintenance',
          'Offline Maintenance',
          channelDescription: 'Reminders for stale offline article cleanup',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: false,
          presentSound: false,
        ),
      ),
      payload: 'offline_cleanup',
    );

    await _setMetaValue(
      _staleReminderLastSentMsKey,
      DateTime.now().toUtc().millisecondsSinceEpoch,
    );
  }

  Future<void> _ensureNotificationsInitialized() async {
    if (_notificationsReady) return;

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _localNotifications.initialize(settings: settings);

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'offline_maintenance',
        'Offline Maintenance',
        description: 'Reminders for stale offline article cleanup',
      ),
    );

    _notificationsReady = true;
  }

  Map<String, dynamic> _metaFor(String url) {
    final raw = _metaBox?.get(url);
    if (raw is Map) {
      return Map<String, dynamic>.from(raw.cast<dynamic, dynamic>());
    }
    return <String, dynamic>{};
  }

  Future<void> _setMetaValue(String key, dynamic value) async {
    await _metaBox?.put(key, value);
  }

  DateTime? _dateFromMs(dynamic value) {
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
    }
    if (value is String && value.isNotEmpty) {
      if (int.tryParse(value) case final int parsed) {
        return DateTime.fromMillisecondsSinceEpoch(parsed, isUtc: true);
      }
      final parsed = DateTime.tryParse(value);
      return parsed?.toUtc();
    }
    return null;
  }
}
