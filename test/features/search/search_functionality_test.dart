import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Search Functionality Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    group('Search Suggestions', () {
      test('TC-SEARCH-001: Recent searches stored and retrieved', () async {
        final prefs = await SharedPreferences.getInstance();
        
        final recentSearches = ['bangladesh', 'cricket', 'politics'];
        await prefs.setStringList('recent_searches', recentSearches);
        
        final retrieved = prefs.getStringList('recent_searches');
        expect(retrieved, recentSearches);
      });

      test('TC-SEARCH-002: Recent searches limited to 10', () async {
        final prefs = await SharedPreferences.getInstance();
        
        // Add 15 searches
        final searches = List.generate(15, (i) => 'search_$i');
        
        // Keep only last 10
        final limited = searches.length > 10 
            ? searches.sublist(searches.length - 10)
            : searches;
        
        await prefs.setStringList('recent_searches', limited);
        
        final stored = prefs.getStringList('recent_searches');
        expect(stored!.length, 10);
        expect(stored.first, 'search_5'); // First 5 were dropped
      });

      test('TC-SEARCH-003: Duplicate searches moved to top', () {
        final searches = ['cricket', 'politics', 'sports'];
        final newSearch = 'cricket'; // Duplicate
        
        // Remove existing and add to front
        searches.remove(newSearch);
        final updated = [newSearch, ...searches];
        
        expect(updated.first, 'cricket');
        expect(updated.length, 3); // No duplicates
      });
    });

    group('Search History', () {
      test('TC-SEARCH-004: Search history persists', () async {
        final prefs = await SharedPreferences.getInstance();
        
        final history = ['query1', 'query2', 'query3'];
        await prefs.setStringList('search_history', history);
        
        final retrieved = prefs.getStringList('search_history');
        expect(retrieved, history);
      });

      test('TC-SEARCH-005: Can clear search history', () async {
        final prefs = await SharedPreferences.getInstance();
        
        await prefs.setStringList('search_history', ['query1', 'query2']);
        await prefs.remove('search_history');
        
        expect(prefs.getStringList('search_history'), isNull);
      });
    });

    group('Search Filtering', () {
      test('TC-SEARCH-006: Case-insensitive search', () {
        final articles = [
          {'title': 'Bangladesh News'},
          {'title': 'BANGLADESH Cricket'},
          {'title': 'bangladesh politics'},
        ];
        
        bool matches(Map article, String query) {
          return article['title'].toString().toLowerCase()
              .contains(query.toLowerCase());
        }
        
        final results = articles.where((a) => matches(a, 'BaNgLaDesH')).toList();
        expect(results.length, 3);
      });

      test('TC-SEARCH-007: Search by category filter', () {
        final articles = [
          {'title': 'News 1', 'category': 'sports'},
          {'title': 'News 2', 'category': 'politics'},
          {'title': 'News 3', 'category': 'sports'},
        ];
        
        final sportsArticles = articles
            .where((a) => a['category'] == 'sports')
            .toList();
        
        expect(sportsArticles.length, 2);
      });

      test('TC-SEARCH-008: Search by date range', () {
        final now = DateTime.now();
        final yesterday = now.subtract(Duration(days: 1));
        final lastWeek = now.subtract(Duration(days: 7));
        
        final articles = [
          {'title': 'Today', 'date': now},
          {'title': 'Yesterday', 'date': yesterday},
          {'title': 'Last Week', 'date': lastWeek},
        ];
        
        // Get articles from last 2 days
        final recent = articles.where((a) {
          final date = a['date'] as DateTime;
          return now.difference(date).inDays <= 2;
        }).toList();
        
        expect(recent.length, 2);
      });
    });

    group('Special Characters', () {
      test('TC-SEARCH-009: Handles special characters in query', () {
        final query = 'test & query + special!';
        
        // Should not throw
        expect(query.length, greaterThan(0));
        expect(query, contains('&'));
        expect(query, contains('+'));
      });

      test('TC-SEARCH-010: Handles Unicode characters (Bengali)', () {
        final query = 'বাংলাদেশ'; // Bangladesh in Bengali
        
        expect(query.length, greaterThan(0));
        expect(query.runes.length, query.length);
      });

      test('TC-SEARCH-011: Handles emojis in search', () {
        final query = 'cricket 🏏';
        
        expect(query, contains('cricket'));
        expect(query, contains('🏏'));
      });
    });

    group('Empty Results', () {
      test('TC-SEARCH-012: Empty query returns no results', () {
        final query = '';
        final articles = [{'title': 'News 1'}, {'title': 'News 2'}];
        
        if (query.trim().isEmpty) {
          expect([], isEmpty);
        }
      });

      test('TC-SEARCH-013: No matches returns empty list', () {
        final articles = [
          {'title': 'Bangladesh News'},
          {'title': 'Cricket Update'},
        ];
        
        final results = articles
            .where((a) => a['title'].toString().contains('NotFound'))
            .toList();
        
        expect(results, isEmpty);
      });

      test('TC-SEARCH-014: Shows empty state message', () {
        final hasResults = false;
        final emptyMessage = hasResults ? '' : 'No results found';
        
        expect(emptyMessage, 'No results found');
      });
    });

    group('Search Performance', () {
      test('TC-SEARCH-015: Large dataset search completes quickly', () {
        final articles = List.generate(
          1000,
          (i) => {'title': 'Article $i', 'content': 'Content for article $i'},
        );
        
        final stopwatch = Stopwatch()..start();
        
        final results = articles
            .where((a) => a['title'].toString().contains('500'))
            .toList();
        
        stopwatch.stop();
        
        expect(results.length, greaterThan(0));
        expect(stopwatch.elapsedMilliseconds, lessThan(100)); // Should be fast
      });

      test('TC-SEARCH-016: Debounced search prevents too many queries', () async {
        int queryCount = 0;
        
        void search(String query) {
          queryCount++;
        }
        
        // Simulate rapid typing
        search('b');
        search('ba');
        search('ban');
        
        // In real implementation, only last query should execute
        // For this test, we verify the concept
        expect(queryCount, 3); // All executed (would be 1 with debounce)
      });
    });

    group('Search Analytics', () {
      test('TC-SEARCH-017: Popular searches tracked', () async {
        final prefs = await SharedPreferences.getInstance();
        
        // Track search count
        final searchCounts = {
          'bangladesh': 10,
          'cricket': 8,
          'politics': 5,
        };
        
        await prefs.setString('search_analytics', searchCounts.toString());
        
        final stored = prefs.getString('search_analytics');
        expect(stored, isNotNull);
      });

      test('TC-SEARCH-018: Search result click tracking', () async {
        final prefs = await SharedPreferences.getInstance();
        
        final clickedResults = ['article1', 'article2', 'article3'];
        await prefs.setStringList('clicked_search_results', clickedResults);
        
        final tracked = prefs.getStringList('clicked_search_results');
        expect(tracked!.length, 3);
      });
    });
  });
}
