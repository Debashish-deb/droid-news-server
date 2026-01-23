import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../data/models/news_article.dart';

class HorizontalSlider extends StatelessWidget {
  const HorizontalSlider({
    required this.title,
    required this.articles,
    required this.onTap,
    super.key,
  });
  final String title;
  final List<NewsArticle> articles;
  final void Function(NewsArticle article) onTap;

  static const List<Color> _fallbackGradient = <Color>[
    Color(0xFF141E30),
    Color(0xFF243B55),
  ];

  @override
  Widget build(BuildContext context) {
    if (articles.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(
          height: 115,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            scrollDirection: Axis.horizontal,
            itemCount: articles.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, int i) {
              final NewsArticle article = articles[i];
              final String? img = article.imageUrl;

              return InkWell(
                onTap: () => onTap(article),
                child: Container(
                  width: 280,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.15)),
                  ),
                  padding: const EdgeInsets.all(6),
                  child: Row(
                    children: <Widget>[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child:
                            img == null || img.isEmpty
                                ? Container(
                                  width: 85,
                                  height: 85,
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: _fallbackGradient,
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.newspaper,
                                    color: Colors.white70,
                                    size: 32,
                                  ),
                                )
                                : CachedNetworkImage(
                                  imageUrl: img,
                                  memCacheWidth: 255,
                                  memCacheHeight: 255,
                                  width: 85,
                                  height: 85,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Container(
                                    width: 85,
                                    height: 85,
                                    color: Colors.white.withOpacity(0.05),
                                    child: const Center(
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  ),
                                  errorWidget:
                                      (_, __, ___) => Container(
                                        width: 85,
                                        height: 85,
                                        decoration: const BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: _fallbackGradient,
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.newspaper,
                                          color: Colors.white70,
                                          size: 32,
                                        ),
                                      ),
                                ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          article.title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
