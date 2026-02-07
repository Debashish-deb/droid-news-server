import '../../core/architecture/either.dart';
import '../../core/architecture/failure.dart';
import '../../core/architecture/use_case.dart';
import '../../domain/repositories/news_repository.dart' show NewsRepository;

/// Use case for bookmarking a news article.
///
/// Handles the business logic for saving an article for later reading.
class BookmarkArticleUseCase implements UseCase<void, BookmarkArticleParams> {
  const BookmarkArticleUseCase(this._repository);
  final NewsRepository _repository;

  @override
  Future<Either<AppFailure, void>> execute(BookmarkArticleParams params) async {
    if (params.articleId.trim().isEmpty) {
      return const Left(
        ValidationFailure('Article ID cannot be empty', {
          'articleId': 'Article ID is required',
        }),
      );
    }

    if (params.shouldBookmark) {
      return await _repository.bookmarkArticle(params.articleId);
    } else {
      return await _repository.unbookmarkArticle(params.articleId);
    }
  }
}

/// Parameters for bookmarking an article.
class BookmarkArticleParams {
  const BookmarkArticleParams({
    required this.articleId,
    required this.shouldBookmark,
  });
  final String articleId;
  final bool shouldBookmark;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BookmarkArticleParams &&
          runtimeType == other.runtimeType &&
          articleId == other.articleId &&
          shouldBookmark == other.shouldBookmark;

  @override
  int get hashCode => Object.hash(articleId, shouldBookmark);

  @override
  String toString() =>
      'BookmarkArticleParams(articleId: $articleId, shouldBookmark: $shouldBookmark)';
}
