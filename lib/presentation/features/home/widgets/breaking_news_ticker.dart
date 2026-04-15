import 'dart:async';
import '../../../../core/theme/theme_skeleton.dart';
import 'package:flutter/material.dart';
import "../../../../domain/entities/news_article.dart";

class BreakingNewsTicker extends StatefulWidget {
  const BreakingNewsTicker({required this.articles, super.key});

  final List<NewsArticle> articles;

  @override
  State<BreakingNewsTicker> createState() => _BreakingNewsTickerState();
}

class _BreakingNewsTickerState extends State<BreakingNewsTicker> {
  late final ScrollController _scrollController;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncAutoScroll();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAutoScroll();
  }

  @override
  void didUpdateWidget(covariant BreakingNewsTicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.articles != widget.articles) {
      _syncAutoScroll();
    }
  }

  void _syncAutoScroll() {
    final shouldScroll =
        mounted && widget.articles.isNotEmpty && TickerMode.of(context);

    if (shouldScroll) {
      _startAutoScroll();
    } else {
      _stopAutoScroll();
    }
  }

  void _startAutoScroll() {
    if (!mounted ||
        widget.articles.isEmpty ||
        !TickerMode.of(context) ||
        (_timer?.isActive ?? false)) {
      return;
    }

    // Optimized from 50ms to 100ms (10 FPS instead of 20 FPS) for better battery performance
    const Duration tick = Duration(milliseconds: 100);
    _timer = Timer.periodic(tick, (Timer t) {
      if (!mounted || !_scrollController.hasClients) return;

      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent) {
        _scrollController.jumpTo(0);
      } else {
        // Increased jump distance to compensate for lower frequency
        _scrollController.jumpTo(_scrollController.position.pixels + 3.0);
      }
    });
  }

  void _stopAutoScroll() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _stopAutoScroll();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.articles.isEmpty) return const SizedBox.shrink();

    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      height: 40,
      color: Theme.of(context).cardTheme.color ?? scheme.surface,
      child: Row(
        children: <Widget>[
          Container(
            padding: ThemeSkeleton.shared.insetsSymmetric(horizontal: 12),
            height: double.infinity,
            color: scheme.error,
            alignment: Alignment.center,
            child: Text(
              'BREAKING',
              style: TextStyle(
                color: scheme.onError,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 1,
              ),
            ),
          ),

          Expanded(
            child: RepaintBoundary(
              child: ShaderMask(
              shaderCallback: (Rect bounds) {
                return const LinearGradient(
                  colors: <Color>[
                    Colors.white,
                    Colors.white,
                    Colors.transparent,
                  ],
                  stops: <double>[0.0, 0.9, 1.0],
                ).createShader(bounds);
              },
              blendMode: BlendMode.dstIn,
              child: ListView.builder(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: widget.articles.length,
                itemBuilder: (BuildContext context, int index) {
                  final NewsArticle article = widget.articles[index];
                  return Padding(
                    padding: ThemeSkeleton.shared.insetsSymmetric(
                      horizontal: 20,
                    ),
                    child: Center(
                      child: Text(
                        '•   ${article.title}',
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            ),
          ),
        ],
      ),
    );
  }
}
