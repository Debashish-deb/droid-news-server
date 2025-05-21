import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../data/models/news_article.dart';

class NewsListWidget extends StatelessWidget {
  final List<NewsArticle> articles;
  final void Function(NewsArticle) onTap;
  final Future<void> Function() onRefresh; // Make refresh logic explicit and required

  const NewsListWidget({
    Key? key,
    required this.articles,
    required this.onTap,
    required this.onRefresh, // Now caller must provide real refresh logic
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (articles.isEmpty) {
      return const Center(
        child: Text('No articles available.', style: TextStyle(color: Colors.grey)),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        itemCount: articles.length,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 12),
        separatorBuilder: (_, __) => const Divider(height: 0),
        itemBuilder: (context, index) {
          final article = articles[index];
          final isCached = article.fromCache;
          final isFresh = DateTime.now().difference(article.publishedAt).inMinutes < 30;

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(
                imageUrl: article.imageUrl ?? '',
                placeholder: (context, url) => const SizedBox(
                  width: 56,
                  height: 56,
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                errorWidget: (context, url, error) => Container(
                  width: 56,
                  height: 56,
                  color: Colors.grey[200],
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image, size: 24),
                ),
                width: 56,
                height: 56,
                fit: BoxFit.cover,
              ),
            ),
            title: Text(
              article.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Row(
              children: [
                Expanded(
                  child: Text(
                    article.sourceOverride ?? article.source,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
                if (isFresh)
                  _badge('NEW', Colors.blueAccent)
                else if (isCached)
                  _badge('CACHED', Colors.grey),
              ],
            ),
            onTap: () => onTap(article),
          );
        },
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
