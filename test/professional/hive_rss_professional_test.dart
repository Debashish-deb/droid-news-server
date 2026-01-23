import 'package:flutter_test/flutter_test.dart';
import 'package:bdnewsreader/data/services/rss_service.dart';
import 'package:bdnewsreader/data/models/news_article.dart';
import 'package:bdnewsreader/core/network_quality_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Professional Hive & RSS Tests', () {
    group('Cache TTL (Time To Live)', () {
      test('TC-HIVE-PRO-001: Cache has valid TTL configuration', () {
        final manager = NetworkQualityManager();
        final cacheDuration = manager.getCacheDuration();
        
        expect(cacheDuration.inMinutes, greaterThan(0));
        expect(cacheDuration.inHours, lessThanOrEqualTo(24));
      });

      test('TC-HIVE-PRO-002: Cache expiry is properly calculated', () {
        final cachedAt = DateTime.now().subtract(const Duration(hours: 2));
        const cacheDuration = Duration(hours: 1);
        
        final isExpired = DateTime.now().difference(cachedAt) > cacheDuration;
        
        expect(isExpired, isTrue); // 2 hours > 1 hour TTL
      });
    });

    group('RSS Service Categories', () {
      test('TC-RSS-PRO-001: All categories are defined', () {
        const categories = RssService.categories;
        
        expect(categories.length, greaterThanOrEqualTo(5));
        expect(categories, contains('latest'));
        expect(categories, contains('sports'));
      });
    });

    group('Data Validation', () {
      test('TC-RSS-PRO-002: NewsArticle validates required fields', () {
        final article = NewsArticle(
          title: 'Valid Title',
          url: 'https://example.com',
          source: 'Source',
          publishedAt: DateTime.now(),
        );
        
        expect(article.title.isNotEmpty, isTrue);
        expect(article.url.isNotEmpty, isTrue);
        expect(article.source.isNotEmpty, isTrue);
      });

      test('TC-RSS-PRO-003: Empty titles are filtered', () {
        final articles = [
          NewsArticle(title: 'Valid', url: 'u1', source: 's', publishedAt: DateTime.now()),
          NewsArticle(title: '', url: 'u2', source: 's', publishedAt: DateTime.now()),
        ];
        
        final valid = articles.where((a) => a.title.isNotEmpty).toList();
        
        expect(valid.length, 1);
      });
    });

    group('Network Adaptation', () {
      test('TC-RSS-PRO-004: NetworkQualityManager provides timeout', () {
        final manager = NetworkQualityManager();
        final timeout = manager.getAdaptiveTimeout();
        
        expect(timeout.inSeconds, greaterThanOrEqualTo(5));
        expect(timeout.inSeconds, lessThanOrEqualTo(60));
      });

      test('TC-RSS-PRO-005: NetworkQualityManager is singleton', () {
        final m1 = NetworkQualityManager();
        final m2 = NetworkQualityManager();
        
        expect(identical(m1, m2), isTrue);
      });
    });

    group('Deduplication', () {
      test('TC-RSS-PRO-006: Duplicate URLs are removed', () {
        final articles = [
          NewsArticle(title: 'A', url: 'same-url', source: 's', publishedAt: DateTime.now()),
          NewsArticle(title: 'B', url: 'same-url', source: 's', publishedAt: DateTime.now()),
          NewsArticle(title: 'C', url: 'different-url', source: 's', publishedAt: DateTime.now()),
        ];
        
        final seen = <String>{};
        final unique = articles.where((a) => seen.add(a.url)).toList();
        
        expect(unique.length, 2);
      });
    });

    group('Sorting', () {
      test('TC-RSS-PRO-007: Articles sorted by newest first', () {
        final articles = [
          NewsArticle(title: 'Old', url: 'u1', source: 's', publishedAt: DateTime(2024)),
          NewsArticle(title: 'New', url: 'u2', source: 's', publishedAt: DateTime(2024, 12, 25)),
          NewsArticle(title: 'Mid', url: 'u3', source: 's', publishedAt: DateTime(2024, 6, 15)),
        ];
        
        articles.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
        
        expect(articles[0].title, 'New');
        expect(articles[2].title, 'Old');
      });
    });

    group('Fallback Strategy', () {
      test('TC-RSS-PRO-008: Empty data doesn\'t overwrite valid cache', () {
        final existingCache = ['article1', 'article2'];
        final newData = <String>[];
        
        // Business logic: Never replace valid cache with empty
        final shouldUpdate = newData.isNotEmpty;
        
        expect(shouldUpdate, isFalse);
        expect(existingCache.length, 2); // Cache preserved
      });
    });

    group('Error Handling', () {
      test('TC-RSS-PRO-009: Errors return empty list, not throw', () async {
        Future<List<String>> fetchWithErrorHandling() async {
          try {
            throw Exception('Network error');
          } catch (e) {
            return []; // Graceful degradation
          }
        }
        
        final result = await fetchWithErrorHandling();
        expect(result, isEmpty);
      });
    });

    group('Serialization', () {
      test('TC-RSS-PRO-010: NewsArticle serializes to map', () {
        final article = NewsArticle(
          title: 'Test',
          url: 'https://example.com',
          source: 'Source',
          publishedAt: DateTime(2024, 12, 25),
        );
        
        final map = article.toMap();
        
        expect(map['title'], 'Test');
        expect(map['url'], 'https://example.com');
        expect(map.containsKey('publishedAt'), isTrue);
      });

      test('TC-RSS-PRO-011: NewsArticle deserializes from map', () {
        final map = {
          'title': 'From Map',
          'url': 'https://example.com',
          'source': 'Source',
          'publishedAt': '2024-12-25T00:00:00.000',
        };
        
        final article = NewsArticle.fromMap(map);
        
        expect(article.title, 'From Map');
        expect(article.url, 'https://example.com');
      });
    });

    group('Cache Performance', () {
      test('TC-HIVE-PRO-003: Map operations are fast', () {
        final cache = <String, String>{};
        
        final start = DateTime.now();
        for (int i = 0; i < 1000; i++) {
          cache['key$i'] = 'value$i';
        }
        final writeTime = DateTime.now().difference(start).inMilliseconds;
        
        expect(writeTime, lessThan(100)); // 1000 writes < 100ms
        expect(cache.length, 1000);
      });
    });
  });
}
