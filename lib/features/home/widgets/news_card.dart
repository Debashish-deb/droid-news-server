import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '/core/utils/source_logos.dart';
import '../../../data/models/news_article.dart';

class NewsCard extends StatelessWidget {
  final NewsArticle article;
  final VoidCallback? onTap;
  final bool highlight;
  const NewsCard({
  Key? key,
  required this.article,
  this.onTap,
  this.highlight = true,
}) : super(key: key);

  bool get isLive => article.isLive;
  bool get isBreaking => DateTime.now().difference(article.publishedAt) < const Duration(hours: 6);
  bool get isFresh => DateTime.now().difference(article.publishedAt) < const Duration(minutes: 30);
  bool get isCached => article.fromCache;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final logoPath = SourceLogos.logos[article.sourceOverride ?? article.source];
    final timestamp = DateFormat('hh:mm a').format(article.publishedAt);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Colors.white.withOpacity(0.08),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (article.imageUrl?.isNotEmpty ?? false)
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                    child: FadeInImage.assetNetwork(
                      placeholder: 'assets/placeholder.png',
                      image: article.imageUrl!,
                      width: double.infinity,
                      height: 180,
                      fit: BoxFit.cover,
                      imageErrorBuilder: (_, __, ___) => Container(
                        height: 180,
                        color: Colors.grey.shade300,
                        alignment: Alignment.center,
                        child: const Icon(Icons.image_not_supported, size: 36, color: Colors.grey),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                     Row(
  children: [
    if (logoPath != null)
      _glassLogo(logoPath)
    else
      const Icon(
        Icons.public,
        size: 24,
        color: Colors.deepPurpleAccent,
      ),
    const SizedBox(width: 10),
    Expanded(
      child: Text(
        article.sourceOverride ?? article.source,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ),
    if (isLive) _tag("LIVE ⚡", Colors.redAccent),
    if (!isLive && isBreaking) _tag("BREAKING 🔥", Colors.orangeAccent),
    if (!isLive && !isBreaking && isFresh) _tag("NEW", Colors.lightBlue),
    if (!isLive && !isBreaking && !isFresh && isCached) _tag("CACHED", Colors.grey),
  ],
),


                      const SizedBox(height: 10),

                      Text(
                        article.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),

                      if (article.snippet.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            article.snippet,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white70,
                              height: 1.4,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                      const SizedBox(height: 8),
                      Text(
                        timestamp,
                        style: theme.textTheme.labelSmall?.copyWith(color: Colors.white60),
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

  Widget _glassLogo(String path) {
    return Container(
      width: 36,
      height: 36,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.25),
            Colors.white.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withOpacity(0.25), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.asset(path, fit: BoxFit.contain),
      ),
    );
  }

  Widget _tag(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
