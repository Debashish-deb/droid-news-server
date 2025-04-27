import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

class MagazineCard extends StatelessWidget {
  const MagazineCard({
    required this.magazine,
    required this.isFavorite,
    required this.onFavoriteToggle,
    super.key,
  });

  final Map<String, dynamic> magazine;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;

  void _openMagazine(BuildContext context) {
    final String url = magazine['contact']?['website'] ?? '';
    final String title = magazine['name'] ?? 'Magazine';

    final Uri? parsed = Uri.tryParse(url);
    if (parsed == null || !(parsed.scheme == 'http' || parsed.scheme == 'https')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid or missing website URL')),
      );
      return;
    }

    context.pushNamed('webview', extra: {'url': url, 'title': title});
  }

  String _getDescription() {
    final String desc = magazine['description'] ?? '';
    if (desc.isNotEmpty) return desc;
    final String country = magazine['country'] ?? 'Unknown Country';
    final String language = magazine['language'] ?? 'Unknown Language';
    return '$country • $language';
  }

  String _getLogoUrl() {
    final String? website = magazine['contact']?['website'] as String?;
    if (website != null && website.isNotEmpty) {
      try {
        final host = Uri.parse(website).host;
        return 'https://logo.clearbit.com/$host';
      } catch (_) {}
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final glowColor = theme.colorScheme.primary.withOpacity(isDark ? 0.1 : 0.4);

    final String logoUrl = _getLogoUrl();
    final String name = magazine['name'] ?? 'Unknown Magazine';
    final String description = _getDescription();
    final String fallbackText = (magazine['name'] as String?)?.substring(0, 2).toUpperCase() ?? 'MG';

    return InkWell(
      onTap: () => _openMagazine(context),
      child: Card(
        elevation: 6,
        margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        color: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        shadowColor: glowColor,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: glowColor,
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: CachedNetworkImage(
                    imageUrl: logoUrl,
                    width: 55,
                    height: 55,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Image.asset(
                      isDark
                          ? 'assets/imageplaceHolder_dark.png'
                          : 'assets/imageplaceHolder.png',
                      width: 55,
                      height: 55,
                      fit: BoxFit.cover,
                    ),
                  ),
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
                    color: isFavorite ? Colors.redAccent : Colors.grey,
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
}
