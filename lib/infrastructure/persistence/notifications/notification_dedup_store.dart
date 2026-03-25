import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Tracks which articles have already been shown in notifications to prevent
/// duplicate / repeated notifications (e.g. "36 new articles" every 4 hours).
///
/// Two responsibilities:
/// 1. **Article-level dedup** — prevents the same article from being notified
///    twice across FCM push and local WorkManager notifications.
/// 2. **Timestamp watermark** — remembers *when* the last notification was sent
///    so background sync can query only articles published *after* that time.
class NotificationDedupStore {
  NotificationDedupStore(this._prefs);

  final SharedPreferences _prefs;

  // ── Keys ──────────────────────────────────────────────────────────────────
  static const String _shownArticlesKey = 'notif_shown_article_keys';
  static const String _lastNotifiedAtKey = 'notif_last_notified_at';

  // ── Limits ────────────────────────────────────────────────────────────────
  /// Maximum number of article keys to retain.  Prevents unbounded growth in
  /// SharedPreferences.  When exceeded, the oldest entries are evicted.
  static const int maxStoredArticles = 500;

  /// Entries older than this are eligible for cleanup.
  static const Duration articleTTL = Duration(hours: 48);

  // ── Article-level dedup ───────────────────────────────────────────────────

  /// Returns `true` if the article has NOT been shown in a notification yet.
  bool shouldShow(String articleKey) {
    if (articleKey.isEmpty) return false;
    final shown = _getShownArticles();
    return !shown.containsKey(articleKey);
  }

  /// Filters [articleKeys] and returns only those that have NOT been shown.
  List<String> filterUnseen(List<String> articleKeys) {
    final shown = _getShownArticles();
    return articleKeys.where((k) => k.isNotEmpty && !shown.containsKey(k)).toList();
  }

  /// Marks a single article as shown.
  Future<void> markShown(String articleKey) async {
    if (articleKey.isEmpty) return;
    final shown = _getShownArticles();
    shown[articleKey] = DateTime.now().toIso8601String();
    await _saveShownArticles(shown);
  }

  /// Marks many articles as shown in one write.
  Future<void> markAllShown(List<String> articleKeys) async {
    if (articleKeys.isEmpty) return;
    final shown = _getShownArticles();
    final now = DateTime.now().toIso8601String();
    for (final key in articleKeys) {
      if (key.isNotEmpty) {
        shown[key] = now;
      }
    }
    await _saveShownArticles(shown);
  }

  // ── Timestamp watermark ───────────────────────────────────────────────────

  /// The time the last notification was sent.  Returns `null` if never set.
  DateTime? get lastNotifiedAt {
    final stored = _prefs.getString(_lastNotifiedAtKey);
    if (stored == null || stored.isEmpty) return null;
    return DateTime.tryParse(stored);
  }

  /// Updates the watermark to [time] (defaults to now).
  Future<void> updateLastNotifiedAt([DateTime? time]) async {
    await _prefs.setString(
      _lastNotifiedAtKey,
      (time ?? DateTime.now()).toIso8601String(),
    );
  }

  // ── Cleanup ───────────────────────────────────────────────────────────────

  /// Evicts entries older than [articleTTL] and trims to [maxStoredArticles].
  /// Returns the number of entries removed.
  Future<int> cleanup() async {
    final shown = _getShownArticles();
    final now = DateTime.now();
    final originalSize = shown.length;

    // Remove expired entries.
    shown.removeWhere((_, timestamp) {
      final shownAt = DateTime.tryParse(timestamp);
      return shownAt == null || now.difference(shownAt) > articleTTL;
    });

    // If still over limit, drop oldest.
    if (shown.length > maxStoredArticles) {
      final sorted = shown.entries.toList()
        ..sort((a, b) {
          final aTime = DateTime.tryParse(a.value) ?? DateTime(2000);
          final bTime = DateTime.tryParse(b.value) ?? DateTime(2000);
          return aTime.compareTo(bTime);
        });
      final toRemove = sorted.take(shown.length - maxStoredArticles).toList();
      for (final entry in toRemove) {
        shown.remove(entry.key);
      }
    }

    await _saveShownArticles(shown);
    return originalSize - shown.length;
  }

  // ── Internal helpers ──────────────────────────────────────────────────────

  Map<String, String> _getShownArticles() {
    final stored = _prefs.getString(_shownArticlesKey);
    if (stored == null || stored.isEmpty) return <String, String>{};
    try {
      final decoded = jsonDecode(stored) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v as String));
    } catch (_) {
      return <String, String>{};
    }
  }

  Future<void> _saveShownArticles(Map<String, String> shown) async {
    // Enforce limit before persisting just in case.
    if (shown.length > maxStoredArticles) {
      final sorted = shown.entries.toList()
        ..sort((a, b) {
          final aTime = DateTime.tryParse(a.value) ?? DateTime(2000);
          final bTime = DateTime.tryParse(b.value) ?? DateTime(2000);
          return aTime.compareTo(bTime);
        });
      final toRemove = sorted.take(shown.length - maxStoredArticles).toList();
      for (final entry in toRemove) {
        shown.remove(entry.key);
      }
    }
    await _prefs.setString(_shownArticlesKey, jsonEncode(shown));
  }
}
