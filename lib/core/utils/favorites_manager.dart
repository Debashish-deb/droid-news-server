// lib/core/utils/favorites_manager.dart

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/news_article.dart';

class FavoritesManager {
  static final FavoritesManager _instance = FavoritesManager._internal();
  FavoritesManager._internal();
  static FavoritesManager get instance => _instance;

  static const String favoritesKey = 'favorites';
  static const String magazineFavoritesKey = 'magazine_favorites';
  static const String newspaperFavoritesKey = 'newspaper_favorites';

  List<NewsArticle> _favoriteArticles = [];
  List<Map<String, dynamic>> _favoriteMagazines = [];
  List<Map<String, dynamic>> _favoriteNewspapers = [];

  List<NewsArticle> get favoriteArticles => _favoriteArticles;
  List<Map<String, dynamic>> get favoriteMagazines => _favoriteMagazines;
  List<Map<String, dynamic>> get favoriteNewspapers => _favoriteNewspapers;

  Future<void> loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final articleJson       = prefs.getStringList(favoritesKey) ?? [];
    final magazineJson      = prefs.getStringList(magazineFavoritesKey) ?? [];
    final newspaperJson     = prefs.getStringList(newspaperFavoritesKey) ?? [];

    _favoriteArticles = articleJson
        .map((str) => NewsArticle.fromMap(json.decode(str)))
        .toList();

    _favoriteMagazines = magazineJson
        .map((str) => Map<String, dynamic>.from(json.decode(str)))
        .toList();

    _favoriteNewspapers = newspaperJson
        .map((str) => Map<String, dynamic>.from(json.decode(str)))
        .toList();
  }

  // -------------------------
  // Articles

  Future<void> addFavorite(NewsArticle article) async {
    final prefs = await SharedPreferences.getInstance();
    _favoriteArticles.add(article);
    await prefs.setStringList(
      favoritesKey,
      _favoriteArticles.map((e) => json.encode(e.toMap())).toList(),
    );
  }

  Future<void> removeFavorite(NewsArticle article) async {
    final prefs = await SharedPreferences.getInstance();
    _favoriteArticles.removeWhere((e) => e.url == article.url);
    await prefs.setStringList(
      favoritesKey,
      _favoriteArticles.map((e) => json.encode(e.toMap())).toList(),
    );
  }

  /// Toggle article in favorites (add if missing, remove if already favorited)
  Future<void> toggleArticle(NewsArticle article) async {
    final prefs = await SharedPreferences.getInstance();
    final exists = _favoriteArticles.any((e) => e.url == article.url);
    if (exists) {
      _favoriteArticles.removeWhere((e) => e.url == article.url);
    } else {
      _favoriteArticles.add(article);
    }
    await prefs.setStringList(
      favoritesKey,
      _favoriteArticles.map((e) => json.encode(e.toMap())).toList(),
    );
  }

  /// Check synchronously if an article is favorited
  bool isFavoriteArticle(NewsArticle article) {
    return _favoriteArticles.any((e) => e.url == article.url);
  }

  // -------------------------
  // Magazines

  Future<void> toggleMagazine(Map<String, dynamic> magazine) async {
    final prefs = await SharedPreferences.getInstance();
    final id     = magazine['id'].toString();
    final isFav  = _favoriteMagazines.any((m) => m['id'].toString() == id);

    if (isFav) {
      _favoriteMagazines.removeWhere((m) => m['id'].toString() == id);
    } else {
      _favoriteMagazines.add(magazine);
    }

    await prefs.setStringList(
      magazineFavoritesKey,
      _favoriteMagazines.map((m) => json.encode(m)).toList(),
    );
  }

  bool isFavoriteMagazine(String id) {
    return _favoriteMagazines.any((m) => m['id'].toString() == id);
  }

  // -------------------------
  // Newspapers

  Future<void> toggleNewspaper(Map<String, dynamic> newspaper) async {
    final prefs = await SharedPreferences.getInstance();
    final id     = newspaper['id'].toString();
    final isFav  = _favoriteNewspapers.any((n) => n['id'].toString() == id);

    if (isFav) {
      _favoriteNewspapers.removeWhere((n) => n['id'].toString() == id);
    } else {
      _favoriteNewspapers.add(newspaper);
    }

    await prefs.setStringList(
      newspaperFavoritesKey,
      _favoriteNewspapers.map((n) => json.encode(n)).toList(),
    );
  }

  bool isFavoriteNewspaper(String id) {
    return _favoriteNewspapers.any((n) => n['id'].toString() == id);
  }

  toggleArticleMap(Map<String, dynamic> item) {}
}
