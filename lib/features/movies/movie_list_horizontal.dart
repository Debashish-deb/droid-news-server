// File: lib/features/movies/movie_list_horizontal.dart

import 'package:flutter/material.dart';
import 'movie.dart';

class MovieListHorizontal extends StatelessWidget {
  final List<Movie> movies;
  const MovieListHorizontal({Key? key, required this.movies}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (movies.isEmpty) {
      return const Center(child: Text("No movies"));
    }
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: movies.length,
      itemBuilder: (context, i) {
        final m = movies[i];
        return Container(
          width: 120,
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 2/3,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    m.posterUrl ?? '',
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => const Icon(Icons.broken_image),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                m.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              // Add more info if needed
            ],
          ),
        );
      },
    );
  }
}
