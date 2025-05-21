// lib/features/movies/recommendation_service.dart

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'movie.dart';

class RecommendationService {
  RecommendationService._();
  static final RecommendationService instance = RecommendationService._();

  static const _genreScoresKey = 'genreScores';
  Map<int, double> _genreScores = {};

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_genreScoresKey);
    if (jsonStr != null) {
      final Map<String, dynamic> m = jsonDecode(jsonStr);
      _genreScores =
          m.map((k, v) => MapEntry(int.parse(k), v as double));
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _genreScoresKey,
      jsonEncode(_genreScores.map((k, v) => MapEntry(k.toString(), v))),
    );
  }

  Future<void> recordInteraction(Movie movie) async {
    await load();
    for (var g in movie.genreIds) {
      _genreScores[g] = (_genreScores[g] ?? 0) + 1.0;
    }
    await _save();
  }

  /// Returns a NEW list of movies sorted by (TMDB rating * 0.7 + affinity * 0.3).
  Future<List<Movie>> personalize(List<Movie> movies) async {
    await load();
    // find max genre score
    final maxScore = _genreScores.values.fold<double>(
        0.0, (prev, e) => e > prev ? e : prev);

    // build scored list
    final entries = <MapEntry<Movie, double>>[];
    for (var m in movies) {
      final affinity = m.genreIds
          .fold<double>(0.0, (sum, g) => sum + (_genreScores[g] ?? 0));
      final norm = maxScore > 0 ? (affinity / maxScore) : 0.0;
      final finalScore = m.voteAverage * 0.7 + norm * 5.0 * 0.3;
      entries.add(MapEntry(m, finalScore));
    }

    entries.sort((a, b) => b.value.compareTo(a.value));
    // return only the Movie objects, in sorted order
    return entries.map((e) => e.key).toList();
  }
}
