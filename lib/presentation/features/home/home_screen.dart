import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/app_paths.dart';
import '../../providers/news_providers.dart';
import '../../providers/tab_providers.dart';
import '../../providers/language_providers.dart';
import '../../providers/theme_providers.dart';
import '../../providers/app_settings_providers.dart';
import '../../providers/network_providers.dart';
import '../../../core/theme.dart';
import '../../../core/design_tokens.dart';
import '../../../core/performance_config.dart';
import '../../../core/offline_handler.dart';
import '../../../../domain/entities/news_article.dart';
import '../../../../infrastructure/services/hive_service.dart';
import '../../../../infrastructure/network/app_network_service.dart';
import '../../../core/architecture/failure.dart' show AppFailure;
import '../../widgets/app_drawer.dart';
import '../../widgets/error_widget.dart';
import '../../widgets/animated_theme_container.dart';
import 'widgets/news_card.dart';
import 'widgets/shimmer_loading.dart';
import 'widgets/professional_header.dart';
import 'widgets/breaking_news_ticker.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../widgets/glass_icon_button.dart';
import '../../widgets/premium_theme_icon.dart';
import '../common/app_bar.dart';
import '../../../../infrastructure/services/interstitial_ad_service.dart';
import '../../widgets/unlock_article_dialog.dart';
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const String _latestKey = 'latest';


  bool _isOffline = false;
  bool _showOfflineBanner = false;
  bool _isAppInForeground = true;
  final ScrollController _scrollController = ScrollController();
  late AnimationController _scrollAnimationController;
  List<Particle> _backgroundParticles = [];
  Timer? _refreshTimer;
  Timer? _offlineBannerTimer;
  bool _reduceEffects = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeAnimations();
    _initConnectivity();
    _setupListeners();
    _initializeApp();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final perf = PerformanceConfig.of(context);
    if (perf.reduceEffects != _reduceEffects) {
      _reduceEffects = perf.reduceEffects;
      if (!_reduceEffects && _backgroundParticles.isEmpty) {
        _initializeParticles();
      }
    }
  }

  void _initializeAnimations() {
    _scrollAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  void _initializeParticles() {
    if (_reduceEffects) return;
    final random = math.Random();
    // Reduced from 20 to 10 particles for better battery performance
    _backgroundParticles = List.generate(10, (index) {
      final double size = random.nextDouble() * 3 + 1;
      final double speed = random.nextDouble() * 0.2 + 0.1;
      final double delay = random.nextDouble() * 2;
      return Particle(
        x: random.nextDouble(),
        y: random.nextDouble(),
        size: size,
        speed: speed,
        delay: delay,
        color: Colors.white.withOpacity(random.nextDouble() * 0.15 + 0.05),
      );
    });
  }

  void _setupListeners() {
    ref.listenManual<Locale>(currentLocaleProvider, (previous, next) {
      if (previous != null && previous != next) {
        debugPrint(
          '🌐 Language changed from ${previous.languageCode} to ${next.languageCode} - reloading news',
        );
        _loadNews(force: true);
      }
    });

    ref.listenManual<bool>(dataSaverProvider, (previous, next) {
      if (previous != null && previous != next) {
        _setupAutoRefresh();
      }
    });

    ref.listenManual<NetworkQuality>(networkQualityProvider, (previous, next) {
      if (previous != null && previous != next) {
        _setupAutoRefresh();
      }
    });

    ref.listenManual<int>(currentTabIndexProvider, (previous, next) {
      if (next == 0 && _scrollController.hasClients) {
        _scrollToTop();
      }
    });

    _scrollController.addListener(_handleScroll);
  }

  void _handleScroll() {
    if (!mounted) return;

    final scrollPosition = _scrollController.position;
    final scrollOffset = scrollPosition.pixels;
    final maxScroll = scrollPosition.maxScrollExtent;
    final isNearBottom = scrollOffset > maxScroll * 0.7;

    if (isNearBottom && !ref.read(newsProvider).isLoading(_latestKey)) {
      _loadMoreNews();
    }
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollAnimationController.forward(from: 0).then((_) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      });
    }
  }

  void _initConnectivity() async {
    _isOffline = await OfflineHandler.isOffline();
    OfflineHandler().onConnectivityChanged.listen((bool offline) {
      if (mounted) {
        setState(() => _isOffline = offline);
        
        if (offline) {
          _showOfflineBanner = true;
          _offlineBannerTimer?.cancel();
          _offlineBannerTimer = Timer(const Duration(seconds: 5), () {
            if (mounted) setState(() => _showOfflineBanner = false);
          });
        } else {
          _showOfflineBanner = false;
          _loadNews(force: true);
        }
      }
    });
  }

  Future<void> _initializeApp() async {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      HiveService.init(<String>[_latestKey]).catchError((e) {
        debugPrint('⚠️ Hive initialization failed: $e');
      });

      if (mounted) {
        _loadNews();
        _setupAutoRefresh();
      }
    });
  }

  Future<void> _loadNews({bool force = false}) async {
    if (!mounted) return;
    final Locale locale = ref.read(currentLocaleProvider);
    debugPrint('📰 Loading news for locale: ${locale.languageCode}');
    
    await ref
        .read(newsProvider.notifier)
        .loadNews(_latestKey, locale, force: force);
  }

  Future<void> _loadMoreNews() async {
    if (!mounted) return;
    final Locale locale = ref.read(currentLocaleProvider);
    await ref
        .read(newsProvider.notifier)
        .loadMoreNews(_latestKey, locale);
  }

  void _setupAutoRefresh() {
    _refreshTimer?.cancel();
    // Only run auto-refresh when app is in foreground to save battery
    if (_isAppInForeground) {
      final bool dataSaver = ref.read(dataSaverProvider);
      final NetworkQuality quality = ref.read(networkQualityProvider);
      Duration interval = dataSaver
          ? const Duration(hours: 1)
          : const Duration(minutes: 30);

      if (quality == NetworkQuality.poor || quality == NetworkQuality.offline) {
        interval = const Duration(hours: 2);
      } else if (quality == NetworkQuality.fair && !dataSaver) {
        interval = const Duration(minutes: 45);
      }

      _refreshTimer = Timer.periodic(interval, (timer) {
        if (mounted && !_isOffline && _isAppInForeground) {
          _loadNews();
        }
      });
    }
  }

  Future<void> _handleArticleTap(NewsArticle article) async {
    final bool isPremiumContent = article.tags?.contains('premium') == true;

    if (isPremiumContent) {
      final bool unlocked = await showUnlockDialog(
        context,
        article.url,
        article.title,
      );
      if (!unlocked) return;
    }

    // Trigger ad logic (respects premium status internally)
    InterstitialAdService().onArticleViewed();

    if (!mounted) return;
    context.push(
      AppPaths.newsDetail,
      extra: article,
    );
  }

  Widget _buildParticleBackground() {
    if (_reduceEffects) {
      return const SizedBox.shrink();
    }
    return CustomPaint(
      painter: _HomeParticlePainter(
        particles: _backgroundParticles,
        animationValue: 0.5,
      ),
    );
  }

  Widget _buildScrollToTopButton() {
    final selectionColor = ref.watch(navIconColorProvider);
    
    return AnimatedBuilder(
      animation: _scrollController,
      builder: (context, child) {
        final showButton = _scrollController.hasClients &&
            _scrollController.offset > 300;

        return AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: showButton ? 1.0 : 0.0,
          child: IgnorePointer(
            ignoring: !showButton,
            child: Transform.scale(
              scale: showButton ? 1.0 : 0.8,
              child: GlassContainer(
                margin: const EdgeInsets.all(16),
                borderRadius: BorderRadius.circular(50),
                child: IconButton(
                  onPressed: _scrollToTop,
                  icon: const PremiumThemeIcon(
                    Icons.arrow_upward_rounded,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: selectionColor.withOpacity(0.2),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        // App is backgrounded - cancel timers to save battery
        _isAppInForeground = false;
        _refreshTimer?.cancel();
        break;
      
      case AppLifecycleState.resumed:
        // App is foregrounded - resume timers
        _isAppInForeground = true;
        _setupAutoRefresh();
        break;
      
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _offlineBannerTimer?.cancel();
    _scrollAnimationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations loc = AppLocalizations.of(context);
    final themeMode = ref.watch(currentThemeModeProvider);
    final newsState = ref.watch(newsProvider);
    final theme = Theme.of(context);
    final bool reduceEffects = PerformanceConfig.of(context).reduceEffects;
    final List<Color> colors = AppGradients.getBackgroundGradient(themeMode);
    final Color start = colors[0];
    final Color end = colors[1];

    final List<NewsArticle> allArticles = newsState.getArticles(_latestKey);
    final List<NewsArticle> tickerArticles = allArticles.take(5).toList();
    final List<NewsArticle> displayList = allArticles.skip(5).toList();
    
    final bool isLoading = newsState.isLoading(_latestKey);
    final String? error = newsState.getError(_latestKey);
    final bool hasMore = newsState.hasMore(_latestKey);

    return Scaffold(
      backgroundColor: Colors.transparent,
      drawer: const AppDrawer(),
      body: Builder(
        builder: (scaffoldContext) => Stack(
          children: <Widget>[
          // Background with particles
          Positioned.fill(
            child: AnimatedThemeContainer(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    start.withOpacity(0.85),
                    end.withOpacity(0.85),
                  ],
                ),
              ),
              child: RepaintBoundary(
                child: _buildParticleBackground(),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: <Widget>[
                const SizedBox(height: 66), // Increased from 52 to clear 64px app bar

                // Breaking news ticker
                if (tickerArticles.isNotEmpty)
                  BreakingNewsTicker(articles: tickerArticles),
                // Offline banner
                if (_showOfflineBanner)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2), // Reduced from 4
                    child: GlassContainer(
                      borderColor: Colors.orange,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            const Icon(Icons.wifi_off_rounded, color: Colors.orange),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                loc.offlineShowingCached,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                Expanded(
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      if (notification is ScrollUpdateNotification) {
                        // Handle scroll updates if needed
                      }
                      return false;
                    },
                    child: RefreshIndicator.adaptive(
                      onRefresh: () => _loadNews(force: true),
                      color: theme.colorScheme.primary,
                      backgroundColor: theme.colorScheme.surface,
                      strokeWidth: 3.0,
                      child: CustomScrollView(
                        controller: _scrollController,
                        key: const PageStorageKey('home_scroll'),
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        slivers: <Widget>[
                          // Error banner
                          if (error != null && !_isOffline)
                            SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md,
                                    vertical: 4,
                                  ),
                                child: GlassContainer(
                                  borderColor: Colors.red,
                                  child: ErrorDisplay(
                                    error: AppFailure.serverError(error),
                                    onRetry: _loadNews,
                                  ),
                                ),
                              ),
                            ),

                          const SliverToBoxAdapter(child: SizedBox(height: 4)), // Reduced to 4 (50% from 8)

                          // Header
                          SliverToBoxAdapter(
                              child: ProfessionalHeader(articleCount: allArticles.length),
                          ),

                          const SliverToBoxAdapter(child: SizedBox(height: 4)), // Reduced to 4 (50% from 8)

                          // Loading shimmer
                          if (isLoading && allArticles.isEmpty)
                            const SliverToBoxAdapter(
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: ShimmerLoading(),
                              ),
                            )
                          // Empty state
                          else if (displayList.isEmpty && error == null)
                            SliverFillRemaining(
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(32),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.article_rounded,
                                        size: 64,
                                        color: theme.colorScheme.onSurface.withOpacity(0.3),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        loc.noArticlesFound,
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        loc.checkConnection,
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          color: theme.colorScheme.onSurface.withOpacity(0.4),
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      ElevatedButton.icon(
                                        onPressed: _loadNews,
                                        icon: const Icon(Icons.refresh_rounded),
                                        label: Text(loc.retry),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: theme.colorScheme.primary,
                                          foregroundColor: theme.colorScheme.onPrimary,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 24,
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          // Articles list
                          else
                            SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  if (index < displayList.length) {
                                    return Padding(
                                      padding: EdgeInsets.fromLTRB(
                                        16,
                                        index == 0 ? 0 : 2, // Gap reduced by 50% (from 4 to 2)
                                        16,
                                        index == displayList.length - 1 ? 8 : 2, // Bottom padding reduced from 12 to 8
                                      ),
                                      child: NewsCard(
                                        key: ValueKey('${displayList[index].url}_$index'),
                                        article: displayList[index],
                                        onTap: () => _handleArticleTap(displayList[index]),
                                      ),
                                    );
                                  } else if (hasMore) {
                                    // Loading more indicator
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 24),
                                      child: Center(
                                        child: CircularProgressIndicator.adaptive(
                                          valueColor: AlwaysStoppedAnimation(
                                            theme.colorScheme.primary,
                                          ),
                                        ),
                                      ),
                                    );
                                  } else {
                                    // End of list indicator
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 48),
                                      child: Center(
                                        child: Text(
                                          loc.endOfNews,
                                          style: theme.textTheme.bodyMedium?.copyWith(
                                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                },
                                childCount: displayList.length + (hasMore ? 1 : 1),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Scroll to top button
          Positioned(
            bottom: 116,
            right: 20,
            child: _buildScrollToTopButton(),
          ),

          // Custom Glass AppBar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildCustomAppBar(
              scaffoldContext,
              theme,
              loc,
              colors,
              reduceEffects: reduceEffects,
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildCustomAppBar(
  BuildContext context,
  ThemeData theme,
  AppLocalizations loc,
  List<Color> colors, {
  required bool reduceEffects,
}) {
  final double topPadding = MediaQuery.of(context).padding.top;
  final Color baseColor =
      theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface;
  
  return SizedBox(
    height: topPadding + 64,
    child: Stack(
      children: [
        // 1. Visual Background (Ignored for hit tests)
        IgnorePointer(
          child: Container(
            height: topPadding + 64,
            decoration: reduceEffects
                ? BoxDecoration(
                    color: baseColor.withOpacity(0.94),
                  )
                : BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        colors[0].withOpacity(0.9),
                        colors[0].withOpacity(0.6),
                        Colors.transparent,
                      ],
                    ),
                  ),
            child: reduceEffects
                ? const SizedBox.shrink()
                : ClipRect(
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(color: Colors.transparent),
                    ),
                  ),
          ),
        ),
        
        // 2. Interactive Layer
        SafeArea(
          bottom: false,
          child: SizedBox(
            height: 64,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  GlassIconButton(
                    icon: Icons.menu_rounded,
                    onPressed: () {
                      print('>>> HOME SCREEN: Drawer button pressed');
                      Scaffold.of(context).openDrawer();
                    },
                    isDark: theme.brightness == Brightness.dark,
                  ),
                  const Expanded(
                    child: IgnorePointer(
                      child: Center(
                        child: AppBarTitle('BD NewsReader'),
                      ),
                    ),
                  ),
                  GlassIconButton(
                    icon: Icons.refresh_rounded,
                    onPressed: () {
                      print('>>> HOME SCREEN: Refresh button pressed');
                      _loadNews(force: true);
                    },
                    isDark: theme.brightness == Brightness.dark,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
}

class _HomeParticlePainter extends CustomPainter {
  _HomeParticlePainter({
    required this.particles,
    required this.animationValue,
  });

  final List<Particle> particles;
  final double animationValue;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill;

    for (final particle in particles) {
      final time = animationValue + particle.delay;
      final offsetY = (particle.y + time * particle.speed) % 1.0;
      final opacity = particle.color.opacity *
          (0.5 + 0.5 * math.sin(time * 2 * math.pi + particle.x * math.pi));
      final currentSize = particle.size *
          (1 + 0.2 * math.sin(time * 2 * math.pi + particle.delay * math.pi));

      paint.color = particle.color.withOpacity(opacity);

      canvas.drawCircle(
        Offset(particle.x * size.width, offsetY * size.height),
        currentSize,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HomeParticlePainter oldDelegate) {
    // Only repaint if the animation is actually running
    return animationValue != oldDelegate.animationValue;
  }
}

class Particle {
  Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.delay,
    required this.color,
  });

  final double x;
  final double y;
  final double size;
  final double speed;
  final double delay;
  final Color color;
}
