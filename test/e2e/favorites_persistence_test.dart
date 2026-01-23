import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bdnewsreader/data/models/news_article.dart';

/// Tests favorites persistence patterns without importing Firebase-dependent FavoritesManager
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Favorites Persistence E2E', () {
    group('Article Favorites Persistence', () {
      test('TC-E2E-030: Favorites persist in SharedPreferences', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final prefs = await SharedPreferences.getInstance();
        
        final article = NewsArticle(
          title: 'Persistable Article',
          url: 'https://example.com/persist',
          source: 'Test Source',
          publishedAt: DateTime.now(),
        );
        
        // Save favorite
        final favorites = [json.encode(article.toMap())];
        await prefs.setStringList('favorites', favorites);
        
        // Verify persisted
        final saved = prefs.getStringList('favorites');
        expect(saved, isNotNull);
        expect(saved!.length, 1);
        
        // Restore and verify
        final restored = NewsArticle.fromMap(json.decode(saved.first));
        expect(restored.url, article.url);
      });

      test('TC-E2E-031: Multiple articles persist correctly', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final prefs = await SharedPreferences.getInstance();
        
        final articles = List.generate(5, (i) => NewsArticle(
          title: 'Article $i',
          url: 'https://example.com/article$i',
          source: 'Source',
          publishedAt: DateTime.now(),
        ));
        
        final serialized = articles.map((a) => json.encode(a.toMap())).toList();
        await prefs.setStringList('favorites', serialized);
        
        expect(prefs.getStringList('favorites')!.length, 5);
      });

      test('TC-E2E-032: Removed favorites update persistence', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          'favorites': ['{"title":"test","url":"u1","source":"s","publishedAt":"2024-01-01T00:00:00.000"}'],
        });
        final prefs = await SharedPreferences.getInstance();
        
        expect(prefs.getStringList('favorites')!.length, 1);
        
        // Remove all
        await prefs.setStringList('favorites', []);
        expect(prefs.getStringList('favorites')!.length, 0);
      });
    });

    group('Magazine Favorites Persistence', () {
      test('TC-E2E-033: Magazine favorites persist', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final prefs = await SharedPreferences.getInstance();
        
        final magazines = [
          json.encode({'id': 'mag1', 'name': 'Anandabazar'}),
          json.encode({'id': 'mag2', 'name': 'Robbar'}),
        ];
        
        await prefs.setStringList('magazine_favorites', magazines);
        expect(prefs.getStringList('magazine_favorites')!.length, 2);
      });
    });

    group('Newspaper Favorites Persistence', () {
      test('TC-E2E-034: Newspaper favorites persist', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final prefs = await SharedPreferences.getInstance();
        
        final newspapers = [
          json.encode({'id': 'paper1', 'name': 'Prothom Alo'}),
          json.encode({'id': 'paper2', 'name': 'Kaler Kantho'}),
        ];
        
        await prefs.setStringList('newspaper_favorites', newspapers);
        expect(prefs.getStringList('newspaper_favorites')!.length, 2);
      });
    });

    group('Cross-Type Persistence', () {
      test('TC-E2E-035: All favorite types persist independently', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final prefs = await SharedPreferences.getInstance();
        
        await prefs.setStringList('favorites', ['{"title":"a","url":"u","source":"s","publishedAt":"2024-01-01T00:00:00.000"}']);
        await prefs.setStringList('magazine_favorites', ['{"id":"m1","name":"M"}']);
        await prefs.setStringList('newspaper_favorites', ['{"id":"n1","name":"N"}']);
        
        expect(prefs.getStringList('favorites')!.length, 1);
        expect(prefs.getStringList('magazine_favorites')!.length, 1);
        expect(prefs.getStringList('newspaper_favorites')!.length, 1);
      });
    });

    group('Edge Cases', () {
      test('TC-E2E-036: Empty favorites don\'t crash', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final prefs = await SharedPreferences.getInstance();
        
        expect(prefs.getStringList('favorites'), isNull);
        expect(prefs.getStringList('magazine_favorites'), isNull);
        expect(prefs.getStringList('newspaper_favorites'), isNull);
      });

      test('TC-E2E-037: Toggle adds then removes', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final prefs = await SharedPreferences.getInstance();
        
        // Add
        await prefs.setStringList('favorites', ['{"title":"t","url":"u","source":"s","publishedAt":"2024-01-01T00:00:00.000"}']);
        expect(prefs.getStringList('favorites')!.length, 1);
        
        // Remove (toggle)
        await prefs.setStringList('favorites', []);
        expect(prefs.getStringList('favorites')!.length, 0);
      });
    });
  });
}
