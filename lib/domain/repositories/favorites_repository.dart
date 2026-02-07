import '../../core/architecture/either.dart';
import '../../core/architecture/failure.dart';
import '../entities/news_article.dart';

/// Repository interface for Favorites (Articles, Magazines, Newspapers).
abstract class FavoritesRepository {
  /// Toggle article favorite status.
  Future<Either<AppFailure, void>> toggleArticle(NewsArticle article);

  /// Check if article is favorite.
  bool isFavoriteArticle(String url);

  /// Get all favorite articles.
  Future<Either<AppFailure, List<NewsArticle>>> getFavoriteArticles();

  /// Toggle magazine favorite status.
  Future<Either<AppFailure, void>> toggleMagazine(Map<String, dynamic> magazine);

  /// Check if magazine is favorite.
  bool isFavoriteMagazine(String id);

  /// Get all favorite magazines.
  Future<Either<AppFailure, List<Map<String, dynamic>>>> getFavoriteMagazines();

  /// Toggle newspaper favorite status.
  Future<Either<AppFailure, void>> toggleNewspaper(Map<String, dynamic> newspaper);

  /// Check if newspaper is favorite.
  bool isFavoriteNewspaper(String id);

  /// Get all favorite newspapers.
  Future<Either<AppFailure, List<Map<String, dynamic>>>> getFavoriteNewspapers();
  
  /// Sync favorites with cloud.
  Future<Either<AppFailure, void>> syncFavorites();
}
