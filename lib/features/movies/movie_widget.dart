// File: lib/features/movies/movie_widget.dart

import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as https;
import 'package:provider/provider.dart';

import 'movie.dart';
import 'recommendation_service.dart';
import '../../core/theme_provider.dart';
import '../../core/theme.dart';

class MovieWidget extends StatelessWidget {
  final double height;
  const MovieWidget({Key? key, required this.height}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: ElevatedButton.icon(
        icon: Icon(Icons.movie, color: scheme.onPrimary),
        label: Text(
          "Open CineSpot",
          style: theme.textTheme.labelLarge
              ?.copyWith(color: scheme.onPrimary),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.surface.withOpacity(0.6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: scheme.primary, width: 2),
          ),
          shadowColor: scheme.primary.withOpacity(0.7),
          elevation: 8,
        ),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => const FullScreenMoviePage(),
          ),
        ),
      ),
    );
  }
}

class FullScreenMoviePage extends StatefulWidget {
  const FullScreenMoviePage({Key? key}) : super(key: key);

  @override
  State<FullScreenMoviePage> createState() => _FullScreenMoviePageState();
}

class _FullScreenMoviePageState extends State<FullScreenMoviePage>
    with TickerProviderStateMixin {
  late final TabController _langCtrl, _catCtrl;
  final _langs = ['All', 'English', 'Bangla', 'Hindi'];
  final _langCodes = [null, 'en', 'bn', 'hi'];
  final _cats = ['Trending', 'Discover', ];
  final _apiCats = ['popular', 'discover', 'now_playing'];
  final Set<int> _favoriteIds = {};

  @override
  void initState() {
    super.initState();
    _langCtrl = TabController(length: _langs.length, vsync: this);
    _catCtrl = TabController(length: _cats.length, vsync: this);
  }

  @override
  void dispose() {
    _langCtrl.dispose();
    _catCtrl.dispose();
    super.dispose();
  }

  /// Fetches movies from TMDB, with robust error handling.
  Future<List<Movie>> _fetch(String apiCat, String? langCode) async {
    const apiKey = 'e2999b9d149f7847e3c467822ccbc1a7';
    final today = DateTime.now().toIso8601String().split('T')[0];

    final uri = Uri.https('api.themoviedb.org', 
      apiCat == 'popular'
        ? '/3/discover/movie'
        : '/3/movie/$apiCat',
      {
        'api_key': apiKey,
        'language': 'en-US',
        if (langCode != null) 'with_original_language': langCode,
        if (apiCat == 'popular') 'sort_by': 'popularity.desc',
        if (apiCat == 'upcoming') 'primary_release_date.gte': today,
      },
    );

    try {
      // 10s timeout to avoid hanging indefinitely
      final response = await https.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        throw Exception(
            'TMDB error ${response.statusCode}: ${response.reasonPhrase}');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw FormatException('Expected JSON object');
      }

      final results = decoded['results'];
      if (results is! List) {
        throw FormatException('Missing "results" list');
      }

      // Build movie list, skipping any invalid entries
      List<Movie> movies = results
          .where((e) => e is Map<String, dynamic>)
          .map<Movie>((e) => Movie.fromJson(e as Map<String, dynamic>))
          .toList();

      // Personalize only the popular category
      if (apiCat == 'popular' && langCode == null) {
        try {
          movies =
              await RecommendationService.instance.personalize(movies);
        } catch (e) {
          // if personalization fails, use unmodified list
          
        }
      }

      return movies;
    } on TimeoutException catch (e) {
      return [];
    } on FormatException catch (e) {
      return [];
    } catch (e) {
      return [];
    }
  }

  Widget _neonButton(IconData icon, VoidCallback onTap, Color color) =>
      Material(
        color: color.withOpacity(0.6),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child:
                Icon(icon, color: Theme.of(context).colorScheme.onPrimary),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final gradientColors = AppGradients.getGradientColors(
        context.read<ThemeProvider>().appThemeMode);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 12),
              Text("CineSpot 🎬",
                  style: theme.textTheme.headlineSmall),
              TabBar(
                controller: _langCtrl,
                isScrollable: true,
                indicatorColor: scheme.primary,
                labelColor: scheme.onPrimary,
                unselectedLabelColor: scheme.onSurface,
                tabs: _langs.map((l) => Tab(text: l)).toList(),
              ),
              TabBar(
                controller: _catCtrl,
                indicatorColor: scheme.primary,
                labelColor: scheme.onPrimary,
                unselectedLabelColor: scheme.onSurface,
                tabs: _cats.map((c) => Tab(text: c)).toList(),
              ),
              Expanded(
                child: TabBarView(
                  controller: _langCtrl,
                  children: _langs.map((lang) {
                    return TabBarView(
                      controller: _catCtrl,
                      children: _apiCats.map((cat) {
                        final langIndex = _langs.indexOf(lang);
                        return FutureBuilder<List<Movie>>(
                          future: _fetch(cat, _langCodes[langIndex]),
                          builder: (ctx, snap) {
                            if (snap.connectionState ==
                                ConnectionState.waiting) {
                              return Center(
                                  child: CircularProgressIndicator(
                                      color: scheme.primary));
                            }
                            if (snap.hasError) {
                              return Center(
                                child: Text(
                                  'Error: ${snap.error}',
                                  style: theme.textTheme.bodyMedium
                                      ?.copyWith(color: scheme.error),
                                ),
                              );
                            }
                            final movies = snap.data!;
                            if (movies.isEmpty) {
                              return Center(
                                  child: Text('No movies',
                                      style: theme.textTheme.bodyMedium));
                            }

                            final cols =
                                MediaQuery.of(ctx).size.width > 600 ? 3 : 2;
                            return Padding(
                              padding: const EdgeInsets.all(12),
                              child: GridView.builder(
                                itemCount: movies.length,
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: cols,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 0.65,
                                ),
                                itemBuilder: (ctx, i) => _MovieCard(
                                  movie: movies[i],
                                  rank: i + 1,
                                  isFavorite:
                                      _favoriteIds.contains(movies[i].id),
                                  onToggleFavorite: () => setState(() {
                                    final id = movies[i].id;
                                    _favoriteIds.contains(id)
                                        ? _favoriteIds.remove(id)
                                        : _favoriteIds.add(id);
                                  }),
                                ),
                              ),
                            );
                          },
                        );
                      }).toList(),
                    );
                  }).toList(),
                ),
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _neonButton(
                        Icons.close, () => Navigator.of(context).pop(),
                        scheme.secondary),
                    _neonButton(
                        Icons.refresh, () => setState(() {}),
                        scheme.secondary),
                    _neonButton(
                        Icons.search,
                        () => showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: Text("Search",
                                    style:
                                        theme.textTheme.titleMedium),
                                content: Text(
                                    "Search feature not implemented.",
                                    style:
                                        theme.textTheme.bodyMedium),
                                actions: [
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context),
                                      child: const Text("OK"))
                                ],
                              ),
                            ),
                        scheme.secondary),
                    _neonButton(
                        Icons.star,
                        () => showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: Text("Favorites",
                                    style:
                                        theme.textTheme.titleMedium),
                                content: Text(
                                    "Favorites: ${_favoriteIds.length} selected",
                                    style:
                                        theme.textTheme.bodyMedium),
                                actions: [
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context),
                                      child: const Text("OK"))
                                ],
                              ),
                            ),
                        scheme.secondary),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}

