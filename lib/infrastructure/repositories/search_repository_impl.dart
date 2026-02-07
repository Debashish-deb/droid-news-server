import '../../core/architecture/either.dart';
import '../../core/architecture/failure.dart';
import '../../domain/entities/news_article.dart';
import '../../domain/repositories/search_repository.dart';
import '../../domain/repositories/news_repository.dart';
import '../../domain/repositories/settings_repository.dart';

import 'package:injectable/injectable.dart';

@LazySingleton(as: SearchRepository)
class SearchRepositoryImpl implements SearchRepository {

  SearchRepositoryImpl(this._newsRepository, this._settingsRepository);
  final NewsRepository _newsRepository;
  final SettingsRepository _settingsRepository;

  @override
  Future<Either<AppFailure, List<NewsArticle>>> searchArticles(String query) {
    return _newsRepository.searchArticles(query: query);
  }

  @override
  Future<Either<AppFailure, List<String>>> getRecentSearches() {
    return _settingsRepository.getRecentSearches();
  }

  @override
  Future<Either<AppFailure, void>> saveRecentSearch(String query) {
    return _settingsRepository.saveRecentSearch(query);
  }

  @override
  Future<Either<AppFailure, void>> clearRecentSearches() {
    // For now, we don't have a clear single method, but we can implement it in settings_repo if needed.
    // Stubbing for now or implementing if necessary.
    return Future.value(const Right(null));
  }
}
