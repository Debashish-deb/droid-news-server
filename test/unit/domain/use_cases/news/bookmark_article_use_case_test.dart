import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'package:bdnewsreader/core/architecture/either.dart';
import 'package:bdnewsreader/core/architecture/failure.dart';
import 'package:bdnewsreader/domain/repositories/news_repository.dart';
import 'package:bdnewsreader/domain/use_cases/news/bookmark_article_use_case.dart';

@GenerateMocks([NewsRepository])
import 'bookmark_article_use_case_test.mocks.dart';

void main() {
  provideDummy<Either<AppFailure, void>>(
    const Right(null),
  );

  late BookmarkArticleUseCase useCase;
  late MockNewsRepository mockRepository;

  setUp(() {
    mockRepository = MockNewsRepository();
    useCase = BookmarkArticleUseCase(mockRepository);
  });

  group('BookmarkArticleUseCase', () {
    const testArticleId = 'test-article-123';

    test('should bookmark article successfully', () async {
      // Arrange
      when(mockRepository.bookmarkArticle(testArticleId))
          .thenAnswer((_) async => const Right(null));

      // Act
      final result = await useCase.execute(
        const BookmarkArticleParams(
          articleId: testArticleId,
          shouldBookmark: true,
        ),
      );

      // Assert
      expect(result.isRight(), true);
      verify(mockRepository.bookmarkArticle(testArticleId)).called(1);
    });

    test('should unbookmark article when already bookmarked', () async {
      // Arrange
      when(mockRepository.unbookmarkArticle(testArticleId))
          .thenAnswer((_) async => const Right(null));

      // Act
      final result = await useCase.execute(
        const BookmarkArticleParams(
          articleId: testArticleId,
          shouldBookmark: false, // unbookmark
        ),
      );

      // Assert
      expect(result.isRight(), true);
      verify(mockRepository.unbookmarkArticle(testArticleId)).called(1);
      verifyNever(mockRepository.bookmarkArticle(any));
    });

    test('should return StorageFailure when bookmark fails', () async {
      // Arrange
      const failure = StorageFailure('Failed to save bookmark');
      when(mockRepository.bookmarkArticle(testArticleId))
          .thenAnswer((_) async => const Left(failure));

      // Act
      final result = await useCase.execute(
        const BookmarkArticleParams(
          articleId: testArticleId,
          shouldBookmark: true,
        ),
      );

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (f) {
          expect(f, isA<StorageFailure>());
          expect(f.message, contains('Failed to save bookmark'));
        },
        (_) => fail('Expected failure'),
      );
    });

    test('should return StorageFailure when unbookmark fails', () async {
      // Arrange
      const failure = StorageFailure('Failed to remove bookmark');
      when(mockRepository.unbookmarkArticle(testArticleId))
          .thenAnswer((_) async => const Left(failure));

      // Act
      final result = await useCase.execute(
        const BookmarkArticleParams(
          articleId: testArticleId,
          shouldBookmark: false, // unbookmark
        ),
      );

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f, isA<StorageFailure>()),
        (_) => fail('Expected failure'),
      );
    });

    test('should handle network failure gracefully', () async {
      // Arrange
      const failure = NetworkFailure('No network connection');
      when(mockRepository.bookmarkArticle(testArticleId))
          .thenAnswer((_) async => const Left(failure));

      // Act
      final result = await useCase.execute(
        const BookmarkArticleParams(
          articleId: testArticleId,
          shouldBookmark: true,
        ),
      );

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f, isA<NetworkFailure>()),
        (_) => fail('Expected failure'),
      );
    });
  });
}
