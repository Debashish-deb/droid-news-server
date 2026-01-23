import 'package:flutter_test/flutter_test.dart';
import 'package:bdnewsreader/data/models/news_article.dart';

void main() {
  group('NewsArticle Model', () {
    group('Construction', () {
      test('TC-MODEL-001: NewsArticle can be created with required fields', () {
        final article = NewsArticle(
          title: 'Test Title',
          url: 'https://example.com/article',
          source: 'Test Source',
          publishedAt: DateTime(2024, 12, 25),
        );
        
        expect(article.title, 'Test Title');
        expect(article.url, 'https://example.com/article');
        expect(article.source, 'Test Source');
        expect(article.publishedAt, DateTime(2024, 12, 25));
      });

      test('TC-MODEL-002: NewsArticle can be created with optional fields', () {
        final article = NewsArticle(
          title: 'Test',
          url: 'https://example.com',
          source: 'Source',
          publishedAt: DateTime.now(),
          description: 'Test description',
          snippet: 'Short snippet',
          imageUrl: 'https://example.com/image.jpg',
          language: 'bn',
          isLive: true,
        );
        
        expect(article.description, 'Test description');
        expect(article.snippet, 'Short snippet');
        expect(article.imageUrl, 'https://example.com/image.jpg');
        expect(article.language, 'bn');
        expect(article.isLive, isTrue);
      });

      test('TC-MODEL-003: Default values are correct', () {
        final article = NewsArticle(
          title: 'Test',
          url: 'https://example.com',
          source: 'Source',
          publishedAt: DateTime.now(),
        );
        
        // description and other optional strings default to empty string
        expect(article.description, isEmpty);
        expect(article.isLive, isFalse);
      });
    });

    group('Serialization', () {
      test('TC-MODEL-004: toMap returns valid map', () {
        final article = NewsArticle(
          title: 'Serialize Test',
          url: 'https://example.com/serialize',
          source: 'Test Source',
          description: 'Description',
          publishedAt: DateTime(2024, 12, 25, 10, 30),
          isLive: true,
        );
        
        final map = article.toMap();
        
        expect(map['title'], 'Serialize Test');
        expect(map['url'], 'https://example.com/serialize');
        expect(map['source'], 'Test Source');
        expect(map['description'], 'Description');
        expect(map['isLive'], isTrue);
        expect(map.containsKey('publishedAt'), isTrue);
      });

      test('TC-MODEL-005: fromMap creates valid article', () {
        final map = {
          'title': 'From Map Test',
          'url': 'https://example.com/frommap',
          'source': 'Map Source',
          'description': 'Map description',
          'publishedAt': '2024-12-25T10:30:00.000',
          'isLive': false,
        };
        
        final article = NewsArticle.fromMap(map);
        
        expect(article.title, 'From Map Test');
        expect(article.url, 'https://example.com/frommap');
        expect(article.source, 'Map Source');
        expect(article.description, 'Map description');
      });

      test('TC-MODEL-006: Round-trip serialization preserves data', () {
        final original = NewsArticle(
          title: 'Round Trip',
          url: 'https://example.com/roundtrip',
          source: 'Original Source',
          description: 'Original description',
          snippet: 'Short',
          imageUrl: 'https://example.com/img.jpg',
          publishedAt: DateTime(2024, 12, 25, 10),
          isLive: true,
        );
        
        final map = original.toMap();
        final restored = NewsArticle.fromMap(map);
        
        expect(restored.title, original.title);
        expect(restored.url, original.url);
        expect(restored.source, original.source);
        expect(restored.isLive, original.isLive);
      });
    });

    group('LIVE Badge', () {
      test('TC-MODEL-007: isLive flag can be true', () {
        final liveArticle = NewsArticle(
          title: 'Live Event',
          url: 'https://example.com/live',
          source: 'Live Source',
          publishedAt: DateTime.now(),
          isLive: true,
        );
        
        expect(liveArticle.isLive, isTrue);
      });

      test('TC-MODEL-008: isLive flag defaults to false', () {
        final regularArticle = NewsArticle(
          title: 'Regular',
          url: 'https://example.com/regular',
          source: 'Source',
          publishedAt: DateTime.now(),
        );
        
        expect(regularArticle.isLive, isFalse);
      });
    });

    group('Date Handling', () {
      test('TC-MODEL-009: publishedAt stores correct date', () {
        final date = DateTime(2024, 12, 25, 15, 30, 45);
        final article = NewsArticle(
          title: 'Test',
          url: 'https://example.com',
          source: 'Source',
          publishedAt: date,
        );
        
        expect(article.publishedAt.year, 2024);
        expect(article.publishedAt.month, 12);
        expect(article.publishedAt.day, 25);
        expect(article.publishedAt.hour, 15);
      });

      test('TC-MODEL-010: Articles can be sorted by date', () {
        final articles = [
          NewsArticle(title: 'Old', url: 'u1', source: 's', publishedAt: DateTime(2024)),
          NewsArticle(title: 'New', url: 'u2', source: 's', publishedAt: DateTime(2024, 12, 25)),
          NewsArticle(title: 'Mid', url: 'u3', source: 's', publishedAt: DateTime(2024, 6, 15)),
        ];
        
        articles.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
        
        expect(articles[0].title, 'New');
        expect(articles[1].title, 'Mid');
        expect(articles[2].title, 'Old');
      });
    });

    group('Image Handling', () {
      test('TC-MODEL-011: imageUrl can be null', () {
        final article = NewsArticle(
          title: 'No Image',
          url: 'https://example.com',
          source: 'Source',
          publishedAt: DateTime.now(),
        );
        
        expect(article.imageUrl, isNull);
      });

      test('TC-MODEL-012: imageUrl stores URL correctly', () {
        final article = NewsArticle(
          title: 'With Image',
          url: 'https://example.com',
          source: 'Source',
          publishedAt: DateTime.now(),
          imageUrl: 'https://cdn.example.com/image.jpg',
        );
        
        expect(article.imageUrl, 'https://cdn.example.com/image.jpg');
      });
    });
  });
}
