import '../../core/architecture/either.dart';
import '../../core/architecture/failure.dart';
import '../entities/news_article.dart';

/// Repository interface for news-related operations.
///
/// This defines the contract that data layer implementations must follow.
/// The UI layer should never interact with this directly - use cases should
/// be used instead.
abstract class NewsRepository {
  /// Fetches a paginated list of news articles.
  ///
  /// Parameters:
  /// - [page]: Page number (1-indexed)
  /// - [limit]: Number of articles per page
  /// - [category]: Optional category filter
  ///
  /// Returns [Right] with list of articles on success,
  /// or [Left] with [NetworkFailure]/[ServerFailure] on error.
  Future<Either<AppFailure, List<NewsArticle>>> getNewsFeed({
    required int page,
    required int limit,
    String? category,
  });

  /// Fetches a single article by ID.
  ///
  /// Returns [Right] with the article on success,
  /// or [Left] with [NotFoundFailure] if article doesn't exist.
  Future<Either<AppFailure, NewsArticle>> getArticleById(String id);

  /// Bookmarks an article for later reading.
  ///
  /// Returns [Right] with void on success,
  /// or [Left] with [StorageFailure] on error.
  Future<Either<AppFailure, void>> bookmarkArticle(String articleId);

  /// Removes an article from bookmarks.
  ///
  /// Returns [Right] with void on success,
  /// or [Left] with [StorageFailure] on error.
  Future<Either<AppFailure, void>> unbookmarkArticle(String articleId);

  /// Fetches all bookmarked articles.
  ///
  /// Returns [Right] with list of bookmarked articles,
  /// or [Left] with [StorageFailure] on error.
  Future<Either<AppFailure, List<NewsArticle>>> getBookmarkedArticles();

  /// Marks an article as read.
  ///
  /// Returns [Right] with void on success,
  /// or [Left] with [StorageFailure] on error.
  Future<Either<AppFailure, void>> markAsRead(String articleId);

  /// Searches articles by query.
  ///
  /// Parameters:
  /// - [query]: Search query string
  /// - [limit]: Maximum number of results
  ///
  /// Returns [Right] with matching articles,
  /// or [Left] with [NetworkFailure] on error.
  Future<Either<AppFailure, List<NewsArticle>>> searchArticles({
    required String query,
    int limit = 20,
  });

  /// Gets articles for a specific category.
  ///
  /// Returns [Right] with category articles,
  /// or [Left] with [NetworkFailure] on error.
  Future<Either<AppFailure, List<NewsArticle>>> getArticlesByCategory(
    String category, {
    int page = 1,
    int limit = 20,
  });

  /// Shares an article and tracks the share event.
  ///
  /// Returns [Right] with void on success,
  /// or [Left] with [AppFailure] on error.
  Future<Either<AppFailure, void>> shareArticle(String articleId);
}
