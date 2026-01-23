import 'dart:async';
import 'package:flutter/material.dart';
import '../../../data/models/news_article.dart';

class BreakingNewsTicker extends StatefulWidget {
  const BreakingNewsTicker({required this.articles, super.key});

  final List<NewsArticle> articles;

  @override
  State<BreakingNewsTicker> createState() => _BreakingNewsTickerState();
}

class _BreakingNewsTickerState extends State<BreakingNewsTicker> {
  late final ScrollController _scrollController;
  late Timer _timer;
  final bool _isScrolling = true;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();

    // Start scrolling after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAutoScroll();
    });
  }

  void _startAutoScroll() {
    if (!mounted || !_isScrolling || widget.articles.isEmpty) return;

    // Calculate duration based on content width (simulated)
    // We want a slow, steady speed. e.g. 50 pixels per second.
    // Since we don't know exact width, we'll just scroll far and reset.
    // A better approach for "infinite" ticker is typically specific packages,
    // but here we will scroll to end and jump back.

    // Constant low speed scroll
    const Duration tick = Duration(milliseconds: 50);
    _timer = Timer.periodic(tick, (Timer t) {
      if (!mounted || !_scrollController.hasClients) return;

      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent) {
        _scrollController.jumpTo(0);
      } else {
        _scrollController.jumpTo(_scrollController.position.pixels + 1.5);
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
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
      color:
          Theme.of(context).cardTheme.color ??
          scheme.surface, // Match card background
      child: Row(
        children: <Widget>[
          // Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            height: double.infinity,
            color: scheme.error, // Use Theme Error color (Red)
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

          // Ticker List
          Expanded(
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
                physics:
                    const NeverScrollableScrollPhysics(), // Disable user scroll
                itemCount: widget.articles.length,
                itemBuilder: (BuildContext context, int index) {
                  final NewsArticle article = widget.articles[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
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
        ],
      ),
    );
  }
}
