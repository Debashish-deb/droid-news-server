// lib/features/news/widgets/news_card.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '/data/models/news_article.dart';

class NewsCard extends StatelessWidget {
  const NewsCard({
    super.key,
    required this.article,
    this.isFavorite = false,
    this.onFavoriteToggle,
  });

  final NewsArticle article;
  final bool isFavorite;
  final VoidCallback? onFavoriteToggle;

  void _open(BuildContext context) {
    final url = article.url ?? '';
    final title = article.title ?? 'News';

    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No URL available')),
      );
      return;
    }

    try {
      context.pushNamed('webview', extra: {'url': url, 'title': title});
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to open URL')),
      );
    }
  }

  void _share(BuildContext context) {
    final url = article.url ?? '';
    if (url.isNotEmpty) {
      Share.share(url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing to share')),
      );
    }
  }

  bool _isBanglaNews() {
    final lang = article.language ?? '';
    return lang.toLowerCase().contains('bn');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final glowColor = theme.colorScheme.primary.withOpacity(isDark ? 0.1 : 0.4);
    final String logoUrl = article.imageUrl ?? '';
    final String name = article.title ?? 'Untitled';

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF2C2C2C).withOpacity(0.4)
                : Colors.white.withOpacity(0.5),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.black12,
              width: 1.2,
            ),
          ),
          margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Card(
            color: Colors.transparent,
            elevation: 0,
            shadowColor: glowColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => _open(context),
              splashColor: theme.colorScheme.primary.withOpacity(0.2),
              highlightColor: theme.colorScheme.primary.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: logoUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: logoUrl,
                              width: 55,
                              height: 55,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Image.asset(
                                'assets/icons/app-icon.png',
                                width: 55,
                                height: 55,
                                fit: BoxFit.cover,
                              ),
                              errorWidget: (_, __, ___) => Image.asset(
                                'assets/icons/app-icon.png',
                                width: 55,
                                height: 55,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Image.asset(
                              'assets/icons/app-icon.png',
                              width: 55,
                              height: 55,
                              fit: BoxFit.cover,
                            ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (_isBanglaNews())
                                const Padding(
                                  padding: EdgeInsets.only(left: 4.0),
                                  child: Icon(Icons.flag, size: 16, color: Colors.green),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (onFavoriteToggle != null)
                          IconButton(
                            icon: Icon(
                              isFavorite ? Icons.favorite : Icons.favorite_border,
                              color: isFavorite ? Colors.red : Colors.grey,
                            ),
                            onPressed: onFavoriteToggle,
                          ),
                        IconButton(
                          icon: const Icon(Icons.share, color: Colors.blueGrey),
                          onPressed: () => _share(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
