import '../../../domain/entities/news_article.dart';
import '../../../core/telemetry/structured_logger.dart';

class NewsApiService {
  NewsApiService(this._logger);

  final StructuredLogger _logger;

  Future<List<NewsArticle>> fetchFromNewsData({
    required String category,
    String language = 'en',
  }) async {
    // RSS is working perfectly; stubbing out API calls to reduce external pressure and costs.
    _logger.info('API Stub: fetchFromNewsData skipped');
    return [];
  }

  Future<List<NewsArticle>> fetchFromGNews({
    required String category,
    String language = 'en',
    String country = 'bd',
  }) async {
    // RSS is working perfectly; stubbing out API calls to reduce external pressure and costs.
    _logger.info('API Stub: fetchFromGNews skipped');
    return [];
  }
}
