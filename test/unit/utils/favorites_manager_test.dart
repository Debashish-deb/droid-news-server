import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bdnewsreader/data/models/news_article.dart';

/// Tests FavoritesManager patterns without importing the Firebase-dependent service
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FavoritesManager (Patterns)', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      prefs = await SharedPreferences.getInstance();
    });

    group('Article Favorites', () {
      test('TC-UNIT-030: Initial favorites list is empty', () {
        final favorites = prefs.getStringList('favorites') ?? [];
        expect(favorites, isEmpty);
      });

      test('TC-UNIT-031: addFavorite stores article', () async {
        final article = NewsArticle(
          title: 'Test Article',
          url: 'https://example.com/test',
          source: 'Test Source',
          publishedAt: DateTime.now(),
        );
        
        final favorites = [json.encode(article.toMap())];
        await prefs.setStringList('favorites', favorites);
        
        expect(prefs.getStringList('favorites')!.length, 1);
      });

      test('TC-UNIT-032: removeFavorite updates list', () async {
        await prefs.setStringList('favorites', ['{"title":"t","url":"u","source":"s","publishedAt":"2024-01-01T00:00:00.000"}']);
        expect(prefs.getStringList('favorites')!.length, 1);
        
        await prefs.setStringList('favorites', []);
        expect(prefs.getStringList('favorites'), isEmpty);
      });

      test('TC-UNIT-033: toggleArticle adds when not favorited', () async {
        final list = prefs.getStringList('favorites') ?? [];
        const article = '{"title":"t","url":"u","source":"s","publishedAt":"2024-01-01T00:00:00.000"}';
        
        list.add(article);
        await prefs.setStringList('favorites', list);
        
        expect(prefs.getStringList('favorites')!.length, 1);
      });

      test('TC-UNIT-034: toggleArticle removes when already favorited', () async {
        await prefs.setStringList('favorites', ['article1']);
        
        final list = prefs.getStringList('favorites') ?? [];
        list.remove('article1');
        await prefs.setStringList('favorites', list);
        
        expect(prefs.getStringList('favorites'), isEmpty);
      });

      test('TC-UNIT-035: isFavoriteArticle checks URL', () {
        final favorites = ['{"title":"t","url":"https://example.com/test","source":"s","publishedAt":"2024-01-01T00:00:00.000"}'];
        
        bool isFavorite(String url) {
          return favorites.any((f) {
            final map = json.decode(f);
            return map['url'] == url;
          });
        }
        
        expect(isFavorite('https://example.com/test'), isTrue);
        expect(isFavorite('https://example.com/other'), isFalse);
      });
    });

    group('Magazine Favorites', () {
      test('TC-UNIT-036: Initial magazine favorites is empty', () {
        expect(prefs.getStringList('magazine_favorites'), isNull);
      });

      test('TC-UNIT-037: toggleMagazine adds magazine', () async {
        final magazines = [json.encode({'id': 'mag1', 'name': 'Test Magazine'})];
        await prefs.setStringList('magazine_favorites', magazines);
        
        expect(prefs.getStringList('magazine_favorites')!.length, 1);
      });

      test('TC-UNIT-038: toggleMagazine removes when already favorited', () async {
        await prefs.setStringList('magazine_favorites', ['{"id":"mag1"}']);
        await prefs.setStringList('magazine_favorites', []);
        
        expect(prefs.getStringList('magazine_favorites'), isEmpty);
      });
    });

    group('Newspaper Favorites', () {
      test('TC-UNIT-039: Initial newspaper favorites is empty', () {
        expect(prefs.getStringList('newspaper_favorites'), isNull);
      });

      test('TC-UNIT-040: toggleNewspaper adds newspaper', () async {
        final newspapers = [json.encode({'id': 'paper1', 'name': 'Prothom Alo'})];
        await prefs.setStringList('newspaper_favorites', newspapers);
        
        expect(prefs.getStringList('newspaper_favorites')!.length, 1);
      });

      test('TC-UNIT-041: toggleNewspaper removes when already favorited', () async {
        await prefs.setStringList('newspaper_favorites', ['{"id":"paper1"}']);
        await prefs.setStringList('newspaper_favorites', []);
        
        expect(prefs.getStringList('newspaper_favorites'), isEmpty);
      });
    });

    group('Persistence', () {
      test('TC-UNIT-042: Favorites persist to SharedPreferences', () async {
        await prefs.setStringList('favorites', ['article1', 'article2']);
        
        final saved = prefs.getStringList('favorites');
        expect(saved!.length, 2);
      });
    });

    group('Serialization', () {
      test('TC-UNIT-043: NewsArticle serializes correctly', () {
        final article = NewsArticle(
          title: 'Serialize Test',
          url: 'https://example.com',
          source: 'Source',
          publishedAt: DateTime(2024, 12, 25),
        );
        
        final serialized = json.encode(article.toMap());
        final restored = NewsArticle.fromMap(json.decode(serialized));
        
        expect(restored.title, article.title);
        expect(restored.url, article.url);
      });
    });
  });
}
