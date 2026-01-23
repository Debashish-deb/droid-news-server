// lib/widgets/favorite_button.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/news_article.dart';
import '../core/services/favorites_providers.dart';

class FavoriteButton extends ConsumerStatefulWidget {
  const FavoriteButton({
    required this.article,
    super.key,
    this.onFavoriteChanged,
  });

  final NewsArticle article;
  final VoidCallback? onFavoriteChanged;

  @override
  ConsumerState<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends ConsumerState<FavoriteButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _flashAnim;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _scaleAnim = TweenSequence<double>(<TweenSequenceItem<double>>[
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 50),
    ]).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );

    _flashAnim = Tween<double>(begin: 0.0, end: 0.3).animate(
      CurvedAnimation(parent: _animController, curve: const Interval(0, 0.5)),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _toggleFavorite() async {
    // Start the pop+flash
    _animController.forward(from: 0);
    // Toggle using Riverpod
    await ref.read(favoritesProvider.notifier).toggleArticle(widget.article);
    widget.onFavoriteChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    // Watch using Riverpod
    final bool isFavorite = ref.watch(
      favoritesProvider.select(
        (state) => state.articles.any((a) => a.url == widget.article.url),
      ),
    );

    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final Color heartColor =
        isFavorite
            ? colorScheme.secondary
            : colorScheme.onSurface.withOpacity(0.6);

    return Semantics(
      label: isFavorite ? 'Remove from favorites' : 'Add to favorites',
      button: true,
      child: GestureDetector(
        onTap: _toggleFavorite,
        child: AnimatedBuilder(
          animation: _animController,
          builder: (BuildContext context, Widget? child) {
            return Stack(
              alignment: Alignment.center,
              children: <Widget>[
                // Flashing frosted circle
                if (_flashAnim.value > 0)
                  BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: 12 * _flashAnim.value,
                      sigmaY: 12 * _flashAnim.value,
                    ),
                    child: Container(
                      width: 40 + 20 * _flashAnim.value,
                      height: 40 + 20 * _flashAnim.value,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(_flashAnim.value * 0.2),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                // Scaled heart
                Transform.scale(
                  scale: _scaleAnim.value,
                  child: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: heartColor,
                    size: 28,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
