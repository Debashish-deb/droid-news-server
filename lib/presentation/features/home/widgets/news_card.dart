import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/utils/source_logos.dart';
import '../../../../domain/entities/news_article.dart';
import '../../../../infrastructure/services/ml/ml_categorizer.dart';
import '../../../../infrastructure/services/ml/ml_sentiment_analyzer.dart';
import '../../../providers/favorites_providers.dart';
import '../../../providers/theme_providers.dart';
import '../../../widgets/glass_icon_button.dart';
import '../../../../core/performance_config.dart';

class NewsCard extends ConsumerStatefulWidget {
  const NewsCard({
    required this.article,
    super.key,
    this.onTap,
    this.highlight = true,
    this.enableParallax = true,
    this.enableGlowEffect = true,
  });

  final NewsArticle article;
  final VoidCallback? onTap;
  final bool highlight;
  final bool enableParallax;
  final bool enableGlowEffect;

  @override
  ConsumerState<NewsCard> createState() => _NewsCardState();
}

class _NewsCardState extends ConsumerState<NewsCard> 
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;
  late Animation<double> _borderAnimation;
  double _parallaxOffset = 0.0;
  bool _isHovering = false;
  final bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.98,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    _elevationAnimation = Tween<double>(
      begin: 1.0,
      end: 0.5,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    _borderAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(_) => _controller.forward();
  void _onTapUp(_) {
    _controller.reverse().then((_) {
      widget.onTap?.call();
    });
  }
  void _onTapCancel() => _controller.reverse();

  void _handleHover(bool hovering) {
    if (mounted) {
      setState(() => _isHovering = hovering);
    }
  }

  void _updateParallax(PointerEvent event) {
    if (!widget.enableParallax) return;
    
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;

    final localPosition = box.globalToLocal(event.position);
    final normalizedX = (localPosition.dx / box.size.width - 0.5) * 2;
    final normalizedY = (localPosition.dy / box.size.height - 0.5) * 2;

    setState(() {
      _parallaxOffset = normalizedX * 10;
    });
  }

  bool get isLive => widget.article.isLive;
  bool get isBreaking =>
      DateTime.now().difference(widget.article.publishedAt) < 
      const Duration(hours: 6);
  bool get isFresh =>
      DateTime.now().difference(widget.article.publishedAt) <
      const Duration(minutes: 30);
  bool get isPremiumContent => widget.article.tags?.contains('premium') == true;

  Widget _buildPremiumBadge() {
    return Positioned(
      top: 12,
      right: 12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.amber.withOpacity(0.9),
              Colors.orange.withOpacity(0.9),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.amber.withOpacity(0.3),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star_rounded, size: 12, color: Colors.white),
            SizedBox(width: 4),
            Text(
              'PREMIUM',
              style: TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(String imageUrl, bool isDark, Color selectionColor) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(24),
        topRight: Radius.circular(24),
      ),
      child: Stack(
        children: [
          // Image with parallax effect
          Transform.translate(
            offset: Offset(_parallaxOffset, 0),
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              height: 100, // Reduced from 115
              width: double.infinity,
              fit: BoxFit.cover,
              memCacheHeight: 300, // Reduced from 360
              fadeInDuration: const Duration(milliseconds: 300),
              placeholder: (context, url) => Container(
                height: 100, // Reduced from 115
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                      isDark ? const Color(0xFF1C1C1E) : const Color(0xFFE5E5EA),
                    ],
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                height: 100, // Reduced from 115
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                      isDark ? const Color(0xFF1C1C1E) : const Color(0xFFE5E5EA),
                    ],
                  ),
                ),
                child: Icon(
                  Icons.image_not_supported_rounded,
                  size: 40,
                  color: isDark ? const Color(0xFF8E8E93) : const Color(0xFFAEAEB2),
                ),
              ),
            ),
          ),

          // Gradient overlay
          Container(
            height: 100, // Reduced from 115
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.3),
                ],
              ),
            ),
          ),

          // Premium badge if applicable
          if (isPremiumContent) _buildPremiumBadge(),
        ],
      ),
    );
  }

  Widget _buildSourceLogo(String path, Color selectionColor) {
    return Container(
      width: 20, // Reduced from 24
      height: 20, // Reduced from 24
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selectionColor.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(3), // Reduced from 4
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.asset(
          path,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }

  Widget _buildModernTag(String label, Color color, IconData icon) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), // Reduced from 10x5
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.2),
            color.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
        boxShadow: _isHovering
            ? [
                BoxShadow(
                  color: color.withOpacity(0.2),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBadge(BuildContext context, Color selectionColor) {
    return FutureBuilder<String>(
      future: MLCategorizer.instance.categorizeArticle(
        widget.article.title,
        widget.article.snippet,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final categoryId = snapshot.data!;
        final categoryInfo = MLCategorizer.instance.getCategoryInfo(categoryId);
        if (categoryInfo == null) return const SizedBox.shrink();

        final colorStr = categoryInfo['color'] as String?;
        final emoji = categoryInfo['emoji'] as String?;
        final label = categoryInfo['label'] as String?;

        if (colorStr == null || emoji == null || label == null) {
          return const SizedBox.shrink();
        }

        final categoryColor = Color(int.parse(colorStr.replaceFirst('#', '0xFF')));

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // Reduced from 12x6
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                categoryColor.withOpacity(0.2),
                categoryColor.withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: categoryColor.withOpacity(0.3),
            ),
            boxShadow: _isHovering
                ? [
                    BoxShadow(
                      color: categoryColor.withOpacity(0.15),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                emoji,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(width: 6),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                  color: categoryColor,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSentimentIndicator() {
    return FutureBuilder<double>(
      future: MLSentimentAnalyzer.instance.analyzeSentiment(
        '${widget.article.title} ${widget.article.snippet}'
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final sentiment = snapshot.data!;
        final emoji = MLSentimentAnalyzer.instance.getSentimentEmoji(sentiment);
        Color sentimentColor;

        if (sentiment > 0.3) {
          sentimentColor = Colors.green;
        } else if (sentiment < -0.3) {
          sentimentColor = Colors.red;
        } else {
          sentimentColor = Colors.amber;
        }

        return Container(
          width: 26, // Reduced from 32
          height: 26, // Reduced from 32
          decoration: BoxDecoration(
            color: sentimentColor.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(
              color: sentimentColor.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Center(
            child: Text(
              emoji,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final article = widget.article;
    final logoPath = SourceLogos.logos[article.sourceOverride ?? article.source];
    
    final isFavorite = ref.watch(isFavoriteArticleProvider(article));

    String timestamp = '';
    try {
      timestamp = DateFormat('h:mm a').format(article.publishedAt);
      final diff = DateTime.now().difference(article.publishedAt);
      if (diff.inMinutes < 60) {
        timestamp = '${diff.inMinutes}m ago';
      } else if (diff.inHours < 24) {
        timestamp = '${diff.inHours}h ago';
      } else {
        timestamp = DateFormat('MMM d').format(article.publishedAt);
      }
    } catch (_) {
      timestamp = 'Recently';
    }

    final perf = PerformanceConfig.of(context);
    final bool reduceEffects = perf.reduceEffects;
    final bool reduceMotion = perf.reduceMotion;
    final bool dataSaver = perf.dataSaver;

    final selectionColor = ref.watch(navIconColorProvider);
    final glassColor = ref.watch(glassColorProvider);
    final borderColor = ref.watch(borderColorProvider);

    final bool enableHover = !reduceMotion && !reduceEffects;
    final bool enableParallax = !reduceMotion && !reduceEffects && widget.enableParallax;
    final bool enableGlow = !reduceEffects && widget.enableGlowEffect && widget.highlight;
    final double blurSigma = reduceEffects ? 0.0 : 12.0;

    if (reduceEffects) {
      return _buildCardContent(context, isDark, selectionColor, glassColor, borderColor, blurSigma, enableHover, enableParallax);
    }

    return MouseRegion(
      onEnter: enableHover ? (_) => _handleHover(true) : null,
      onExit: enableHover ? (_) => _handleHover(false) : null,
      onHover: enableParallax ? _updateParallax : null,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: _buildCardContent(context, isDark, selectionColor, glassColor, borderColor, blurSigma, enableHover, enableParallax),
          );
        },
      ),
    );
  }

  Widget _buildCardContent(
    BuildContext context,
    bool isDark,
    Color selectionColor,
    Color glassColor,
    Color borderColor,
    double blurSigma,
    bool enableHover,
    bool enableParallax,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: PerformanceConfig.of(context).reduceEffects
            ? const []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(
                    isDark ? 0.3 : 0.1 * _elevationAnimation.value,
                  ),
                  blurRadius: 20 * _elevationAnimation.value,
                  spreadRadius: 2 * _elevationAnimation.value,
                  offset: Offset(0, 8 * _elevationAnimation.value),
                ),
                if (_elevationAnimation.value > 0.5 && widget.highlight)
                  BoxShadow(
                    color: selectionColor.withOpacity(
                      0.2 * _borderAnimation.value,
                    ),
                    blurRadius: 30,
                    spreadRadius: 2,
                  ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: blurSigma > 0
            ? BackdropFilter(
                filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
                child: _buildInnerContent(isDark, glassColor, selectionColor, borderColor),
              )
            : _buildInnerContent(isDark, glassColor, selectionColor, borderColor),
      ),
    );
  }

  Widget _buildInnerContent(bool isDark, Color glassColor, Color selectionColor, Color borderColor) {
    final article = widget.article;
    final logoPath = SourceLogos.logos[article.sourceOverride ?? article.source];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            glassColor,
            glassColor.withOpacity(isDark ? 0.08 : 0.15),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: widget.highlight
              ? selectionColor.withOpacity(0.4 * _borderAnimation.value)
              : borderColor.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTapDown: _onTapDown,
          onTapUp: _onTapUp,
          onTapCancel: _onTapCancel,
          borderRadius: BorderRadius.circular(24),
          highlightColor: selectionColor.withOpacity(0.1),
          splashColor: selectionColor.withOpacity(0.2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (article.imageUrl != null && article.imageUrl!.isNotEmpty)
                _buildImage(
                  article.imageUrl!,
                  isDark,
                  selectionColor,
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), // Reduced from all(10)
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSourceRow(logoPath, selectionColor, isDark),
                    const SizedBox(height: 2), // Reduced from 4
                    _buildTitle(isDark, selectionColor),
                    if (article.snippet.isNotEmpty) ...[
                      const SizedBox(height: 4), // Reduced from 6
                      _buildSnippet(isDark),
                    ],
                    const SizedBox(height: 4), // Reduced from 6
                    _buildActionsRow(selectionColor, isDark),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSourceRow(String? logoPath, Color selectionColor, bool isDark) {
    final article = widget.article;
    return Row(
      children: [
        if (logoPath != null)
          _buildSourceLogo(logoPath, selectionColor)
        else
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: selectionColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selectionColor.withOpacity(0.3),
              ),
            ),
            child: Icon(
              Icons.public_rounded,
              size: 14,
              color: selectionColor,
            ),
          ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            (article.sourceOverride ?? article.source).toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: isDark ? Colors.white.withOpacity(0.7) : Colors.black.withOpacity(0.6),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (isLive)
          _buildModernTag(
            "LIVE",
            const Color(0xFFFF3B30),
            Icons.fiber_manual_record_rounded,
          )
        else if (isBreaking)
          _buildModernTag(
            "BREAKING",
            const Color(0xFFFF9500),
            Icons.bolt_rounded,
          )
        else if (isFresh)
          _buildModernTag(
            "FRESH",
            const Color(0xFF34C759),
            Icons.access_time_rounded,
          ),
      ],
    );
  }

  Widget _buildTitle(bool isDark, Color selectionColor) {
    return Text(
      widget.article.title,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 14.5, // Reduced from 15.5
        height: 1.2,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.3,
        color: isDark ? Colors.white : Colors.black,
        shadows: isPremiumContent
            ? [
                Shadow(
                  color: Colors.amber.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
    );
  }

  Widget _buildSnippet(bool isDark) {
    return Text(
      widget.article.snippet,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 12.0, // Reduced from 12.5
        height: 1.4,
        fontWeight: FontWeight.w400,
        color: isDark ? Colors.white.withOpacity(0.7) : Colors.black.withOpacity(0.6),
      ),
    );
  }

  Widget _buildActionsRow(Color selectionColor, bool isDark) {
    final article = widget.article;
    final isFavorite = ref.watch(isFavoriteArticleProvider(article));

    String timestamp = '';
    try {
      final diff = DateTime.now().difference(article.publishedAt);
      if (diff.inMinutes < 60) {
        timestamp = '${diff.inMinutes}m ago';
      } else if (diff.inHours < 24) {
        timestamp = '${diff.inHours}h ago';
      } else {
        timestamp = DateFormat('MMM d').format(article.publishedAt);
      }
    } catch (_) {
      timestamp = 'Recently';
    }

    return Row(
      children: [
        _buildCategoryBadge(context, selectionColor),
        const SizedBox(width: 12),
        _buildSentimentIndicator(),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.08),
            ),
          ),
          child: Text(
            timestamp,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white.withOpacity(0.5) : Colors.black.withOpacity(0.5),
            ),
          ),
        ),
        const SizedBox(width: 12),
        GlassIconButton(
          icon: isFavorite ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
          onPressed: () => ref.read(favoritesProvider.notifier).toggleArticle(article),
          isDark: isDark,
          backgroundColor: isFavorite ? selectionColor.withOpacity(0.3) : null,
          color: isFavorite ? selectionColor : null,
          size: 18,
        ),
        const SizedBox(width: 8),
        GlassIconButton(
          icon: Icons.share_rounded,
          onPressed: () async {
            await Share.share(
              '${article.title}\n\n${article.url}',
              subject: article.title,
            );
          },
          isDark: isDark,
          size: 18,
        ),
      ],
    );
  }
}
