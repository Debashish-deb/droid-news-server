// lib/features/movies/movie_detail_screen.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme_provider.dart';
import '../../core/theme.dart';

import 'movie.dart';

class MovieDetailScreen extends StatelessWidget {
  final Movie movie;
  const MovieDetailScreen({Key? key, required this.movie}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final router = GoRouter.of(context);
    final gradient = AppGradients.getGradientColors(context.read<ThemeProvider>().appThemeMode);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      body: Stack(fit: StackFit.expand, children: [
        Container(color: scheme.background),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(color: Colors.black.withOpacity(0.3)),
          ),
        ),
        CustomScrollView(slivers: [
          SliverAppBar(
            backgroundColor: Colors.transparent,
            pinned: true,
            expandedHeight: 300,
            elevation: 0,
            leading: Padding(
              padding: const EdgeInsets.only(left: 12, top: 12),
              child: Material(
                color: scheme.surface.withOpacity(0.3),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: IconButton(
                  icon: Icon(Icons.arrow_back, color: scheme.onPrimary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12, top: 12),
                child: Material(
                  color: scheme.surface.withOpacity(0.3),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: IconButton(
                    icon: Icon(Icons.refresh, color: scheme.onPrimary),
                    onPressed: () => router.go('/movies/${movie.id}', extra: movie),
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                movie.title,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: scheme.onPrimary,
                  shadows: const [Shadow(blurRadius: 4, color: Colors.black54)],
                ),
              ),
              background: Stack(fit: StackFit.expand, children: [
                movie.backdropPath.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: 'https://image.tmdb.org/t/p/w500${movie.backdropPath}',
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => const Icon(Icons.broken_image),
                        placeholder: (_, __) => const Center(child: CircularProgressIndicator()),
                      )
                    : const Center(child: Icon(Icons.image_not_supported)),
                Container(color: Colors.black45),
              ]),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Center(
                  child: RatingBarIndicator(
                    rating: movie.voteAverage / 2,
                    itemCount: 5,
                    itemSize: 36,
                    itemBuilder: (_, __) => Icon(Icons.star, color: scheme.secondary),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Release Date: ${movie.releaseDate}', style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurface)),
                const SizedBox(height: 12),
                Text('Genres: ${movie.genreIds.join(', ')}', style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurface)),
                const SizedBox(height: 20),
                Text(movie.overview, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onPrimary)),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ]),
      ]),
    );
  }
}
