class Movie {
  final int id;
  final String title;
  final String overview;
  final String posterPath;
  final String backdropPath;
  final double voteAverage;
  final String releaseDate;
  final List<int> genreIds;
  final String originalLanguage;
  final double popularity;

  Movie({
    required this.id,
    required this.title,
    required this.overview,
    required this.posterPath,
    required this.backdropPath,
    required this.voteAverage,
    required this.releaseDate,
    required this.genreIds,
    required this.originalLanguage,
    required this.popularity,
  });

  static const String _tmdbImageBase = 'https://image.tmdb.org/t/p/w500';

  String? get posterUrl {
    if (posterPath.isEmpty) return null;
    return '$_tmdbImageBase$posterPath';
  }

  String? get backdropUrl {
    if (backdropPath.isEmpty) return null;
    return '$_tmdbImageBase$backdropPath';
  }

  factory Movie.fromJson(Map<String, dynamic> json) {
    return Movie(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      overview: json['overview'] as String? ?? '',
      posterPath: json['poster_path'] as String? ?? '',
      backdropPath: json['backdrop_path'] as String? ?? '',
      voteAverage: (json['vote_average'] as num).toDouble(),
      releaseDate: json['release_date'] as String? ?? '',
      genreIds: List<int>.from(json['genre_ids'] as List<dynamic>? ?? []),
      originalLanguage: json['original_language'] as String? ?? '',
      popularity: (json['popularity'] as num).toDouble(),
    );
  }
}
