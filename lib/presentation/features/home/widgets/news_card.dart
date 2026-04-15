// lib/presentation/features/home/widgets/news_card_enhanced.dart
// ENHANCED VERSION with Fixed Category Display

import 'dart:ui';
import '../../../../core/theme/theme_skeleton.dart';
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
import '../../../widgets/platform_surface_treatment.dart';

typedef _NewsCardThemeSnapshot = ({
  AppThemeMode themeMode,
  Color selectionColor,
  Color borderColor,
});

final _newsCardThemeProvider = Provider<_NewsCardThemeSnapshot>((ref) {
  return (
    themeMode: ref.watch(currentThemeModeProvider),
    selectionColor: ref.watch(navIconColorProvider),
    borderColor: ref.watch(borderColorProvider),
  );
});

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
    with TickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double> _scaleAnimation = const AlwaysStoppedAnimation(1.0);
  Animation<double> _elevationAnimation = const AlwaysStoppedAnimation(1.0);
  double _parallaxOffset = 0.0;
  Future<SentimentResult>? _sentimentFuture;
  bool _motionEffectsEnabled = false;
  Object? _lastMotionProfileKey;
  String? _cachedTaxonomyLocale;
  String? _cachedTaxonomyCategory;
  String? _cachedTaxonomyTagsKey;
  String? _cachedLocalizedCategoryLabel;
  List<String>? _cachedVisibleTaxonomyTags;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final perf = PerformanceConfig.of(context);
    final nextMotionProfileKey = Object.hash(
      perf.reduceMotion,
      perf.reduceEffects,
      perf.lowPowerMode,
      perf.isLowEndDevice,
      perf.performanceTier,
    );
    if (_lastMotionProfileKey != nextMotionProfileKey) {
      _lastMotionProfileKey = nextMotionProfileKey;
      _syncMotionController(perf);
    }

    if (!widget.showSentimentBadge) return;

    // Cache the sentiment future - Defer to microtask to keep UI thread responsive.
    if (_sentimentFuture == null) {
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
    _controller?.dispose();
    super.dispose();
  }

  void _syncMotionController([PerformanceConfig? perf]) {
    final resolvedPerf = perf ?? PerformanceConfig.of(context);
    final shouldEnable =
        !resolvedPerf.reduceMotion &&
        !resolvedPerf.reduceEffects &&
        !resolvedPerf.lowPowerMode &&
        !resolvedPerf.isLowEndDevice &&
        resolvedPerf.performanceTier == DevicePerformanceTier.flagship;

    if (shouldEnable == _motionEffectsEnabled) return;
    _motionEffectsEnabled = shouldEnable;

    if (shouldEnable) {
      _controller ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 200),
      );
      final controller = _controller!;
      _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeOutCubic),
      );
      _elevationAnimation = Tween<double>(begin: 1.0, end: 0.5).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeOutCubic),
      );
      return;
    }

    _controller?.dispose();
    _controller = null;
    _scaleAnimation = const AlwaysStoppedAnimation(1.0);
    _elevationAnimation = const AlwaysStoppedAnimation(1.0);
  }

  void _onTapDown(_) => _controller?.forward();
  void _onTapUp(_) {
    final controller = _controller;
    if (controller == null) {
      widget.onTap?.call();
      return;
    }
    controller.reverse();
    widget.onTap?.call();
  }

  void _onTapCancel() => _controller?.reverse();

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

  static const Set<String> _excludedTagPrefixes = <String>{'format', 'topic'};
  static const Set<String> _hiddenTagSemantics = <String>{'tax'};
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
  static const Map<String, Set<String>> _categorySemanticAliases =
      <String, Set<String>>{
        'national': <String>{'national', 'bangladesh', 'country bangladesh'},
        'international': <String>{
          'international',
          'global',
          'world',
          'world affairs',
        },
        'sports': <String>{'sports', 'sport'},
        'entertainment': <String>{'entertainment', 'showbiz'},
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
  static const Map<String, String> _bnPublisherFallback = <String, String>{
    'al jazeera': 'আল জাজিরা',
    'alokito bangladesh': 'আলোকিত বাংলাদেশ',
    'amader shomoy': 'আমাদের সময়',
    'ars technica': 'আর্স টেকনিকা',
    'bangla insider': 'বাংলা ইনসাইডার',
    'bangla tribune': 'বাংলা ট্রিবিউন',
    'bangladesh pratidin': 'বাংলাদেশ প্রতিদিন',
    'banglanews24': 'বাংলানিউজ২৪',
    'banglanews24 com': 'বাংলানিউজ২৪',
    'bbc bangla': 'বিবিসি বাংলা',
    'bbc bengali': 'বিবিসি বাংলা',
    'bbc news': 'বিবিসি নিউজ',
    'bd news 24': 'বিডিনিউজ২৪',
    'bdnews24': 'বিডিনিউজ২৪',
    'bdnews24 com': 'বিডিনিউজ২৪',
    'bhorer kagoj': 'ভোরের কাগজ',
    'bss': 'বাসস',
    'bss news': 'বাসস',
    'cnet': 'সিনেট',
    'cnn': 'সিএনএন',
    'dainik azadi': 'দৈনিক আজাদী',
    'daily campus': 'দ্য ডেইলি ক্যাম্পাস',
    'daily star': 'দ্য ডেইলি স্টার',
    'dawn': 'ডন',
    'dhaka post': 'ঢাকা পোস্ট',
    'dhaka tribune': 'ঢাকা ট্রিবিউন',
    'engadget': 'এনগ্যাজেট',
    'gizmodo': 'গিজমোডো',
    'google news': 'গুগল নিউজ',
    'inqilab': 'ইনকিলাব',
    'ittefaq': 'ইত্তেফাক',
    'jai jai din': 'যায়যায়দিন',
    'jugantor': 'যুগান্তর',
    'kaler kantho': 'কালের কণ্ঠ',
    'kalerkontho': 'কালের কণ্ঠ',
    'khulna gazette': 'খুলনা গেজেট',
    'lekhapora bd': 'লেখাপড়া বিডি',
    'manab kantha': 'মানবকণ্ঠ',
    'manab zamin': 'মানবজমিন',
    'mashable': 'ম্যাশেবল',
    'naya diganta': 'নয়া দিগন্ত',
    'prothom alo': 'প্রথম আলো',
    'prothomalo': 'প্রথম আলো',
    'reuters': 'রয়টার্স',
    'risingbd': 'রাইজিংবিডি',
    'samakal': 'সমকাল',
    'sangbad pratidin': 'সংবাদ প্রতিদিন',
    'shiksha barta': 'শিক্ষাবার্তা',
    'sylheter dak': 'সিলেটের ডাক',
    'techcrunch': 'টেকক্রাঞ্চ',
    'the daily campus': 'দ্য ডেইলি ক্যাম্পাস',
    'the daily star': 'দ্য ডেইলি স্টার',
    'the hindu': 'দ্য হিন্দু',
    'the next web': 'দ্য নেক্সট ওয়েব',
    'the verge': 'দ্য ভার্জ',
    'wired': 'ওয়্যার্ড',
    'zdnet': 'জেডডিনেট',
  };

  Widget _buildImage(
    String imageUrl,
    bool isDark,
    Color selectionColor,
    PerformanceConfig perf,
    AppLocalizations loc,
    double spacingScale,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.only(
        topLeft: ThemeSkeleton.shared.radius(24),
        topRight: ThemeSkeleton.shared.radius(24),
      ),
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Transform.translate(
              offset: Offset(_parallaxOffset, 0),
              child: OptimizedCachedImage(
                imageUrl: imageUrl,
                width: double.infinity,
                semanticLabel: 'Article image: ${widget.article.title}',
                errorWidget: Container(
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
                    size: 40 * spacingScale,
                    color: isDark
                        ? const Color(0xFF8E8E93)
                        : const Color(0xFFAEAEB2),
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
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
          ),
        ],
      ),
    );
  }

  Widget _buildSourceLogo(String path, Color selectionColor) {
    return Container(
      width: 22,
      height: 22,
      padding: ThemeSkeleton.shared.insetsAll(3.5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: ThemeSkeleton.shared.circular(7),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 3,
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: Center(
        child: Image.asset(
          path,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          errorBuilder: (context, error, stackTrace) {
            return Icon(
              Icons.public_rounded,
              size: 12,
              color: selectionColor.withValues(alpha: 0.7),
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
    final cardTheme = ref.watch(_newsCardThemeProvider);
    final themeMode = cardTheme.themeMode;
    final selectionColor = cardTheme.selectionColor;
    final borderColor = cardTheme.borderColor;
    final preferMaterialChrome = preferAndroidMaterialSurfaceChrome(context);
    final cardSurfaceColor = _resolveCardSurfaceColor(themeMode, theme);
    final uniformCardBackground =
        themeMode == AppThemeMode.dark ||
        themeMode == AppThemeMode.bangladesh ||
        (themeMode == AppThemeMode.system &&
            theme.brightness == Brightness.dark);

    final mediaQuery = MediaQuery.of(context);
    final double screenWidth = mediaQuery.size.width;
    final double screenHeight = mediaQuery.size.height;

    // Viewport scaling factors
    final double textScale = (screenWidth < 360)
        ? 0.92
        : (screenWidth > 480 ? 1.08 : 1.0);
    final double spacingScale = (screenHeight < 700) ? 0.85 : 1.0;

    final bool isLowEnd = perf.isLowEndDevice;
    final bool lowPowerMode = perf.lowPowerMode;
    final bool flagshipEffects =
        perf.performanceTier == DevicePerformanceTier.flagship;
    final Duration publishedAge = (() {
      final diff = DateTime.now().difference(widget.article.publishedAt);
      return diff.isNegative ? Duration.zero : diff;
    })();
    final bool isLive = widget.article.isLive;
    final bool isBreaking = publishedAge < const Duration(hours: 6);

    final bool enableHover =
        flagshipEffects &&
        !perf.reduceMotion &&
        !perf.reduceEffects &&
        !lowPowerMode &&
        !isLowEnd;
    final bool enableParallax =
        flagshipEffects &&
        !perf.reduceMotion &&
        !perf.reduceEffects &&
        !lowPowerMode &&
        !isLowEnd &&
        widget.enableParallax;

    // Aggressive performance optimizations for non-flagship devices
    // Blur is disabled globally since BackdropFilter inside scrollable lists generates
    // multiple massive rendering wrappers without significant visual upside.
    const bool allowCardBlur = false;

    final bool allowComplexShadows =
        !perf.reduceEffects &&
        !lowPowerMode &&
        !isLowEnd &&
        perf.performanceTier == DevicePerformanceTier.flagship &&
        !preferMaterialChrome;

    const double blurSigma = allowCardBlur ? 4.0 : 0.0;

    final controller = _controller;
    if (blurSigma <= 0 || controller == null) {
      return _buildCardContent(
        context,
        isDark,
        selectionColor,
        cardSurfaceColor,
        borderColor,
        themeMode,
        blurSigma,
        enableHover,
        enableParallax,
        perf,
        uniformCardBackground,
        textScale,
        spacingScale,
        allowComplexShadows,
        isLive,
        isBreaking,
        publishedAge,
      );
    }

    return MouseRegion(
      onEnter: enableHover ? (_) => _handleHover(true) : null,
      onExit: enableHover ? (_) => _handleHover(false) : null,
      onHover: enableParallax ? _updateParallax : null,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: _buildCardContent(
              context,
              isDark,
              selectionColor,
              cardSurfaceColor,
              borderColor,
              themeMode,
              blurSigma,
              enableHover,
              enableParallax,
              perf,
              uniformCardBackground,
              textScale,
              spacingScale,
              allowComplexShadows,
              isLive,
              isBreaking,
              publishedAge,
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
    AppThemeMode themeMode,
    double blurSigma,
    bool enableHover,
    bool enableParallax,
    PerformanceConfig perf,
    bool uniformCardBackground,
    double textScale,
    double spacingScale,
    bool allowComplexShadows,
    bool isLive,
    bool isBreaking,
    Duration publishedAge,
  ) {
    final loc = AppLocalizations.of(context);
    return Container(
      margin: ThemeSkeleton.shared.insetsSymmetric(vertical: 2 * spacingScale),
      decoration: BoxDecoration(
        borderRadius: ThemeSkeleton.shared.circular(24),
        boxShadow: !allowComplexShadows || !isDark || !enableHover
            ? const []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 10 * _elevationAnimation.value,
                  offset: Offset(0, 4 * _elevationAnimation.value),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: ThemeSkeleton.shared.circular(24),
        child: blurSigma > 0
            ? BackdropFilter(
                filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
                child: _buildInnerContent(
                  isDark,
                  cardSurfaceColor,
                  selectionColor,
                  borderColor,
                  themeMode,
                  perf,
                  loc,
                  uniformCardBackground,
                  textScale,
                  spacingScale,
                  isLive,
                  isBreaking,
                  publishedAge,
                ),
              )
            : _buildInnerContent(
                isDark,
                cardSurfaceColor,
                selectionColor,
                borderColor,
                themeMode,
                perf,
                loc,
                uniformCardBackground,
                textScale,
                spacingScale,
                isLive,
                isBreaking,
                publishedAge,
              ),
      ),
    );
  }

  Widget _buildInnerContent(
    bool isDark,
    Color cardSurfaceColor,
    Color selectionColor,
    Color borderColor,
    AppThemeMode themeMode,
    PerformanceConfig perf,
    AppLocalizations loc,
    bool uniformCardBackground,
    double textScale,
    double spacingScale,
    bool isLive,
    bool isBreaking,
    Duration publishedAge,
  ) {
    final isBangladesh = themeMode == AppThemeMode.bangladesh;
    final hasSolidSurface = cardSurfaceColor.alpha > 0;

    return Stack(
      children: [
        // Emerald keeps the dark glass shape, but uses a white bloom instead of red.
        if (isBangladesh && hasSolidSurface)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(
                    0.0,
                    -0.2,
                  ), // Slightly offset like the flag disk
                  radius: 0.8,
                  colors: [
                    Colors.white.withValues(alpha: 0.10),
                    Colors.white.withValues(alpha: 0.05),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        _buildActualInnerContent(
          isDark,
          cardSurfaceColor,
          selectionColor,
          borderColor,
          themeMode,
          perf,
          loc,
          uniformCardBackground,
          textScale,
          spacingScale,
          isLive,
          isBreaking,
          publishedAge,
        ),
      ],
    );
  }

  Widget _buildActualInnerContent(
    bool isDark,
    Color cardSurfaceColor,
    Color selectionColor,
    Color borderColor,
    AppThemeMode themeMode,
    PerformanceConfig perf,
    AppLocalizations loc,
    bool uniformCardBackground,
    double textScale,
    double spacingScale,
    bool isLive,
    bool isBreaking,
    Duration publishedAge,
  ) {
    final article = widget.article;
    final enableTapAnimation = _controller != null;
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
        borderRadius: ThemeSkeleton.shared.circular(24),
        border: Border.all(
          color: _resolveCardBorderColor(
            mode: themeMode,
            baseBorderColor: borderColor,
            isDark: isDark,
            isHighlighted: widget.highlight,
          ),
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enableTapAnimation ? null : widget.onTap,
          onTapDown: enableTapAnimation ? _onTapDown : null,
          onTapUp: enableTapAnimation ? _onTapUp : null,
          onTapCancel: enableTapAnimation ? _onTapCancel : null,
          borderRadius: ThemeSkeleton.shared.circular(24),
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
                  spacingScale,
                ),
              Padding(
                padding: ThemeSkeleton.shared.insetsSymmetric(
                  horizontal: 12 * textScale,
                  vertical: 10 * spacingScale,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTitle(isDark, selectionColor, textScale),
                    if (article.snippet.isNotEmpty && !perf.dataSaver) ...[
                      SizedBox(height: ThemeSkeleton.size6 * spacingScale),
                      _buildSnippet(isDark, textScale),
                    ],
                    if (taxonomyRow != null) ...[
                      SizedBox(height: ThemeSkeleton.size8 * spacingScale),
                      taxonomyRow,
                    ],
                    SizedBox(height: ThemeSkeleton.size10 * spacingScale),
                    _buildFooterRow(
                      logoPath,
                      selectionColor,
                      isDark,
                      perf,
                      textScale,
                      isLive,
                      isBreaking,
                      publishedAge,
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

  Color _resolveCardSurfaceColor(AppThemeMode mode, ThemeData theme) {
    switch (mode) {
      case AppThemeMode.bangladesh:
        return Colors.transparent;
      case AppThemeMode.dark:
        return Colors.transparent;
      case AppThemeMode.system:
        final brightness = theme.brightness;
        if (brightness == Brightness.dark) {
          return theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.96,
          );
        }
        return const Color(0xFFE2E5EA).withValues(alpha: 0.94);
    }
  }

  Color _resolveCardBorderColor({
    required AppThemeMode mode,
    required Color baseBorderColor,
    required bool isDark,
    required bool isHighlighted,
  }) {
    final highlightScale = isHighlighted ? 1.0 : 0.85;
    switch (mode) {
      case AppThemeMode.bangladesh:
        return Colors.white.withValues(alpha: 0.40 * highlightScale);
      case AppThemeMode.dark:
        return baseBorderColor.withValues(alpha: 0.58 * highlightScale);
      case AppThemeMode.system:
        final alpha = isDark ? 0.52 : 0.28;
        return baseBorderColor.withValues(alpha: alpha * highlightScale);
    }
  }

  Widget _buildTitle(bool isDark, Color selectionColor, double textScale) {
    return Text(
      widget.article.title,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 14.5 * textScale,
        height: 1.2,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.3,
        color: isDark ? Colors.white : Colors.black,
      ),
    );
  }

  Widget _buildSnippet(bool isDark, double textScale) {
    return Text(
      widget.article.snippet,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 12.0 * textScale,
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
    _ensureTaxonomyCache(loc);
    final chips = <Widget>[];
    final category = widget.article.category.trim().toLowerCase();

    if (widget.showCategoryBadge &&
        category.isNotEmpty &&
        _cachedLocalizedCategoryLabel != null) {
      chips.add(
        _buildTaxonomyChip(
          label: _cachedLocalizedCategoryLabel!,
          isDark: isDark,
          color: _colorForCategory(category, selectionColor),
        ),
      );
    }

    for (final tag in _cachedVisibleTaxonomyTags ?? const <String>[]) {
      chips.add(
        _buildTaxonomyChip(label: tag, isDark: isDark, color: selectionColor),
      );
    }

    if (chips.isEmpty) return null;
    return Wrap(spacing: 6, runSpacing: 6, children: chips);
  }

  void _ensureTaxonomyCache(AppLocalizations loc) {
    final category = widget.article.category.trim().toLowerCase();
    final tagsKey = (widget.article.tags ?? const <String>[]).join('||');
    final localeName = loc.localeName;

    if (_cachedTaxonomyLocale == localeName &&
        _cachedTaxonomyCategory == category &&
        _cachedTaxonomyTagsKey == tagsKey) {
      return;
    }

    _cachedTaxonomyLocale = localeName;
    _cachedTaxonomyCategory = category;
    _cachedTaxonomyTagsKey = tagsKey;
    _cachedLocalizedCategoryLabel = category.isEmpty
        ? null
        : _formatCategory(category, loc);
    _cachedVisibleTaxonomyTags = _visibleTags(
      widget.article.tags,
      loc,
      primaryCategory: category,
    );
  }

  List<String> _visibleTags(
    List<String>? rawTags,
    AppLocalizations loc, {
    required String primaryCategory,
  }) {
    if (rawTags == null || rawTags.isEmpty) return const <String>[];

    final labels = <String>[];
    final seenLabels = <String>{};
    final seenSemantics = <String>{};
    final normalizedPrimary = _canonicalTagSemanticValue(primaryCategory);

    for (final raw in rawTags) {
      final normalized = raw.trim().toLowerCase();
      if (normalized.isEmpty || normalized == 'premium') continue;

      final prefix = normalized.contains(':')
          ? normalized.split(':').first
          : '';
      if (_excludedTagPrefixes.contains(prefix)) continue;
      final semanticRaw = normalized.contains(':')
          ? normalized.split(':').sublist(1).join(':')
          : normalized;
      final semantic = _canonicalTagSemanticValue(semanticRaw);
      if (semantic.isEmpty) continue;
      if (_hiddenTagSemantics.contains(semantic)) continue;
      if (_isCategoryEquivalentSemantic(semantic, normalizedPrimary)) continue;
      if (!seenSemantics.add(semantic)) continue;

      final label = _formatTagLabel(normalized, loc);
      if (label.isEmpty || !seenLabels.add(label)) continue;
      labels.add(label);
      if (labels.length >= 2) break;
    }

    return labels;
  }

  bool _isCategoryEquivalentSemantic(String semantic, String categorySemantic) {
    final aliases =
        _categorySemanticAliases[categorySemantic] ??
        _categorySemanticAliases[_taxonomyAliases[categorySemantic] ?? ''] ??
        const <String>{};
    return aliases.contains(semantic);
  }

  Widget _buildTaxonomyChip({
    required String label,
    required bool isDark,
    required Color color,
  }) {
    return Container(
      padding: ThemeSkeleton.shared.insetsSymmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.18 : 0.12),
        borderRadius: ThemeSkeleton.shared.circular(999),
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

  String _canonicalTagSemanticValue(String rawValue) {
    final normalized = rawValue
        .trim()
        .toLowerCase()
        .replaceAll('-', ' ')
        .replaceAll('_', ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) return '';
    return _taxonomyAliases[normalized] ?? normalized;
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

  String _localizedPublisherName(AppLocalizations loc) {
    final source = (widget.article.sourceOverride ?? widget.article.source)
        .trim();
    if (source.isEmpty || !loc.localeName.startsWith('bn')) return source;

    final normalized = _normalizePublisherKey(source);
    return _bnPublisherFallback[normalized] ?? source;
  }

  static String _normalizePublisherKey(String source) {
    var normalized = source
        .trim()
        .toLowerCase()
        .replaceAll('&', ' and ')
        .replaceAll(RegExp(r'[^a-z0-9\u0980-\u09FF]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (normalized.startsWith('www ')) {
      normalized = normalized.substring(4);
    }
    if (normalized.endsWith(' com')) {
      normalized = normalized.substring(0, normalized.length - 4);
    }
    return normalized;
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
    double textScale,
    bool isLive,
    bool isBreaking,
    Duration publishedAge,
  ) {
    final article = widget.article;
    final l10n = AppLocalizations.of(context);

    String timestamp = '';
    try {
      if (publishedAge == Duration.zero) {
        timestamp = l10n.justNow;
      } else if (publishedAge.inMinutes < 60) {
        timestamp = l10n.minutesAgo(publishedAge.inMinutes);
      } else if (publishedAge.inHours < 24) {
        timestamp = l10n.hoursAgo(publishedAge.inHours);
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
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: selectionColor.withValues(alpha: 0.15),
              borderRadius: ThemeSkeleton.shared.circular(7),
              border: Border.all(color: selectionColor.withValues(alpha: 0.3)),
            ),
            child: Icon(Icons.public_rounded, size: 13, color: selectionColor),
          ),
        const SizedBox(width: ThemeSkeleton.size8),

        // Middle: Source Name & Time
        Expanded(
          child: DefaultTextStyle(
            style: TextStyle(
              fontSize: 11 * textScale,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.5)
                  : Colors.black.withValues(alpha: 0.5),
            ),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    _localizedPublisherName(l10n).toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Padding(
                  padding: ThemeSkeleton.shared.insetsSymmetric(horizontal: 4),
                  child: Text(
                    '•',
                    style: TextStyle(
                      fontSize: 10 * textScale,
                      color: selectionColor.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                Text(timestamp),
                if (isLive || isBreaking) ...[
                  const SizedBox(width: ThemeSkeleton.size6),
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
                final isFavorite = favState.articles.any(
                  (favorite) => favorite.url == article.url,
                );
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
                  size: 14 * textScale,
                  padding: ThemeSkeleton.shared.insetsAll(4),
                  innerPadding: ThemeSkeleton.shared.insetsAll(6),
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
            const SizedBox(width: ThemeSkeleton.size2),
            GlassIconButton(
              icon: Icons.share_rounded,
              onPressed: () async {
                await SmartShareService.shareArticle(article);
              },
              isDark: isDark,
              size: 14 * textScale,
              padding: ThemeSkeleton.shared.insetsAll(4),
              innerPadding: ThemeSkeleton.shared.insetsAll(6),
              semanticsLabel: l10n.share,
            ),
          ],
        ),
      ],
    );
  }
}
