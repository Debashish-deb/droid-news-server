// lib/features/news/screens/news_detail_screen.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../data/models/news_article.dart';
import '../../core/utils/favorites_manager.dart';
import '../../core/theme_provider.dart';
import '../../widgets/app_drawer.dart';
import '../../core/theme.dart';
import 'animated_background.dart';

class NewsDetailScreen extends StatefulWidget {
  final NewsArticle news;
  const NewsDetailScreen({Key? key, required this.news}) : super(key: key);

  @override
  State<NewsDetailScreen> createState() => _NewsDetailScreenState();
}

class _NewsDetailScreenState extends State<NewsDetailScreen> {
  bool isFavorite = false;

  @override
  void initState() {
    super.initState();
    _checkFavorite();
  }

  Future<void> _checkFavorite() async {
    final fav = FavoritesManager.instance.favoriteArticles
        .any((a) => a.url == widget.news.url);
    setState(() => isFavorite = fav);
  }

  Future<void> _toggleFavorite() async {
    if (isFavorite) {
      await FavoritesManager.instance.removeFavorite(widget.news);
    } else {
      await FavoritesManager.instance.addFavorite(widget.news);
    }
    _checkFavorite();
  }

  void _shareNews() {
    Share.share('${widget.news.title}\n\n${widget.news.url}');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      drawer: const AppDrawer(),
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          widget.news.source,
          style: theme.textTheme.titleMedium?.copyWith(
            color: scheme.onPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        flexibleSpace: const AnimatedBackground(overlayOpacity: 0.35),
        actions: [
          IconButton(
            icon: Icon(Icons.share, color: scheme.onPrimary),
            onPressed: _shareNews,
          ),
          IconButton(
            icon: Icon(
              isFavorite ? Icons.favorite : Icons.favorite_border,
              color: Colors.redAccent,
            ),
            onPressed: _toggleFavorite,
          ),
        ],
      ),
      body: AnimatedBackground(
        overlayOpacity: 0.25,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, kToolbarHeight + 24, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.news.imageUrl != null && widget.news.imageUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CachedNetworkImage(
                    imageUrl: widget.news.imageUrl!,
                    placeholder: (context, url) => Container(
                      height: 200,
                      color: Colors.black12,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 200,
                      color: Colors.black12,
                      child: const Center(child: Icon(Icons.broken_image)),
                    ),
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  color: scheme.surface.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: scheme.primary.withOpacity(0.25)),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.news.title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.bold,
                        shadows: const [Shadow(blurRadius: 4, color: Colors.black45)],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.news.fullContent.isNotEmpty
                          ? widget.news.fullContent
                          : (widget.news.snippet.isNotEmpty
                              ? widget.news.snippet
                              : 'No content available.'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurface.withOpacity(0.85),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
