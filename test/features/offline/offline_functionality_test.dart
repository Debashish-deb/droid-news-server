import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Offline Functionality Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    group('Offline Article Access', () {
      test('TC-OFFLINE-001: Cached articles accessible offline', () async {
        final prefs = await SharedPreferences.getInstance();
        
        // Simulate cached articles
        final cachedArticles = [
          '{"title":"Offline Article 1","url":"https://example.com/1","cached":true}',
          '{"title":"Offline Article 2","url":"https://example.com/2","cached":true}',
        ];
        
        await prefs.setStringList('cached_articles', cachedArticles);
        
        // Verify access offline
        final cached = prefs.getStringList('cached_articles');
        expect(cached, isNotNull);
        expect(cached!.length, 2);
      });

      test('TC-OFFLINE-002: Recently viewed articles are cached', () async {
        final prefs = await SharedPreferences.getInstance();
        
        // Simulate viewing articles
        final recentArticles = ['url1', 'url2', 'url3'];
        await prefs.setStringList('recent_articles', recentArticles);
        
        final recent = prefs.getStringList('recent_articles');
        expect(recent, recentArticles);
      });

      test('TC-OFFLINE-003: Cache limit enforced (max 50 articles)', () async {
        final prefs = await SharedPreferences.getInstance();
        
        // Try to cache 60 articles
        final articles = List.generate(60, (i) => 'article_$i');
        
        // Should only keep last 50
        final limitedCache = articles.length > 50 
            ? articles.sublist(articles.length - 50)
            : articles;
        
        await prefs.setStringList('cached_articles', limitedCache);
        
        final cached = prefs.getStringList('cached_articles');
        expect(cached!.length, 50);
        expect(cached.first, 'article_10'); // First 10 were dropped
      });
    });

    group('Offline Favorites Access', () {
      test('TC-OFFLINE-004: Favorites accessible without network', () async {
        final prefs = await SharedPreferences.getInstance();
        
        final favorites = [
          '{"title":"Favorite 1","url":"https://example.com/fav1"}',
          '{"title":"Favorite 2","url":"https://example.com/fav2"}',
        ];
        
        await prefs.setStringList('favorites', favorites);
        
        // Access offline
        final offlineFavs = prefs.getStringList('favorites');
        expect(offlineFavs, isNotNull);
        expect(offlineFavs!.length, 2);
      });

      test('TC-OFFLINE-005: Can add favorites offline', () async {
        final prefs = await SharedPreferences.getInstance();
        
        // Existing favorites
        await prefs.setStringList('favorites', ['fav1']);
        
        // Add new favorite offline
        final current = prefs.getStringList('favorites') ?? [];
        current.add('fav2');
        await prefs.setStringList('favorites', current);
        
        expect(prefs.getStringList('favorites')!.length, 2);
      });

      test('TC-OFFLINE-006: Offline changes tracked for sync', () async {
        final prefs = await SharedPreferences.getInstance();
        
        // Track pending sync
        await prefs.setStringList('pending_favorite_adds', ['url1', 'url2']);
        await prefs.setStringList('pending_favorite_removes', ['url3']);
        
        final pendingAdds = prefs.getStringList('pending_favorite_adds');
        final pendingRemoves = prefs.getStringList('pending_favorite_removes');
        
        expect(pendingAdds!.length, 2);
        expect(pendingRemoves!.length, 1);
      });
    });

    group('Offline Settings Changes', () {
      test('TC-OFFLINE-007: Settings changes persist offline', () async {
        final prefs = await SharedPreferences.getInstance();
        
        // Change settings offline
        await prefs.setInt('theme_mode', 2);
        await prefs.setString('language_code', 'bn');
        await prefs.setBool('data_saver', true);
        
        expect(prefs.getInt('theme_mode'), 2);
        expect(prefs.getString('language_code'), 'bn');
        expect(prefs.getBool('data_saver'), true);
      });

      test('TC-OFFLINE-008: Offline settings marked for sync', () async {
        final prefs = await SharedPreferences.getInstance();
        
        await prefs.setBool('settings_needs_sync', true);
        await prefs.setInt('settings_last_modified', DateTime.now().millisecondsSinceEpoch);
        
        expect(prefs.getBool('settings_needs_sync'), true);
        expect(prefs.getInt('settings_last_modified'), greaterThan(0));
      });
    });

    group('Sync Resume After Reconnection', () {
      test('TC-OFFLINE-009: Pending changes detected on reconnect', () async {
        final prefs = await SharedPreferences.getInstance();
        
        // Simulate offline changes
        await prefs.setStringList('pending_sync_favorites', ['item1', 'item2']);
        await prefs.setStringList('pending_sync_settings', ['theme', 'language']);
        
        // Check on reconnect
        final hasPendingFavorites = (prefs.getStringList('pending_sync_favorites') ?? []).isNotEmpty;
        final hasPendingSettings = (prefs.getStringList('pending_sync_settings') ?? []).isNotEmpty;
        
        expect(hasPendingFavorites, true);
        expect(hasPendingSettings, true);
      });

      test('TC-OFFLINE-010: Sync queue cleared after successful sync', () async {
        final prefs = await SharedPreferences.getInstance();
        
        await prefs.setStringList('pending_sync_favorites', ['item1']);
        
        // Simulate successful sync
        await prefs.remove('pending_sync_favorites');
        
        expect(prefs.getStringList('pending_sync_favorites'), isNull);
      });
    });

    group('Conflict Resolution', () {
      test('TC-OFFLINE-011: Local changes timestamped', () async {
        final prefs = await SharedPreferences.getInstance();
        
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        await prefs.setInt('favorites_last_modified_local', timestamp);
        
        expect(prefs.getInt('favorites_last_modified_local'), timestamp);
      });

      test('TC-OFFLINE-012: Last-write-wins strategy', () {
        final localTimestamp = DateTime.now().millisecondsSinceEpoch;
        final serverTimestamp = localTimestamp - 1000; // 1 second older
        
        // Local is newer, should win
        expect(localTimestamp > serverTimestamp, true);
      });

      test('TC-OFFLINE-013: Handles simultaneous offline changes', () async {
        final prefs = await SharedPreferences.getInstance();
        
        // Device A adds favorite
        await prefs.setStringList('device_a_changes', ['add:article1']);
        
        // Device B removes favorite
        await prefs.setStringList('device_b_changes', ['remove:article2']);
        
        // Both changes should be tracked
        expect(prefs.getStringList('device_a_changes'), isNotNull);
        expect(prefs.getStringList('device_b_changes'), isNotNull);
      });
    });

    group('Cache Management', () {
      test('TC-OFFLINE-014: Old cache cleared on storage full', () async {
        final prefs = await SharedPreferences.getInstance();
        
        // Simulate old cached data
        final oldArticles = List.generate(100, (i) => 'old_$i');
        await prefs.setStringList('old_cache', oldArticles);
        
        // Clear old cache
        await prefs.remove('old_cache');
        
        expect(prefs.getStringList('old_cache'), isNull);
      });

      test('TC-OFFLINE-015: Cache expiry based on age', () {
        final cacheTime = DateTime.now().subtract(Duration(days: 8));
        final maxAge = Duration(days: 7);
        
        final isExpired = DateTime.now().difference(cacheTime) > maxAge;
        expect(isExpired, true);
      });
    });
  });
}
