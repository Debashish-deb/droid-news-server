// lib/presentation/features/home/widgets/news_card_enhanced.dart
// ENHANCED VERSION with Fixed Category Display

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/utils/source_logos.dart';
import '../../../../domain/entities/news_article.dart';
import '../../../../core/enums/theme_mode.dart';
import '../../../../core/di/providers.dart';
import '../../../../infrastructure/services/ml/ml_sentiment_analyzer.dart';
import '../../../../l10n/generated/app_localizations.dart'
    show AppLocalizations;
import '../../../providers/favorites_providers.dart';
import '../../../providers/theme_providers.dart';
import '../../growth/smart_share_service.dart';
import '../../../widgets/glass_icon_button.dart';
import '../../../../core/config/performance_config.dart';
import '../../../widgets/optimized_cached_image.dart' show OptimizedCachedImage;

class NewsCard extends ConsumerStatefulWidget {
  const NewsCard({
    required this.article,
    super.key,
    this.onTap,
    this.highlight = true,
    this.enableParallax = true,
    this.enableGlowEffect = true,
    this.showCategoryBadge = true,
    this.showSentimentBadge = true,
  });

  final NewsArticle article;
  final VoidCallback? onTap;
  final bool highlight;
  final bool enableParallax;
  final bool enableGlowEffect;
  final bool showCategoryBadge;
  final bool showSentimentBadge;

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
  Future<SentimentResult>? _sentimentFuture;

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
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _elevationAnimation = Tween<double>(
      begin: 1.0,
      end: 0.5,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _borderAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!widget.showSentimentBadge) return;

    // Cache the sentiment future - Defer to microtask to keep UI thread responsive
    // Safe to access PerformanceConfig.of(context) here
    if (_sentimentFuture == null) {
      final perf = PerformanceConfig.of(context);
      if (!perf.lowPowerMode && !perf.dataSaver) {
        // [DATA SAVER] skip sentiment
        _sentimentFuture = Future.microtask(
          () => ref
              .read(mlSentimentAnalyzerProvider)
              .analyzeSentiment(
                '${widget.article.title} ${widget.article.snippet}',
              ),
        );
      }
    }
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

  void _handleHover(bool hovering) {}

  void _updateParallax(PointerEvent event) {
    if (!widget.enableParallax || PerformanceConfig.of(context).reduceMotion) {
      return;
    }

    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;

    final localPosition = box.globalToLocal(event.position);
    final normalizedX = (localPosition.dx / box.size.width - 0.5) * 2;

    _parallaxOffset = normalizedX * 10;
    if (mounted) setState(() {});
  }

  bool get isLive => widget.article.isLive;
  bool get isBreaking =>
      DateTime.now().difference(widget.article.publishedAt) <
      const Duration(hours: 6);
  bool get isFresh =>
      DateTime.now().difference(widget.article.publishedAt) <
      const Duration(minutes: 30);
  bool get isPremiumContent => widget.article.tags?.contains('premium') == true;

