import '../../../core/architecture/either.dart';
import '../../../core/architecture/failure.dart';
import '../../../core/architecture/use_case.dart';
import '../../entities/news_article.dart';
import '../../repositories/news_repository.dart';

/// Use case for fetching a paginated news feed.
///
/// This encapsulates the business logic for retrieving news articles,
/// separating it from both the UI and data layer concerns.
class FetchNewsFeedUseCase
    implements UseCase<List<NewsArticle>, FetchNewsFeedParams> {
  const FetchNewsFeedUseCase(this._repository);
  final NewsRepository _repository;

  @override
  Future<Either<AppFailure, List<NewsArticle>>> execute(
    FetchNewsFeedParams params,
  ) async {
    // Validate parameters
    if (params.page < 1) {
      return const Left(
        ValidationFailure('Page number must be greater than 0', {
          'page': 'Page number must be at least 1',
        }),
      );
    }

    if (params.limit < 1 || params.limit > 100) {
      return const Left(
        ValidationFailure('Limit must be between 1 and 100', {
          'limit': 'Limit must be between 1 and 100',
        }),
      );
    }

    // Fetch news from repository
    return await _repository.getNewsFeed(
      page: params.page,
      limit: params.limit,
      category: params.category,
    );
  }
}

/// Parameters for fetching news feed.
class FetchNewsFeedParams {
  const FetchNewsFeedParams({
    required this.page,
    this.limit = 20,
    this.category,
  });
  final int page;
  final int limit;
  final String? category;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FetchNewsFeedParams &&
          runtimeType == other.runtimeType &&
          page == other.page &&
          limit == other.limit &&
          category == other.category;

  @override
  int get hashCode => Object.hash(page, limit, category);

  @override
  String toString() =>
      'FetchNewsFeedParams(page: $page, limit: $limit, category: $category)';
}
