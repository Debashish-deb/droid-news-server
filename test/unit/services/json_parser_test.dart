import 'package:bdnewsreader/domain/entities/news_article.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';

void main() {
  group('JSON Parsing Tests', () {
    group('parse valid article JSON', () {
      test('parses complete article JSON correctly', () {
        // Arrange
        const validJson = '''
        {
          "id": "1",
          "title": "Test Article",
          "description": "Test Description",
          "url": "https://example.com/article1",
          "imageUrl": "https://example.com/image1.jpg",
          "publishedAt": "2024-01-01T00:00:00Z",
          "source": "Test Source"
        }
        ''';

        // Act
        final Map<String, dynamic> parsed = jsonDecode(validJson);
        final article = NewsArticle(
          title: parsed['title'] ?? '',
          description: parsed['description'] ?? '',
          url: parsed['url'] ?? '',
          imageUrl: parsed['imageUrl'],
          source: parsed['source'] ?? 'Unknown',
          publishedAt:
              DateTime.tryParse(parsed['publishedAt'] ?? '') ?? DateTime.now(),
        );

        // Assert
        expect(article.title, 'Test Article');
        expect(article.description, 'Test Description');
        expect(article.url, 'https://example.com/article1');
        expect(article.imageUrl, 'https://example.com/image1.jpg');
        expect(article.source, 'Test Source');
      });

      test('parses article with missing optional fields', () {
        // Arrange
        const minimalJson = '''
        {
          "id": "1",
          "title": "Test Article"
        }
        ''';

        // Act
        final Map<String, dynamic> parsed = jsonDecode(minimalJson);
        final article = NewsArticle(
          title: parsed['title'] ?? '',
          description: parsed['description'] ?? '',
          url: parsed['url'] ?? '',
          imageUrl: parsed['imageUrl'],
          source: parsed['source'] ?? 'Unknown',
          publishedAt:
              DateTime.tryParse(parsed['publishedAt'] ?? '') ?? DateTime.now(),
        );

        // Assert
        expect(article.title, 'Test Article');
        expect(article.description, '');
        expect(article.url, '');
        expect(article.imageUrl, null);
        expect(article.source, 'Unknown');
      });

      test('parses article with null image', () {
        // Arrange
        const noImageJson = '''
        {
          "id": "1",
          "title": "Test Article",
          "description": "Test Description",
          "url": "https://example.com/article1",
          "imageUrl": null,
          "publishedAt": "2024-01-01T00:00:00Z",
          "source": "Test Source"
        }
        ''';

        // Act
        final Map<String, dynamic> parsed = jsonDecode(noImageJson);
        final article = NewsArticle(
          title: parsed['title'] ?? '',
          description: parsed['description'] ?? '',
          url: parsed['url'] ?? '',
          imageUrl: parsed['imageUrl'],
          source: parsed['source'] ?? 'Unknown',
          publishedAt:
              DateTime.tryParse(parsed['publishedAt'] ?? '') ?? DateTime.now(),
        );

        // Assert
        expect(article.title, 'Test Article');
        expect(article.description, 'Test Description');
        expect(article.url, 'https://example.com/article1');
        expect(article.imageUrl, null);
        expect(article.source, 'Test Source');
      });
    });

    group('parse article with invalid data', () {
      test('handles invalid date gracefully', () {
        // Arrange
        const invalidDateJson = '''
        {
          "id": "1",
          "title": "Test Article",
          "description": "Test Description",
          "url": "https://example.com/article1",
          "imageUrl": "https://example.com/image1.jpg",
          "publishedAt": "invalid-date",
          "source": "Test Source"
        }
        ''';

        // Act
        final Map<String, dynamic> parsed = jsonDecode(invalidDateJson);
        final article = NewsArticle(
          title: parsed['title'] ?? '',
          description: parsed['description'] ?? '',
          url: parsed['url'] ?? '',
          imageUrl: parsed['imageUrl'],
          source: parsed['source'] ?? 'Unknown',
          publishedAt:
              DateTime.tryParse(parsed['publishedAt'] ?? '') ?? DateTime.now(),
        );

        // Assert
        expect(article.title, 'Test Article');
        expect(article.publishedAt, isNotNull); // Should fallback to now
        expect(
          article.publishedAt.isAfter(
            DateTime.now().subtract(const Duration(days: 1)),
          ),
          true,
        );
      });

      test('handles extra fields gracefully', () {
        // Arrange
        const extraFieldsJson = '''
        {
          "id": "1",
          "title": "Test Article",
          "description": "Test Description",
          "url": "https://example.com/article1",
          "imageUrl": "https://example.com/image1.jpg",
          "publishedAt": "2024-01-01T00:00:00Z",
          "source": "Test Source",
          "unexpectedField": "should be ignored",
          "anotherUnexpected": 123,
          "nestedObject": {"key": "value"}
        }
        ''';

        // Act
        final Map<String, dynamic> parsed = jsonDecode(extraFieldsJson);
        final article = NewsArticle(
          title: parsed['title'] ?? '',
          description: parsed['description'] ?? '',
          url: parsed['url'] ?? '',
          imageUrl: parsed['imageUrl'],
          source: parsed['source'] ?? 'Unknown',
          publishedAt:
              DateTime.tryParse(parsed['publishedAt'] ?? '') ?? DateTime.now(),
        );

        // Assert
        expect(article.title, 'Test Article');
        expect(article.description, 'Test Description');
        expect(article.url, 'https://example.com/article1');
        expect(article.imageUrl, 'https://example.com/image1.jpg');
        expect(article.source, 'Test Source');
        // Extra fields should be ignored without causing errors
      });

      test('handles emoji content', () {
        // Arrange
        const emojiJson = '''
        {
          "id": "1",
          "title": "Test Article 🔥 News",
          "description": "Breaking news 📰 today",
          "url": "https://example.com/article1",
          "imageUrl": "https://example.com/image1.jpg",
          "publishedAt": "2024-01-01T00:00:00Z",
          "source": "Test Source"
        }
        ''';

        // Act
        final Map<String, dynamic> parsed = jsonDecode(emojiJson);
        final article = NewsArticle(
          title: parsed['title'] ?? '',
          description: parsed['description'] ?? '',
          url: parsed['url'] ?? '',
          imageUrl: parsed['imageUrl'],
          source: parsed['source'] ?? 'Unknown',
          publishedAt:
              DateTime.tryParse(parsed['publishedAt'] ?? '') ?? DateTime.now(),
        );

        // Assert
        expect(article.title, 'Test Article 🔥 News');
        expect(article.description, 'Breaking news 📰 today');
        // Emoji should be preserved in strings
      });

      test('handles very long text', () {
        // Arrange
        final longText = 'A' * 1000; // Very long title
        final longJson =
            '''
        {
          "id": "1",
          "title": "$longText",
          "description": "Test Description",
          "url": "https://example.com/article1",
          "imageUrl": "https://example.com/image1.jpg",
          "publishedAt": "2024-01-01T00:00:00Z",
          "source": "Test Source"
        }
        ''';

        // Act
        final Map<String, dynamic> parsed = jsonDecode(longJson);
        final article = NewsArticle(
          title: parsed['title'] ?? '',
          description: parsed['description'] ?? '',
          url: parsed['url'] ?? '',
          imageUrl: parsed['imageUrl'],
          source: parsed['source'] ?? 'Unknown',
          publishedAt:
              DateTime.tryParse(parsed['publishedAt'] ?? '') ?? DateTime.now(),
        );

        // Assert
        expect(article.title.length, 1000);
        expect(article.title, longText);
        // Long text should be handled without truncation
      });
    });

    group('malformed JSON handling', () {
      test('handles incomplete JSON gracefully', () {
        // Arrange
        const incompleteJson = '''{"id": "1", "title": "Test"''';

        // Act & Assert
        expect(() => jsonDecode(incompleteJson), throwsFormatException);
      });

      test('handles empty JSON object', () {
        // Arrange
        const emptyJson = '{}';

        // Act
        final Map<String, dynamic> parsed = jsonDecode(emptyJson);
        final article = NewsArticle(
          title: parsed['title'] ?? '',
          description: parsed['description'] ?? '',
          url: parsed['url'] ?? '',
          imageUrl: parsed['imageUrl'],
          source: parsed['source'] ?? 'Unknown',
          publishedAt:
              DateTime.tryParse(parsed['publishedAt'] ?? '') ?? DateTime.now(),
        );

        // Assert
        expect(article.title, '');
        expect(article.description, '');
        expect(article.url, '');
        expect(article.imageUrl, null);
        expect(article.source, 'Unknown');
        expect(article.publishedAt, isNotNull);
      });
    });
  });
}
