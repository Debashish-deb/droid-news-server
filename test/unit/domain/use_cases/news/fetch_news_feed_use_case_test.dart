import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:bdnewsreader/core/architecture/either.dart';
import 'package:bdnewsreader/core/architecture/failure.dart';
import "package:bdnewsreader/domain/entities/news_article.dart";
import 'package:bdnewsreader/domain/repositories/news_repository.dart';
import 'package:bdnewsreader/application/news/fetch_news_feed_use_case.dart';

// Manual Mocks
class MockNewsRepository extends Mock implements NewsRepository {
  @override
  Future<Either<AppFailure, List<NewsArticle>>> getNewsFeed({
    required int page,
    required int limit,
    String? category,
    String? language,
  }) {
      return super.noSuchMethod(
      Invocation.method(
        #getNewsFeed,
        [],
        <Symbol, Object?>{
          #page: page,
          #limit: limit,
          #category: category,
          #language: language,
        },
      ),
      returnValue: Future.value(
        const Right<AppFailure, List<NewsArticle>>(<NewsArticle>[]),
      ),
      returnValueForMissingStub: Future.value(
        const Right<AppFailure, List<NewsArticle>>(<NewsArticle>[]),
      ),
    ) as Future<Either<AppFailure, List<NewsArticle>>>;
  }
}

void main() {
  provideDummy<Either<AppFailure, List<NewsArticle>>>(
    const Right([]),
  );
  provideDummy<Future<Either<AppFailure, List<NewsArticle>>>>(
    Future.value(const Right([])),
  );

  late FetchNewsFeedUseCase useCase;
  late MockNewsRepository mockRepository;

  setUp(() {
    mockRepository = MockNewsRepository();
    useCase = FetchNewsFeedUseCase(mockRepository);
  });

  group('FetchNewsFeedUseCase', () {
    const testCategory = 'latest';
    final testArticles = [
      NewsArticle(
        url: 'https://example.com/1',
        title: 'Test Article 1',
        description: 'Content 1',
        publishedAt: DateTime(2026, 1, 5),
        source: 'Test Source',
      ),
      NewsArticle(
        url: 'https://example.com/2',
        title: 'Test Article 2',
        description: 'Content 2',
        publishedAt: DateTime(2026, 1, 4),
        source: 'Test Source',
      ),
    ];

    test('should return list of articles on success', () async {
      // Arrange
      when(mockRepository.getNewsFeed(
        page: 1,
        limit: 20,
        category: testCategory,
      )).thenAnswer((_) async => Right(testArticles));

      // Act
      final result = await useCase.execute(
        const FetchNewsFeedParams(
          page: 1,
          category: testCategory,
        ),
      );

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Expected success but got failure: $failure'),
        (articles) {
          expect(articles, testArticles);
          expect(articles.length, 2);
          expect(articles[0].title, 'Test Article 1');
        },
      );

      verify(mockRepository.getNewsFeed(
        page: 1,
        limit: 20,
        category: testCategory,
      )).called(1);
    });

    test('should return NetworkFailure on network error', () async {
      // Arrange
      const failure = NetworkFailure('Connection failed');
      when(mockRepository.getNewsFeed(
        page: 1,
        limit: 20,
        category: testCategory,
      )).thenAnswer((_) async => const Left(failure));

      // Act
      final result = await useCase.execute(
        const FetchNewsFeedParams(
          page: 1,
          category: testCategory,
        ),
      );

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (f) {
          expect(f, isA<NetworkFailure>());
          expect(f.message, 'Connection failed');
        },
        (_) => fail('Expected failure but got success'),
      );

      verify(mockRepository.getNewsFeed(
        page: 1,
        limit: 20,
        category: testCategory,
      )).called(1);
    });

    test('should use default limit when not provided', () async {
      // Arrange
      when(mockRepository.getNewsFeed(
        page: 1,
        limit: 20,
        category: testCategory,
      )).thenAnswer((_) async => Right(testArticles));

      // Act - using default limit
      final result = await useCase.execute(
        const FetchNewsFeedParams(
          page: 1,
          category: testCategory,
        ),
      );

      // Assert
      expect(result.isRight(), true);
      verify(mockRepository.getNewsFeed(
        page: 1,
        limit: 20, // default value
        category: testCategory,
      )).called(1);
    });

    test('should handle empty result list', () async {
      // Arrange
      when(mockRepository.getNewsFeed(
        page: 1,
        limit: 20,
        category: testCategory,
      )).thenAnswer((_) async => const Right([]));

      // Act
      final result = await useCase.execute(
        const FetchNewsFeedParams(page: 1, category: testCategory),
      );

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Expected success'),
        (articles) => expect(articles, isEmpty),
      );
    });

    test('should return StorageFailure on storage error', () async {
      // Arrange
      const failure = StorageFailure('Database error');
      when(mockRepository.getNewsFeed(
        page: 1,
        limit: 20,
        category: testCategory,
      )).thenAnswer((_) async => const Left(failure));

      // Act
      final result = await useCase.execute(
        const FetchNewsFeedParams(page: 1, category: testCategory),
      );

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f, isA<StorageFailure>()),
        (_) => fail('Expected failure'),
      );
    });
  });
}