class _MovieCard extends StatelessWidget {
  final Movie movie;
  final int rank;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;

  const _MovieCard({
    Key? key,
    required this.movie,
    required this.rank,
    required this.isFavorite,
    required this.onToggleFavorite,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.all(6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: scheme.surface.withOpacity(0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.primary, width: 2),
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withOpacity(0.4),
                blurRadius: 16,
                spreadRadius: 4,
              ),
            ],
          ),
          child: InkWell(
            onTap: () => context.push('/movies/${movie.id}', extra: movie),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: Icon(
                      isFavorite ? Icons.star : Icons.star_border,
                      color: isFavorite
                          ? Colors.amber
                          : scheme.onSurface,
                      size: 20,
                    ),
                    onPressed: onToggleFavorite,
                  ),
                ),
                Expanded(
                  child: movie.posterPath?.isNotEmpty == true
                      ? CachedNetworkImage(
                          imageUrl:
                              'https://image.tmdb.org/t/p/w500${movie.posterPath}',
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              const Icon(Icons.broken_image),
                          placeholder: (_, __) =>
                              const Center(child: CircularProgressIndicator()),
                        )
                      : const Center(
                          child:
                              Icon(Icons.image_not_supported)),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: scheme.surface.withOpacity(0.6),
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(16)),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        movie.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(color: scheme.primary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        movie.releaseDate,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(
                                color: scheme.onSurface
                                    .withOpacity(0.8)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
