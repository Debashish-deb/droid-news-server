import '../../core/architecture/either.dart';
import '../../core/architecture/failure.dart';
import '../entities/news_article.dart';

abstract class SearchRepository {
  Future<Either<AppFailure, List<NewsArticle>>> searchArticles(String query);
  Future<Either<AppFailure, List<String>>> getRecentSearches();
  Future<Either<AppFailure, void>> saveRecentSearch(String query);
  Future<Either<AppFailure, void>> clearRecentSearches();
}
