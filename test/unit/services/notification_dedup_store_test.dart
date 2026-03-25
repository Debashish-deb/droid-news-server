import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bdnewsreader/infrastructure/persistence/notifications/notification_dedup_store.dart';

void main() {
  late NotificationDedupStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    store = NotificationDedupStore(prefs);
  });

  group('shouldShow', () {
    test('returns true for unseen article', () {
      expect(store.shouldShow('article_123'), isTrue);
    });

    test('returns false after markShown', () async {
      await store.markShown('article_123');
      expect(store.shouldShow('article_123'), isFalse);
    });

    test('returns false for empty key', () {
      expect(store.shouldShow(''), isFalse);
    });
  });

  group('filterUnseen', () {
    test('returns only articles not yet shown', () async {
      await store.markAllShown(['a1', 'a2', 'a3']);
      final unseen = store.filterUnseen(['a2', 'a4', 'a5']);
      expect(unseen, ['a4', 'a5']);
    });

    test('strips empty keys', () {
      final unseen = store.filterUnseen(['a1', '', 'a2']);
      expect(unseen, ['a1', 'a2']);
    });
  });

  group('markAllShown', () {
    test('marks multiple articles as shown in one call', () async {
      await store.markAllShown(['x1', 'x2', 'x3']);
      expect(store.shouldShow('x1'), isFalse);
      expect(store.shouldShow('x2'), isFalse);
      expect(store.shouldShow('x3'), isFalse);
      // Unseen article still shows
      expect(store.shouldShow('x4'), isTrue);
    });

    test('no-ops on empty list', () async {
      // Should not throw
      await store.markAllShown([]);
      expect(store.shouldShow('anything'), isTrue);
    });
  });

  group('lastNotifiedAt', () {
    test('returns null when never set', () {
      expect(store.lastNotifiedAt, isNull);
    });

    test('returns stored time after updateLastNotifiedAt', () async {
      final before = DateTime.now();
      await store.updateLastNotifiedAt();
      final after = store.lastNotifiedAt!;
      expect(after.isAfter(before.subtract(const Duration(seconds: 1))), isTrue);
    });

    test('accepts explicit time', () async {
      final custom = DateTime(2026, 1, 15, 10, 30);
      await store.updateLastNotifiedAt(custom);
      expect(store.lastNotifiedAt, custom);
    });
  });

  group('cleanup', () {
    test('evicts entries older than 48 hours', () async {
      // Manually inject an old entry via SharedPreferences
      SharedPreferences.setMockInitialValues({
        'notif_shown_article_keys':
            '{"old_article":"2020-01-01T00:00:00.000","fresh_article":"${DateTime.now().toIso8601String()}"}',
      });
      final prefs = await SharedPreferences.getInstance();
      store = NotificationDedupStore(prefs);

      final removed = await store.cleanup();
      expect(removed, 1);
      expect(store.shouldShow('old_article'), isTrue); // evicted
      expect(store.shouldShow('fresh_article'), isFalse); // still present
    });

    test('caps at maxStoredArticles (FIFO)', () async {
      // Fill with maxStoredArticles + 50 entries
      final entries = <String, String>{};
      for (int i = 0; i < NotificationDedupStore.maxStoredArticles + 50; i++) {
        // Give each a slightly different timestamp so FIFO ordering works
        final ts = DateTime.now()
            .subtract(Duration(minutes: NotificationDedupStore.maxStoredArticles + 50 - i));
        entries['art_$i'] = ts.toIso8601String();
      }
      SharedPreferences.setMockInitialValues({
        'notif_shown_article_keys': entries.entries
            .map((e) => '"${e.key}":"${e.value}"')
            .join(',')
            .let((s) => '{$s}'),
      });
      final prefs = await SharedPreferences.getInstance();
      store = NotificationDedupStore(prefs);

      await store.cleanup();

      // The oldest 50 should have been evicted, so the earliest remaining
      // article should be art_50.
      expect(store.shouldShow('art_0'), isTrue); // evicted
      expect(store.shouldShow('art_49'), isTrue); // evicted
      expect(
        store.shouldShow('art_${NotificationDedupStore.maxStoredArticles + 49}'),
        isFalse,
      ); // kept (newest)
    });
  });

  group('corrupt data handling', () {
    test('handles invalid JSON in SharedPreferences gracefully', () async {
      SharedPreferences.setMockInitialValues({
        'notif_shown_article_keys': 'NOT VALID JSON!!!',
      });
      final prefs = await SharedPreferences.getInstance();
      store = NotificationDedupStore(prefs);

      // Should not throw, and should treat as empty
      expect(store.shouldShow('any_article'), isTrue);
      await store.markShown('any_article');
      expect(store.shouldShow('any_article'), isFalse);
    });

    test('handles empty string in SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        'notif_shown_article_keys': '',
      });
      final prefs = await SharedPreferences.getInstance();
      store = NotificationDedupStore(prefs);

      expect(store.shouldShow('test'), isTrue);
    });
  });
}

// Extension to make the FIFO cap test cleaner
extension _StringLet on String {
  T let<T>(T Function(String) fn) => fn(this);
}
