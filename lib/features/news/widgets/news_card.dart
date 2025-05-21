// lib/features/news/widgets/news_card.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme_provider.dart';
import '../../../core/theme.dart';

class NewsCard extends StatefulWidget {
  final Map<String, dynamic> news;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;
  final bool highlight;
  final String searchQuery;

  const NewsCard({
    super.key,
    required this.news,
    required this.isFavorite,
    required this.onFavoriteToggle,
    this.highlight = true,
    required this.searchQuery,
  });

  @override
  State<NewsCard> createState() => _NewsCardState();
}

class _NewsCardState extends State<NewsCard> with SingleTickerProviderStateMixin {
  bool _isPressed = false;

  void _open(BuildContext context) {
    final maybeWebsite = widget.news['contact']?['website'];
    final maybeUrl = widget.news['url'] ?? widget.news['link'];
    final url = (maybeWebsite is String && maybeWebsite.isNotEmpty)
        ? maybeWebsite
        : (maybeUrl is String ? maybeUrl : '');

    final title = widget.news['name'] ?? 'News';

    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No URL available')),
      );
      return;
    }

    context.push('/webview', extra: {'url': url, 'title': title});
  }

  String? _getLocalLogoPath() {
    final id = widget.news['id']?.toString();
    return id != null ? 'assets/logos/$id.png' : null;
  }

  void _share() {
    final title = widget.news['name'] ?? 'Newspaper';
    final url = widget.news['url'] ?? widget.news['link'] ?? '';
    if (url is String && url.isNotEmpty) {
      Share.share('$title\n$url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mode = context.watch<ThemeProvider>().appThemeMode;
    final localLogoPath = _getLocalLogoPath();

    final isDark = mode == AppThemeMode.dark;
    final isDesh = mode.toString().toLowerCase().contains("desh");
    final fallbackText = (widget.news['name']?.toString().substring(0, 2).toUpperCase() ?? "NP");

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () => _open(context),
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: AspectRatio(
            aspectRatio: 3 / 1,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: isDark ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.02),
                border: Border.all(
                  color: Colors.white.withOpacity(0.08),
                  width: 1.2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withOpacity(0.08),
                              Colors.white.withOpacity(0.02),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (isDark || isDesh)
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white30,
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              center: Alignment.center,
                              radius: 0.5,
                              colors: [
                                Colors.white.withOpacity(isDark ? 0.25 : 0.1),
                                Colors.transparent,
                              ],
                            ),
                            boxShadow: widget.highlight && (isDark || isDesh)
                                ? [
                                    BoxShadow(
                                      color: Colors.white.withOpacity(0.15),
                                      blurRadius: 24,
                                      spreadRadius: 1,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : [],
                          ),
                          padding: const EdgeInsets.all(8),
                          child: localLogoPath != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image.asset(
                                    localLogoPath,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => _fallbackAvatar(fallbackText),
                                  ),
                                )
                              : _fallbackAvatar(fallbackText),
                        ),
                      ),
                    ),
                   // ✅ With this block:
Positioned(
  bottom: 8,
  left: 8,
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      IconButton(
        icon: Icon(
          widget.isFavorite ? Icons.favorite : Icons.favorite_border,
          color: widget.isFavorite ? Colors.redAccent : theme.iconTheme.color,
          size: 20,
        ),
        onPressed: widget.onFavoriteToggle,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      ),
      const SizedBox(height: 4),
      IconButton(
        icon: const Icon(Icons.share, size: 20),
        onPressed: _share,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      ),
    ],
  ),
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

  Widget _fallbackAvatar(String initials) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade200.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }
}
