// File: lib/features/movies/movie_service.dart

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'movie.dart';

class _CacheEntry {
  final List<Movie> movies;
  final DateTime fetchedAt;
  _CacheEntry(this.movies) : fetchedAt = DateTime.now();
}
class MovieService {
  MovieService._() {
    final key = dotenv.env['TMDB_API_KEY']!;
    _dio = Dio(BaseOptions(
      baseUrl: 'https://api.themoviedb.org/3/',
      connectTimeout: const Duration(seconds: 6),
      receiveTimeout: const Duration(seconds: 4),
      queryParameters: {'api_key': key},
    ));
  }

  static final MovieService instance = MovieService._();
  late final Dio _dio;
  static const Duration _refreshInterval = Duration(minutes: 15);
  final Map<String, _CacheEntry> _cache = {};

  
  static const Map<String, String> langCodes = {
    'All': '',
    'English': 'en',
    'Hindi': 'hi',
    'Bangla': 'bn',
  };

  Future<List<Movie>> fetchMovies({
    required String category,
    String language = 'All',
    List<int>? genreIds,
    double? minRating,
    int? minVoteCount,
    bool includeAdult = false,
    String region = 'US',
    int page = 1,
    bool forceRefresh = false,
  }) async {
    // Build cache key
    final cacheKey = [
      category,
      language,
      genreIds?.join(','),
      minRating,
      minVoteCount,
      includeAdult,
      region,
      page
    ].map((e) => e?.toString() ?? '').join('|');

    final entry = _cache[cacheKey];
    if (!forceRefresh && entry != null) {
      if (DateTime.now().difference(entry.fetchedAt) < _refreshInterval) {
        return entry.movies;
      }
    }

    // endpoint and params
    String endpoint;
    final params = <String, dynamic>{
      'language': 'en-US',
      'page': page,
      'include_adult': includeAdult,
      'region': region,
    };

    // Map language for TMDB code
    final langParam = langCodes[language] ?? '';

    switch (category.toLowerCase()) {
      case 'trending':
        endpoint = 'trending/movie/week';
        break;

      case 'now_playing':
      case 'now playing':
        endpoint = 'discover/movie';
        params
          ..['sort_by'] = 'popularity.desc'
          ..['release_date.lte'] =
              DateTime.now().toIso8601String().split('T').first
          ..['release_date.gte'] =
              DateTime.now().subtract(const Duration(days: 30)).toIso8601String().split('T').first;
        if (langParam.isNotEmpty) {
          params['with_original_language'] = langParam;
        }
        break;

      case 'upcoming':
        endpoint = 'discover/movie';
        params
          ..['sort_by'] = 'release_date.asc'
          ..['primary_release_date.gte'] =
              DateTime.now().toIso8601String().split('T').first;
        if (langParam.isNotEmpty) {
          params['with_original_language'] = langParam;
        }
        break;

      case 'top_rated':
      case 'top rated':
        endpoint = 'movie/top_rated';
        break;

      case 'popular':
        endpoint = 'movie/popular';
        break;

      case 'box_office':
      case 'box office':
        endpoint = 'discover/movie';
        params['sort_by'] = 'revenue.desc';
        if (langParam.isNotEmpty) {
          params['with_original_language'] = langParam;
        }
        break;

      default:
        endpoint = 'discover/movie';
        params['sort_by'] = 'popularity.desc';
        if (langParam.isNotEmpty) {
          params['with_original_language'] = langParam;
        }
        break;
    }

    if (endpoint == 'discover/movie') {
      if (genreIds != null && genreIds.isNotEmpty) {
        params['with_genres'] = genreIds.join(',');
      }
      if (minRating != null) {
        params['vote_average.gte'] = minRating;
      }
      if (minVoteCount != null) {
        params['vote_count.gte'] = minVoteCount;
      }
    }

    try {
      final res = await _dio.get(endpoint, queryParameters: params);
      final results = res.data['results'] as List<dynamic>? ?? [];
      final movies =
          results.map((e) => Movie.fromJson(e as Map<String, dynamic>)).toList();
      _cache[cacheKey] = _CacheEntry(movies);
      return movies;
    } catch (e) {
      // On error, return stale data if available
      return entry?.movies ?? [];
    }
  }

  void clearCache({String? category, String? language, int? page}) {
    if (category == null) {
      _cache.clear();
    } else {
      final keyPattern =
          [category, language, page].map((e) => e?.toString() ?? '').join('|');
      _cache.remove(keyPattern);
    }
  }
}