  static const Set<String> _excludedTagPrefixes = <String>{'format'};
  static const Map<String, String> _taxonomyAliases = <String, String>{
    'bd': 'bangladesh',
    'bangla': 'bangladesh',
    'economy': 'economics',
    'financial': 'finance',
    'taxes': 'tax',
    'income tax': 'tax',
    'vat': 'tax',
    'world': 'world affairs',
    'global': 'world affairs',
    'political': 'politics',
    'education news': 'education',
    'health news': 'health',
    'crime news': 'crime',
    'opinions': 'opinion',
    'editorial': 'opinion',
  };
  static const Map<String, String> _bnTaxonomyFallback = <String, String>{
    'bangladesh': 'বাংলাদেশ',
    'generic': 'সাধারণ',
    'tax': 'কর',
    'electricity': 'বিদ্যুৎ',
    'football': 'ফুটবল',
    'murder': 'হত্যা',
    'dhaka': 'ঢাকা',
    'chattogram': 'চট্টগ্রাম',
    'chittagong': 'চট্টগ্রাম',
    'sylhet': 'সিলেট',
    'dinajpur': 'দিনাজপুর',
    'gazipur': 'গাজীপুর',
    'narayanganj': 'নারায়ণগঞ্জ',
    'tangail': 'টাঙ্গাইল',
    'kishoreganj': 'কিশোরগঞ্জ',
    'coxs bazar': 'কক্সবাজার',
    'cox s bazar': 'কক্সবাজার',
    'rangamati': 'রাঙামাটি',
    'bandarban': 'বান্দরবান',
    'rajshahi': 'রাজশাহী',
    'bogura': 'বগুড়া',
    'bogra': 'বগুড়া',
    'naogaon': 'নওগাঁ',
    'pabna': 'পাবনা',
    'khulna': 'খুলনা',
    'satkhira': 'সাতক্ষীরা',
    'jessore': 'যশোর',
    'jashore': 'যশোর',
    'moulvibazar': 'মৌলভীবাজার',
    'rangpur': 'রংপুর',
    'mymensingh': 'ময়মনসিংহ',
    'jamalpur': 'জামালপুর',
    'dhaka division': 'ঢাকা বিভাগ',
    'chattogram division': 'চট্টগ্রাম বিভাগ',
    'chittagong division': 'চট্টগ্রাম বিভাগ',
    'khulna division': 'খুলনা বিভাগ',
    'rajshahi division': 'রাজশাহী বিভাগ',
    'barishal division': 'বরিশাল বিভাগ',
    'barisal division': 'বরিশাল বিভাগ',
    'sylhet division': 'সিলেট বিভাগ',
    'rangpur division': 'রংপুর বিভাগ',
    'mymensingh division': 'ময়মনসিংহ বিভাগ',
    'government': 'সরকার',
    'parliament': 'সংসদ',
    'election': 'নির্বাচন',
    'banking': 'ব্যাংকিং',
    'finance': 'অর্থায়ন',
    'business': 'ব্যবসা',
    'industry': 'শিল্প',
    'trade': 'বাণিজ্য',
    'budget': 'বাজেট',
    'inflation': 'মূল্যস্ফীতি',
    'education': 'শিক্ষা',
    'university': 'বিশ্ববিদ্যালয়',
    'health': 'স্বাস্থ্য',
    'hospital': 'হাসপাতাল',
    'technology': 'প্রযুক্তি',
    'ai': 'কৃত্রিম বুদ্ধিমত্তা',
    'cybersecurity': 'সাইবার নিরাপত্তা',
    'science': 'বিজ্ঞান',
    'space': 'মহাকাশ',
    'environment': 'পরিবেশ',
    'climate change': 'জলবায়ু পরিবর্তন',
    'agriculture': 'কৃষি',
    'crime': 'অপরাধ',
    'fraud': 'প্রতারণা',
    'cybercrime': 'সাইবার অপরাধ',
    'corruption': 'দুর্নীতি',
    'court': 'আদালত',
    'law': 'আইন',
    'transport': 'পরিবহন',
    'road': 'সড়ক',
    'railway': 'রেলওয়ে',
    'airport': 'বিমানবন্দর',
    'energy': 'জ্বালানি',
    'gas': 'গ্যাস',
    'tourism': 'পর্যটন',
    'culture': 'সংস্কৃতি',
    'religion': 'ধর্ম',
    'opinion': 'মতামত',
    'policy': 'নীতি',
    'weather': 'আবহাওয়া',
    'district': 'জেলা',
    'city': 'নগর',
    'cricket': 'ক্রিকেট',
    'tennis': 'টেনিস',
    'badminton': 'ব্যাডমিন্টন',
    'olympics': 'অলিম্পিক',
    'world cup': 'বিশ্বকাপ',
    'film': 'চলচ্চিত্র',
    'cinema': 'সিনেমা',
    'television': 'টেলিভিশন',
    'drama': 'নাটক',
    'web series': 'ওয়েব সিরিজ',
    'music': 'সঙ্গীত',
    'concert': 'কনসার্ট',
    'celebrity': 'তারকা',
    'actor': 'অভিনেতা',
    'actress': 'অভিনেত্রী',
    'director': 'পরিচালক',
    'bollywood': 'বলিউড',
    'hollywood': 'হলিউড',
    'dhallywood': 'ঢালিউড',
    'breaking news': 'ব্রেকিং নিউজ',
    'analysis': 'বিশ্লেষণ',
    'editorial': 'সম্পাদকীয়',
    'interview': 'সাক্ষাৎকার',
    'feature': 'ফিচার',
    'investigation': 'অনুসন্ধান',
    'fact check': 'ফ্যাক্ট চেক',
    'timeline': 'সময়রেখা',
  };

