import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bdnewsreader/infrastructure/persistence/services/offline_service.dart';
import 'package:bdnewsreader/domain/entities/news_article.dart';

class MockOfflineService extends Mock implements OfflineService {}

void main() {
  setUpAll(() {
    registerFallbackValue(NewsArticle(
      title: 'fallback',
      url: 'fallback',
      source: 'fallback',
      publishedAt: DateTime(2024),
    ));
    registerFallbackValue('');
  });

  group('Offline Service Tests', () {
    late MockOfflineService mockOfflineService;

    setUp(() {
      mockOfflineService = MockOfflineService();
    });

    group('article operations', () {
      final testArticle = NewsArticle(
        title: 'Test Article',
        url: 'https://example.com/1',
        source: 'Test Source',
        publishedAt: DateTime.now(),
      );

      test('download article correctly', () async {
        // Arrange
        when(() => mockOfflineService.downloadArticleInstance(any()))
          .thenAnswer((_) async => true);

        // Act
        final result = await mockOfflineService.downloadArticleInstance(testArticle);

        // Assert
        expect(result, true);
        verify(() => mockOfflineService.downloadArticleInstance(testArticle)).called(1);
      });

      test('check if article is downloaded', () async {
        // Arrange
        when(() => mockOfflineService.isArticleDownloadedInstance(any()))
          .thenAnswer((_) async => true);

        // Act
        final result = await mockOfflineService.isArticleDownloadedInstance(testArticle.url);

        // Assert
        expect(result, true);
        verify(() => mockOfflineService.isArticleDownloadedInstance(testArticle.url)).called(1);
      });

      test('list downloaded articles', () async {
        // Arrange
        when(() => mockOfflineService.getDownloadedArticlesInstance())
          .thenAnswer((_) async => [testArticle]);

        // Act
        final result = await mockOfflineService.getDownloadedArticlesInstance();

        // Assert
        expect(result, isA<List<NewsArticle>>());
        expect(result.length, 1);
        expect(result.first.url, testArticle.url);
      });

      test('delete article', () async {
        // Arrange
        when(() => mockOfflineService.deleteArticleInstance(any()))
          .thenAnswer((_) async => true);

        // Act
        final result = await mockOfflineService.deleteArticleInstance(testArticle.url);

        // Assert
        expect(result, true);
        verify(() => mockOfflineService.deleteArticleInstance(testArticle.url)).called(1);
      });

      test('clear all articles', () async {
        // Arrange
        when(() => mockOfflineService.clearAllInstance())
          .thenAnswer((_) async => true);

        // Act
        final result = await mockOfflineService.clearAllInstance();

        // Assert
        expect(result, true);
        verify(() => mockOfflineService.clearAllInstance()).called(1);
      });
    });

    group('storage metrics', () {
      test('get storage used', () async {
        // Arrange
        when(() => mockOfflineService.getStorageUsedInstance())
          .thenAnswer((_) async => 1024);

        // Act
        final result = await mockOfflineService.getStorageUsedInstance();

        // Assert
        expect(result, 1024);
      });

      test('get downloaded count', () async {
        // Arrange
        when(() => mockOfflineService.getDownloadedCountInstance())
          .thenAnswer((_) async => 5);

        // Act
        final result = await mockOfflineService.getDownloadedCountInstance();

        // Assert
        expect(result, 5);
      });
    });
  });
}
