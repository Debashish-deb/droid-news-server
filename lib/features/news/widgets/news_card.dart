// lib/features/news/widgets/news_card.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

class NewsCard extends StatelessWidget {
  final Map<String, dynamic> news;
  final String searchQuery;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;

  const NewsCard({
    super.key,
    required this.news,
    required this.searchQuery,
    required this.isFavorite,
    required this.onFavoriteToggle,
  });

  void _open(BuildContext context) {
    // Try both fields: contact.website or top-level url / link
    final dynamic maybeWebsite = news['contact']?['website'];
    final dynamic maybeUrl     = news['url'] ?? news['link'];
    final String url = (maybeWebsite is String && maybeWebsite.isNotEmpty)
        ? maybeWebsite
        : (maybeUrl is String ? maybeUrl : '');

    final String title = news['name'] ?? 'News';

    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No URL available')),
      );
      return;
    }

    // Push the WebView route, passing URL + title as extra
    context.push(
      '/webview',
      extra: <String, String>{ 'url': url, 'title': title },
    );
  }

  String _getDescription() {
    final desc    = news['description'] ?? '';
    if (desc.toString().trim().isNotEmpty) return desc;
    final country = news['country'] ?? '';
    final lang    = news['language'] ?? '';
    return '$country • $lang';
  }

  String _getImageUrl() {
    final website = (news['contact']?['website'] ?? news['url'] ?? '') as String;
    if (website.isNotEmpty) {
      try {
        final uri = Uri.parse(website);
        return 'https://logo.clearbit.com/${uri.host}';
      } catch (_) {}
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final theme   = Theme.of(context);
    final isDark  = theme.brightness == Brightness.dark;
    final glowCol = theme.colorScheme.primary.withOpacity(isDark ? 0.1 : 0.4);

    final String logoUrl     = _getImageUrl();
    final String fallbackTxt = (news['name']?.substring(0,2).toUpperCase() ?? 'NP');
    final String name        = news['name'] ?? 'Untitled';
    final String description = _getDescription();

    return InkWell(
      onTap: () => _open(context),
      child: Card(
        elevation: 6,
        margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        color: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        shadowColor: glowCol,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(color: glowCol, blurRadius: 8, offset: const Offset(0,4)),
            ],
          ),
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
                          placeholder: (_,__) => const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          errorWidget: (_,__,___) => _fallbackAvatar(fallbackTxt),
                        )
                      : _fallbackAvatar(fallbackTxt),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: isFavorite ? Colors.red : Colors.grey,
                  ),
                  onPressed: onFavoriteToggle,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Fallback when no logo URL
  Widget _fallbackAvatar(String text) {
    return Container(
      width: 55,
      height: 55,
      color: Colors.grey[300],
      alignment: Alignment.center,
      child: Text(
        text,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }
}
