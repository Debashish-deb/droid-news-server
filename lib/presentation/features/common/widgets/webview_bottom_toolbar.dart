import 'dart:async' show FutureOr, unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/entities/news_article.dart';
import '../../../providers/favorites_providers.dart'
    show isFavoriteArticleProvider;
import '../../../providers/saved_articles_provider.dart'
    show savedArticlesProvider;
import 'webview_tokens.dart';

class WebBottomToolbar extends ConsumerWidget {
  const WebBottomToolbar({
    required this.article,
    required this.reduceEffects,
    required this.cs,
    required this.onBack,
    required this.onForward,
    required this.onFavorite,
    required this.onOfflineSave,
    required this.onRefresh,
    required this.onFind,
    super.key,
  });

  final NewsArticle article;
  final bool reduceEffects;
  final ColorScheme cs;
  final FutureOr<void> Function() onBack;
  final FutureOr<void> Function() onForward;
  final FutureOr<void> Function() onFavorite;
  final FutureOr<void> Function() onOfflineSave;
  final FutureOr<void> Function() onRefresh;
  final FutureOr<void> Function() onFind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFav = ref.watch(isFavoriteArticleProvider(article));
    final isSaved = ref
        .watch(savedArticlesProvider)
        .articles
        .any((a) => a.url == article.url);

    return Material(
      color: cs.surface,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: cs.outlineVariant.withValues(alpha: 0.55),
              width: 0.5,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: WT.toolbarHeight,
            child: Row(
              children: [
                ToolBtn(
                  icon: Icons.chevron_left_rounded,
                  onTap: onBack,
                  reduceEffects: reduceEffects,
                ),
                ToolBtn(
                  icon: Icons.chevron_right_rounded,
                  onTap: onForward,
                  reduceEffects: reduceEffects,
                ),
                const VSep(),
                ToolBtn(
                  icon: Icons.refresh_rounded,
                  onTap: onRefresh,
                  reduceEffects: reduceEffects,
                ),
                const VSep(),
                ToolBtn(
                  icon: isFav
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  activeColor: cs.error,
                  isActive: isFav,
                  reduceEffects: reduceEffects,
                  onTap: onFavorite,
                ),
                ToolBtn(
                  icon: isSaved
                      ? Icons.download_done_rounded
                      : Icons.download_for_offline_rounded,
                  activeColor: cs.tertiary,
                  isActive: isSaved,
                  reduceEffects: reduceEffects,
                  onTap: onOfflineSave,
                ),
                ToolBtn(
                  icon: Icons.search_rounded,
                  onTap: onFind,
                  reduceEffects: reduceEffects,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ToolBtn extends StatelessWidget {
  const ToolBtn({
    required this.icon,
    required this.onTap,
    required this.reduceEffects,
    this.isActive = false,
    this.activeColor,
    super.key,
  });

  final IconData icon;
  final bool isActive;
  final Color? activeColor;
  final bool reduceEffects;
  final FutureOr<void> Function() onTap;

  void _triggerTap() {
    final result = onTap();
    if (result is Future<void>) {
      unawaited(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.onSurface;
    final color = isActive
        ? (activeColor ?? base)
        : base.withValues(alpha: 0.60);

    return Expanded(
      child: Center(
        child: IconButton(
          onPressed: _triggerTap,
          icon: Icon(icon, size: 22),
          color: color,
          style: IconButton.styleFrom(
            backgroundColor: isActive
                ? (activeColor ?? base).withValues(alpha: 0.12)
                : Colors.transparent,
            foregroundColor: color,
            minimumSize: const Size.square(48),
            padding: EdgeInsets.zero,
          ),
        ),
      ),
    );
  }
}

class VSep extends StatelessWidget {
  const VSep({super.key});

  @override
  Widget build(BuildContext context) {
    final dividerColor = Theme.of(context).colorScheme.outlineVariant;
    return SizedBox(
      height: 24,
      child: VerticalDivider(
        color: dividerColor.withValues(alpha: 0.55),
        width: 1,
        thickness: 0.5,
      ),
    );
  }
}
