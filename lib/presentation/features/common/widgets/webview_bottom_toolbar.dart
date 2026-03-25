import 'dart:async' show FutureOr, unawaited;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/entities/news_article.dart';
import '../../../providers/favorites_providers.dart'
    show isFavoriteArticleProvider;
import '../../../providers/saved_articles_provider.dart'
    show savedArticlesProvider;
import 'webview_tokens.dart';

// ─────────────────────────────────────────────
// BOTTOM TOOLBAR
// ─────────────────────────────────────────────
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
    // Scoped watches → only this widget rebuilds on fav/saved change.
    final isFav = ref.watch(isFavoriteArticleProvider(article));
    final isSaved = ref
        .watch(savedArticlesProvider)
        .articles
        .any((a) => a.url == article.url);

    final content = Container(
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: reduceEffects ? 0.96 : 0.88),
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
              ToolBtn(icon: Icons.chevron_left_rounded, onTap: onBack),
              ToolBtn(icon: Icons.chevron_right_rounded, onTap: onForward),
              const VSep(),
              ToolBtn(icon: Icons.refresh_rounded, onTap: onRefresh),
              const VSep(),
              ToolBtn(
                icon: isFav
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                activeColor: cs.error,
                isActive: isFav,
                onTap: onFavorite,
              ),
              ToolBtn(
                icon: isSaved
                    ? Icons.download_done_rounded
                    : Icons.download_for_offline_rounded,
                activeColor: cs.tertiary,
                isActive: isSaved,
                onTap: onOfflineSave,
              ),
              ToolBtn(icon: Icons.search_rounded, onTap: onFind),
            ],
          ),
        ),
      ),
    );

    if (reduceEffects) return content;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: content,
      ),
    );
  }
}

class ToolBtn extends StatefulWidget {
  const ToolBtn({
    required this.icon,
    required this.onTap,
    this.isActive = false,
    this.activeColor,
    super.key,
  });
  final IconData icon;
  final bool isActive;
  final Color? activeColor;
  final FutureOr<void> Function() onTap;

  @override
  State<ToolBtn> createState() => _ToolBtnState();
}

class _ToolBtnState extends State<ToolBtn> {
  bool _pressed = false;

  void _triggerTap() {
    final result = widget.onTap();
    if (result is Future<void>) {
      unawaited(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.onSurface;
    final color = widget.isActive
        ? (widget.activeColor ?? base)
        : base.withValues(alpha: 0.60);

    return Expanded(
      child: GestureDetector(
        onTap: _triggerTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: _pressed ? 0.82 : 1.0,
          duration: _pressed ? WT.toolPress : WT.toolRelease,
          curve: _pressed ? Curves.easeIn : Curves.elasticOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: WT.toolbarHeight,
            color: _pressed ? base.withValues(alpha: 0.05) : Colors.transparent,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: widget.isActive
                      ? (widget.activeColor ?? base).withValues(alpha: 0.12)
                      : Colors.transparent,
                ),
                child: Icon(widget.icon, size: 22, color: color),
              ),
            ),
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
