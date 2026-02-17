import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../core/config/app_config.dart';
import '../../domain/entities/news_article.dart';
import '../../core/telemetry/structured_logger.dart';


class NewsApiService {
  NewsApiService(this._client, this._logger);

  final http.Client _client;
  final StructuredLogger _logger;

  Future<List<NewsArticle>> fetchFromNewsData({
    required String category,
    String language = 'en',
  }) async {
    try {
      final String apiKey = AppConfig.newsDataApiKey;
      if (apiKey.isEmpty || apiKey == 'pub_YOUR_KEY') return [];

      // Map our categories to newsdata.io categories
      String apiCategory;
      switch (category) {
        case 'latest':
          apiCategory = 'top';
          break;
        case 'national':
          apiCategory = 'politics'; // Best match for national news
          break;
        case 'international':
          apiCategory = 'world';
          break;
        case 'business':
        case 'economy':
          apiCategory = 'business';
          break;
        case 'sports':
        case 'entertainment':
        case 'technology':
        case 'science':
        case 'health':
          apiCategory = category;
          break;
        default:
          apiCategory = 'top';
      }

      final uri = Uri.parse(
        'https://newsdata.io/api/1/news?apikey=$apiKey&category=$apiCategory&language=$language&country=bd',
      );

      final response = await _client.get(uri);
      if (response.statusCode != 200) {
        _logger.warn('NewsData API returned ${response.statusCode}');
        return [];
      }

      final data = jsonDecode(response.body);
      final List results = data['results'] ?? [];

      return results.map((json) {
        return NewsArticle(
          title: json['title'] ?? '',
          description: json['description'] ?? '',
          url: json['link'] ?? '',
          source: json['source_id'] ?? 'NewsData',
          imageUrl: json['image_url'],
          language: language,
          publishedAt: DateTime.tryParse(json['pubDate'] ?? '') ?? DateTime.now(),
        );
      }).toList();
    } catch (e) {
      _logger.error('Error fetching from NewsData', e);
      return [];
    }
  }

  Future<List<NewsArticle>> fetchFromGNews({
    required String category,
    String language = 'en',
    String country = 'bd',
  }) async {
    try {
      final String apiKey = AppConfig.gNewsApiKey;
      if (apiKey.isEmpty) return [];

      // Map categories to GNews topics
      String? apiTopic;
      switch (category) {
        case 'national':
          apiTopic = 'nation';
          break;
        case 'international':
          apiTopic = 'world';
          break;
        case 'sports':
          apiTopic = 'sports';
          break;
        case 'technology':
          apiTopic = 'technology';
          break;
        case 'entertainment':
          apiTopic = 'entertainment';
          break;
        case 'business':
        case 'economy':
          apiTopic = 'business';
          break;
        case 'science':
          apiTopic = 'science';
          break;
        case 'health':
          apiTopic = 'health';
          break;
        default:
          // For 'latest' or unknown, we don't specify a topic to get all top headlines
          apiTopic = null;
      }

      final String baseUrl = 'https://gnews.io/api/v4/top-headlines?token=$apiKey&lang=$language';
      final Uri uri;
      
      if (apiTopic != null) {
        // Topic and Country/Q are mutually exclusive in GNews API
        uri = Uri.parse('$baseUrl&topic=$apiTopic');
      } else {
        // If no topic (latest/national), use country to get local top headlines
        uri = Uri.parse('$baseUrl&country=$country');
      }

      final response = await _client.get(uri);
      if (response.statusCode != 200) {
        _logger.warn('GNews API returned ${response.statusCode} for topic: $apiTopic');
        return [];
      }

      final data = jsonDecode(response.body);
      final List articles = data['articles'] ?? [];

      return articles.map((json) {
        return NewsArticle(
          title: json['title'] ?? '',
          description: json['description'] ?? '',
          url: json['url'] ?? '',
          source: json['source']?['name'] ?? 'GNews',
          imageUrl: json['image'],
          language: language,
          publishedAt: DateTime.tryParse(json['publishedAt'] ?? '') ?? DateTime.now(),
        );
      }).toList();
    } catch (e) {
      _logger.error('Error fetching from GNews', e);
      return [];
    }
  }
}
