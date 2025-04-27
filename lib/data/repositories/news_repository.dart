// lib/data/repositories/news_repository.dart

import '../services/news_service.dart';
import '../models/news_article.dart';

class NewsRepository {
  factory NewsRepository() => _instance;
  NewsRepository._internal();
  static final NewsRepository _instance = NewsRepository._internal();

  final NewsService _newsService = NewsService();

  /// ✅ Fetch latest news from RSS feeds
  Future<List<NewsArticle>> fetchLatestNews() async {
    return await _newsService.fetchLatestNews();
  }

  /// ✅ Fetch national news from RSS feeds
  Future<List<NewsArticle>> fetchNationalNews() async {
    return await _newsService.fetchNationalNews();
  }

  /// ✅ Fetch trending news from RSS feeds
  Future<List<NewsArticle>> fetchTrendingNews() async {
    return await _newsService.fetchTrendingNews();
  }

  /// ✅ Fetch technology news from RSS feeds
  Future<List<NewsArticle>> fetchTechNews() async {
    return await _newsService.fetchTechNews();
  }

  /// ✅ Fetch sports news from RSS feeds
  Future<List<NewsArticle>> fetchSportsNews() async {
    return await _newsService.fetchSportsNews();
  }

  /// ✅ Fetch entertainment news from RSS feeds
  Future<List<NewsArticle>> fetchEntertainmentNews() async {
    return await _newsService.fetchEntertainmentNews();
  }

  /// ✅ Fetch health news from RSS feeds
  Future<List<NewsArticle>> fetchHealthNews() async {
    return await _newsService.fetchHealthNews();
  }
}
