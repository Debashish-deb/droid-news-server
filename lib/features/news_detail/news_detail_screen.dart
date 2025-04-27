import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/models/news_article.dart';
import '../../core/utils/favorites_manager.dart';

class NewsDetailScreen extends StatefulWidget {
  const NewsDetailScreen({super.key, required this.news});
  final NewsArticle news;

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
    final bool favorite = FavoritesManager.instance.favoriteArticles
        .any((article) => article.url == widget.news.url);
    setState(() {
      isFavorite = favorite;
    });
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.news.source),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareNews,
          ),
          IconButton(
            icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
            onPressed: _toggleFavorite,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: <Widget>[
            Text(
              widget.news.title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 10),
            Text(
              widget.news.fullContent.isNotEmpty
                  ? widget.news.fullContent
                  : widget.news.snippet,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}