  Widget _buildPremiumBadge(AppLocalizations loc) {
    return Positioned(
      top: 12,
      right: 12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.amber.withValues(alpha: 0.9),
              Colors.orange.withValues(alpha: 0.9),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.amber.withValues(alpha: 0.3),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star_rounded, size: 12, color: Colors.white),
            const SizedBox(width: 4),
            Text(
              loc.premium,
              style: const TextStyle(
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

  Widget _buildImage(
    String imageUrl,
    bool isDark,
    Color selectionColor,
    PerformanceConfig perf,
    AppLocalizations loc,
  ) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(24),
        topRight: Radius.circular(24),
      ),
      child: Stack(
        children: [
          Transform.translate(
            offset: Offset(_parallaxOffset, 0),
            child: OptimizedCachedImage(
              imageUrl: imageUrl,
              height: 100,
              width: double.infinity,
              semanticLabel: 'Article image: ${widget.article.title}',
              errorWidget: Container(
                height: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      isDark
                          ? const Color(0xFF2C2C2E)
                          : const Color(0xFFF2F2F7),
                      isDark
                          ? const Color(0xFF1C1C1E)
                          : const Color(0xFFE5E5EA),
                    ],
                  ),
                ),
                child: Icon(
                  Icons.image_not_supported_rounded,
                  size: 40,
                  color: isDark
                      ? const Color(0xFF8E8E93)
                      : const Color(0xFFAEAEB2),
                ),
              ),
            ),
          ),
          Container(
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.3),
                ],
              ),
            ),
          ),
          if (isPremiumContent) _buildPremiumBadge(loc),
        ],
      ),
    );
  }

  Widget _buildSourceLogo(String path, Color selectionColor) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: selectionColor.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(3),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.asset(
          path,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          errorBuilder: (context, error, stackTrace) {
            return Icon(
              Icons.public_rounded,
              size: 14,
              color: selectionColor.withValues(alpha: 0.8),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final perf = PerformanceConfig.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final themeMode = ref.watch(currentThemeModeProvider);

    final selectionColor = ref.watch(navIconColorProvider);
    final borderColor = ref.watch(borderColorProvider);
    final cardSurfaceColor = _resolveCardSurfaceColor(themeMode, theme);
    final uniformCardBackground =
        themeMode == AppThemeMode.dark ||
        themeMode == AppThemeMode.amoled ||
        (themeMode == AppThemeMode.system &&
            theme.brightness == Brightness.dark);

    final bool lowPowerMode = perf.lowPowerMode;
    final bool isLowEnd = perf.isLowEndDevice;
    final bool enableHover =
        !perf.reduceMotion && !perf.reduceEffects && !lowPowerMode && !isLowEnd;
    final bool enableParallax =
        !perf.reduceMotion &&
        !perf.reduceEffects &&
        !lowPowerMode &&
        !isLowEnd &&
        widget.enableParallax;

    // Disable blur if device is heating or low performance
    final double blurSigma = (perf.reduceEffects || perf.dataSaver)
        ? 0.0
        : 12.0;

    if (blurSigma <= 0) {
      return _buildCardContent(
        context,
        isDark,
        selectionColor,
        cardSurfaceColor,
        borderColor,
        blurSigma,
        enableHover,
        enableParallax,
        perf,
        uniformCardBackground,
      );
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
            child: _buildCardContent(
              context,
              isDark,
              selectionColor,
              cardSurfaceColor,
              borderColor,
              blurSigma,
              enableHover,
              enableParallax,
              perf,
              uniformCardBackground,
            ),
          );
        },
      ),
    );
  }

  Widget _buildCardContent(
    BuildContext context,
    bool isDark,
    Color selectionColor,
    Color cardSurfaceColor,
    Color borderColor,
    double blurSigma,
    bool enableHover,
    bool enableParallax,
    PerformanceConfig perf,
    bool uniformCardBackground,
  ) {
    final loc = AppLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: perf.reduceEffects || !isDark
            ? const []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20 * _elevationAnimation.value,
                  spreadRadius: 2 * _elevationAnimation.value,
                  offset: Offset(0, 8 * _elevationAnimation.value),
                ),
                if (_elevationAnimation.value > 0.5 && widget.highlight)
                  BoxShadow(
                    color: selectionColor.withValues(
                      alpha: 0.2 * _borderAnimation.value,
                    ),
                    blurRadius: 30,
                    spreadRadius: 2,
                  ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: RepaintBoundary(
          child: blurSigma > 0
              ? BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: blurSigma,
                    sigmaY: blurSigma,
                  ),
                  child: _buildInnerContent(
                    isDark,
                    cardSurfaceColor,
                    selectionColor,
                    borderColor,
                    perf,
                    loc,
                    uniformCardBackground,
                  ),
                )
              : _buildInnerContent(
                  isDark,
                  cardSurfaceColor,
                  selectionColor,
                  borderColor,
                  perf,
                  loc,
                  uniformCardBackground,
                ),
        ),
      ),
    );
  }

  Widget _buildInnerContent(
    bool isDark,
    Color cardSurfaceColor,
    Color selectionColor,
    Color borderColor,
    PerformanceConfig perf,
    AppLocalizations loc,
    bool uniformCardBackground,
  ) {
    final article = widget.article;
    final logoPath =
        SourceLogos.logos[article.sourceOverride ?? article.source];
    final taxonomyRow = perf.dataSaver
        ? null
        : _buildTaxonomyRow(isDark, selectionColor, loc);

    return Container(
      decoration: BoxDecoration(
        color: uniformCardBackground ? cardSurfaceColor : null,
        gradient: uniformCardBackground
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  cardSurfaceColor,
                  cardSurfaceColor.withValues(alpha: isDark ? 0.85 : 0.90),
                ],
              ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: widget.highlight
              ? selectionColor.withValues(alpha: 0.4 * _borderAnimation.value)
              : borderColor.withValues(alpha: 0.3),
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
          highlightColor: selectionColor.withValues(alpha: 0.1),
          splashColor: selectionColor.withValues(alpha: 0.2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (article.imageUrl != null && article.imageUrl!.isNotEmpty)
                _buildImage(
                  article.imageUrl!,
                  isDark,
                  selectionColor,
                  perf,
                  loc,
                ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTitle(isDark, selectionColor),
                    if (article.snippet.isNotEmpty && !perf.dataSaver) ...[
                      const SizedBox(height: 6),
                      _buildSnippet(isDark),
                    ],
                    if (taxonomyRow != null) ...[
                      const SizedBox(height: 8),
                      taxonomyRow,
                    ],
                    const SizedBox(height: 10),
                    _buildFooterRow(logoPath, selectionColor, isDark, perf),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _resolveCardSurfaceColor(AppThemeMode mode, ThemeData theme) {
    switch (mode) {
      case AppThemeMode.bangladesh:
        // Subtle red tint for Desh theme to improve card/background separation.
        return const Color(0xFF4D1F27).withValues(alpha: 0.58);
      case AppThemeMode.dark:
        // White-ash tint in dark mode for stronger card visibility.
        return Colors.white.withValues(alpha: 0.12);
      case AppThemeMode.amoled:
        return Colors.white.withValues(alpha: 0.10);
      case AppThemeMode.light:
        // Slightly dark ash in light mode for clearer contrast on bright bg.
        return const Color(0xFFE2E5EA).withValues(alpha: 0.94);
      case AppThemeMode.system:
        final brightness = theme.brightness;
        if (brightness == Brightness.dark) {
          return Colors.white.withValues(alpha: 0.12);
        }
        return const Color(0xFFE2E5EA).withValues(alpha: 0.94);
    }
  }

  Widget _buildTitle(bool isDark, Color selectionColor) {
    return Text(
      widget.article.title,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 14.5,
        height: 1.2,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.3,
        color: isDark ? Colors.white : Colors.black,
        shadows: isPremiumContent
            ? [
                Shadow(
                  color: Colors.amber.withValues(alpha: 0.2),
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
        fontSize: 12.0,
        height: 1.4,
        fontWeight: FontWeight.w400,
        color: isDark
            ? Colors.white.withValues(alpha: 0.7)
            : Colors.black.withValues(alpha: 0.6),
      ),
    );
  }

  Widget? _buildTaxonomyRow(
    bool isDark,
    Color selectionColor,
    AppLocalizations loc,
  ) {
    final chips = <Widget>[];
    final category = widget.article.category.trim().toLowerCase();

    if (widget.showCategoryBadge && category.isNotEmpty) {
      chips.add(
        _buildTaxonomyChip(
          label: _formatCategory(category, loc),
          isDark: isDark,
          color: _colorForCategory(category, selectionColor),
        ),
      );
    }

    for (final tag in _visibleTags(widget.article.tags, loc)) {
      chips.add(
        _buildTaxonomyChip(label: tag, isDark: isDark, color: selectionColor),
      );
    }

    if (chips.isEmpty) return null;
    return Wrap(spacing: 6, runSpacing: 6, children: chips);
  }

  List<String> _visibleTags(List<String>? rawTags, AppLocalizations loc) {
    if (rawTags == null || rawTags.isEmpty) return const <String>[];

    final labels = <String>[];
    final seen = <String>{};

    for (final raw in rawTags) {
      final normalized = raw.trim().toLowerCase();
      if (normalized.isEmpty || normalized == 'premium') continue;

      final prefix = normalized.contains(':')
          ? normalized.split(':').first
          : '';
      if (_excludedTagPrefixes.contains(prefix)) continue;

      final label = _formatTagLabel(normalized, loc);
      if (label.isEmpty || !seen.add(label)) continue;
      labels.add(label);
      if (labels.length >= 2) break;
    }

    return labels;
  }

  Widget _buildTaxonomyChip({
    required String label,
    required bool isDark,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.18 : 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
          color: isDark
              ? Colors.white.withValues(alpha: 0.9)
              : color.withValues(alpha: 0.95),
        ),
      ),
    );
  }

  String _formatCategory(String category, AppLocalizations loc) {
    return _localizeTaxonomyValue(category, loc);
  }

  Color _colorForCategory(String category, Color fallback) {
    switch (category) {
      case 'national':
        return const Color(0xFF2E7D32);
      case 'international':
        return const Color(0xFF1565C0);
      case 'sports':
        return const Color(0xFFEF6C00);
      case 'entertainment':
        return const Color(0xFFAD1457);
      default:
        return fallback;
    }
  }

  String _formatTagLabel(String rawTag, AppLocalizations loc) {
    final parts = rawTag.split(':');
    final prefix = parts.length > 1 ? parts.first.trim().toLowerCase() : '';
    final value = parts.length > 1 ? parts.sublist(1).join(':') : rawTag;
    if (value.isEmpty) return '';
    return _localizeTaxonomyValue(value, loc, prefix: prefix);
  }

  String _localizeTaxonomyValue(
    String rawValue,
    AppLocalizations loc, {
    String prefix = '',
  }) {
    final normalized = rawValue
        .trim()
        .toLowerCase()
        .replaceAll('-', ' ')
        .replaceAll('_', ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) return '';

    final canonical = _taxonomyAliases[normalized] ?? normalized;
    final normalizedPrefix = prefix.trim().toLowerCase();
    switch (canonical) {
      case 'latest':
        return loc.latest;
      case 'trending':
        return loc.trending;
      case 'national':
        return loc.national;
      case 'international':
      case 'world affairs':
        return loc.worldAffairs;
      case 'sports':
      case 'sport':
        return loc.sports;
      case 'entertainment':
        return loc.entertainment;
      case 'business':
        return loc.business;
      case 'economics':
        return loc.economics;
      case 'technology':
      case 'tech':
        return loc.technology;
      case 'science':
        return loc.science;
      case 'education':
        return loc.education;
      case 'politics':
        return loc.politics;
      case 'lifestyle':
        return loc.lifestyle;
      case 'arts':
        return loc.arts;
      case 'fashion':
        return loc.fashion;
      case 'regional':
        return loc.regional;
      default:
        break;
    }

    if (loc.localeName.startsWith('bn')) {
      if (canonical == 'generic') {
        switch (normalizedPrefix) {
          case 'international':
          case 'international location':
          case 'international org':
            return loc.international;
          case 'sports':
            return loc.sports;
          case 'entertainment':
            return loc.entertainment;
          case 'district':
            return 'জেলা';
          case 'division':
            return 'বিভাগ';
          case 'topic':
            return 'বিষয়';
          default:
            return 'সাধারণ';
        }
      }

      final directBn = _bnTaxonomyFallback[canonical];
      if (directBn != null) return directBn;

      final words = canonical.split(RegExp(r'\s+'));
      final converted = words
          .map((word) => _bnTaxonomyFallback[word] ?? _titleCase(word))
          .toList();
      if (converted.any((word) => _bnTaxonomyFallback.containsValue(word))) {
        return converted.join(' ');
      }
    }

    return _titleCase(canonical);
  }

  String _titleCase(String text) {
    return text
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  Widget _buildFooterRow(
    String? logoPath,
    Color selectionColor,
    bool isDark,
    PerformanceConfig perf,
  ) {
    final article = widget.article;
    final l10n = AppLocalizations.of(context);
    final isFavorite = ref.watch(isFavoriteArticleProvider(article));

    String timestamp = '';
    try {
      final diff = DateTime.now().difference(article.publishedAt);
      if (diff.isNegative) {
        timestamp = l10n.justNow;
      } else if (diff.inMinutes < 60) {
        timestamp = l10n.minutesAgo(diff.inMinutes);
      } else if (diff.inHours < 24) {
        timestamp = l10n.hoursAgo(diff.inHours);
      } else {
        timestamp = DateFormat('MMM d').format(article.publishedAt);
      }
    } catch (_) {
      timestamp = l10n.recently;
    }

    return Row(
      children: [
        // Left: Source Logo (Skipped in Data Saver)
        if (logoPath != null && !perf.dataSaver)
          _buildSourceLogo(logoPath, selectionColor)
        else if (!perf.dataSaver)
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: selectionColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: selectionColor.withValues(alpha: 0.3)),
            ),
            child: Icon(Icons.public_rounded, size: 12, color: selectionColor),
          ),
        const SizedBox(width: 8),

        // Middle: Source Name & Time
        Expanded(
          child: DefaultTextStyle(
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.5)
                  : Colors.black.withValues(alpha: 0.5),
            ),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    (article.sourceOverride ?? article.source).toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    '•',
                    style: TextStyle(
                      fontSize: 10,
                      color: selectionColor.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                Text(timestamp),
                if (isLive || isBreaking) ...[
                  const SizedBox(width: 6),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isLive
                          ? const Color(0xFFFF3B30)
                          : const Color(0xFFFF9500),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Right: Fast Actions
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Consumer(
              builder: (context, ref, _) {
                final favState = ref.watch(favoritesProvider);
                final isPending = favState.isPending(article.url);

                return GlassIconButton(
                  icon: isPending
                      ? Icons.sync_rounded
                      : (isFavorite
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded),
                  onPressed: isPending
                      ? null
                      : () => ref
                            .read(favoritesProvider.notifier)
                            .toggleArticle(article),
                  isDark: isDark,
                  backgroundColor: isFavorite
                      ? selectionColor.withValues(alpha: 0.2)
                      : null,
                  color: isFavorite
                      ? selectionColor
                      : (isPending ? Colors.grey : null),
                  size: 14,
                  padding: const EdgeInsets.all(4),
                  innerPadding: const EdgeInsets.all(6),
                  tooltip: isFavorite
                      ? l10n.removeFromFavorites
                      : l10n.addToFavorites,
                  semanticsLabel: isPending
                      ? l10n.syncing
                      : (isFavorite
                            ? l10n.removeFromFavorites
                            : l10n.addToFavorites),
                );
              },
            ),
            const SizedBox(width: 2),
            GlassIconButton(
              icon: Icons.share_rounded,
              onPressed: () async {
                await SmartShareService.shareArticle(article);
              },
              isDark: isDark,
              size: 14,
              padding: const EdgeInsets.all(4),
              innerPadding: const EdgeInsets.all(6),
              semanticsLabel: l10n.share,
            ),
          ],
        ),
      ],
    );
  }
}
