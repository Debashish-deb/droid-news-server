import 'package:flutter/material.dart';
import '../../data/models/news_article.dart';
import '../../core/utils/favorites_manager.dart';

class FavoriteButton extends StatefulWidget {
  const FavoriteButton({
    super.key,
    required this.article,
    this.onFavoriteChanged,
  });

  final NewsArticle article;
  final VoidCallback? onFavoriteChanged;

  @override
  State<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<FavoriteButton> {
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _loadFavoriteStatus();
  }

  Future<void> _loadFavoriteStatus() async {
    final status = FavoritesManager.instance.favoriteArticles
        .any((article) => article.url == widget.article.url);
    setState(() => _isFavorite = status);
  }

  Future<void> _toggleFavorite() async {
    if (_isFavorite) {
      await FavoritesManager.instance.removeFavorite(widget.article);
    } else {
      await FavoritesManager.instance.addFavorite(widget.article);
    }
    await _loadFavoriteStatus();
    widget.onFavoriteChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: _isFavorite ? 'Remove from favorites' : 'Add to favorites',
      button: true,
      child: IconButton(
        icon: Icon(
          _isFavorite ? Icons.favorite : Icons.favorite_border,
          color: _isFavorite ? Colors.redAccent : Colors.grey,
        ),
        onPressed: _toggleFavorite,
        tooltip: _isFavorite ? 'Unfavorite' : 'Favorite',
      ),
    );
  }
}