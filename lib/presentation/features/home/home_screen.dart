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
import '../../../core/di/providers.dart' show hiveServiceProvider;
import '../../providers/network_providers.dart';
import '../../../core/theme.dart';
import '../../../core/design_tokens.dart';
import '../../../core/performance_config.dart';
import '../../../core/offline_handler.dart';
import '../../../../domain/entities/news_article.dart';
import '../../../../infrastructure/network/app_network_service.dart';
import '../../../core/architecture/failure.dart' show AppFailure;
import '../../widgets/app_drawer.dart';
import '../../widgets/error_widget.dart';
import '../../widgets/animated_theme_container.dart';
import 'widgets/news_card.dart';
import 'widgets/shimmer_loading.dart';
import 'widgets/professional_header.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../widgets/glass_icon_button.dart';
import '../../widgets/premium_theme_icon.dart';
import '../common/app_bar.dart';
import '../../../../infrastructure/services/interstitial_ad_service.dart';
import '../../widgets/unlock_article_dialog.dart';
import '../../widgets/glass_container.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const String _latestKey = 'latest';

  static const List<String> categories = [
    'national',
    'international',
    'sports',
    'entertainment',
  ];


  AppLocalizations get loc => AppLocalizations.of(context);
  bool _isOffline = false;
  bool _showOfflineBanner = false;
  bool _isAppInForeground = true;
  late final Map<String, ScrollController> _scrollControllers;
  late TabController _tabController;
  late AnimationController _scrollAnimationController;
  List<Particle> _backgroundParticles = [];
  Timer? _refreshTimer;
  Timer? _offlineBannerTimer;
  bool _reduceEffects = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: categories.length, vsync: this);
    _tabController.addListener(_handleTabChange);
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
    _scrollControllers = {
      for (final c in categories)
        c: ScrollController()..addListener(() => _handleScroll(c)),
    };
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
      if (next == 0 && _currentScrollController().hasClients) {
        _scrollToTop();
      }
    });

    ref.listenManual<String>(homeCategoryProvider, (previous, next) {
      if (previous != next) {
        final index = categories.indexOf(next);
        if (index != -1) {
          _tabController.animateTo(index);
        }
      }
    });
  }

  void _handleTabChange() {
    if (!_tabController.indexIsChanging) {
      final category = categories[_tabController.index];
      ref.read(homeCategoryProvider.notifier).state = category;
      _loadNews();
    }
  }

  ScrollController _currentScrollController() {
    final category = ref.read(homeCategoryProvider);
    return _scrollControllers[category] ?? _scrollControllers[categories.first]!;
  }

  void _handleScroll(String category) {
    if (!mounted) return;

    // Only react for the currently selected tab.
    if (category != ref.read(homeCategoryProvider)) return;

    final controller = _scrollControllers[category];
    if (controller == null || !controller.hasClients) return;

    final scrollPosition = controller.position;
    final scrollOffset = scrollPosition.pixels;
    final maxScroll = scrollPosition.maxScrollExtent;
    final isNearBottom = scrollOffset > maxScroll * 0.7;

    if (isNearBottom && !ref.read(newsProvider).isLoading(category)) {
      _loadMoreNews(category: category);
    }
  }

  void _scrollToTop() {
    final controller = _currentScrollController();
    if (controller.hasClients) {
      _scrollAnimationController.forward(from: 0).then((_) {
        controller.animateTo(
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
      ref.read(hiveServiceProvider).init(<String>[_latestKey]).catchError((e) {
        debugPrint('⚠️ Hive initialization failed: $e');
      });

      if (mounted) {
        // Load initial news for the current category (defaults to national)
        _loadNews();
        _setupAutoRefresh();
      }
    });
  }

  Future<void> _loadNews({bool force = false, String? category}) async {
    if (!mounted) return;
    final Locale locale = ref.read(currentLocaleProvider);
    final targetCategory = category ?? ref.read(homeCategoryProvider);
    
    await ref
        .read(newsProvider.notifier)
        .loadNews(targetCategory!, locale, force: force);
  }

  Future<void> _loadMoreNews({String? category}) async {
    if (!mounted) return;
    final Locale locale = ref.read(currentLocaleProvider);
    final targetCategory =
        category ?? ref.read(homeCategoryProvider) ?? categories.first;
    await ref.read(newsProvider.notifier).loadMoreNews(targetCategory, locale);
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
    final controller = _currentScrollController();

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final showButton = controller.hasClients && controller.offset > 300;

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
    for (final c in _scrollControllers.values) {
      c.dispose();
    }
    _refreshTimer?.cancel();
    _offlineBannerTimer?.cancel();
    _scrollAnimationController.dispose();
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
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

    final category = ref.watch(homeCategoryProvider);
    final List<NewsArticle> displayList = newsState.getArticles(category);
    
    final bool isLoading = newsState.isLoading(category);
    final String? error = newsState.getError(category);
    final bool hasMore = newsState.hasMore(category);

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
                    start.withOpacity(0.9),
                    end.withOpacity(0.9),
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
                const SizedBox(height: 70), // Adjusted for cleaner app bar

                // AI Category Tabs - Enhanced Styling
                _buildCategoryTabs(context, loc),

                const SizedBox(height: 8), // Added consistent spacing

                // Offline banner - Enhanced
                if (_showOfflineBanner)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: GlassContainer(
                      borderColor: Colors.orange.withOpacity(0.5),
                      backgroundColor: Colors.orange.withOpacity(0.1),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Icon(Icons.wifi_off_rounded, color: Colors.orange.shade300, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                loc.offlineShowingCached,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _showOfflineBanner = false;
                                });
                              },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                AppLocalizations.of(context).ok,
                                style: TextStyle(
                                  color: Colors.orange.shade300,
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
                  child: TabBarView(
                    controller: _tabController,
                    children: categories.map((cat) {
                      final List<NewsArticle> displayList = newsState.getArticles(cat);
                      final bool isLoading = newsState.isLoading(cat);
                      final String? error = newsState.getError(cat);
                      final bool hasMore = newsState.hasMore(cat);

                      return _buildCategoryContent(
                        context,
                        cat,
                        displayList,
                        isLoading,
                        error,
                        hasMore,
                        loc,
                        theme,
                      );
                    }).toList(),
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

          // Custom Glass AppBar - Enhanced
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
    height: topPadding + 60, // Slightly reduced height
    child: Stack(
      children: [
        // 1. Visual Background (Ignored for hit tests)
        IgnorePointer(
          child: Container(
            height: topPadding + 60,
            decoration: reduceEffects
                ? BoxDecoration(
                    color: baseColor.withOpacity(0.94),
                  )
                : BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        colors[0].withOpacity(0.98),
                        colors[0].withOpacity(0.85),
                        colors[0].withOpacity(0.6),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.4, 0.7, 1.0],
                    ),
                  ),
            child: reduceEffects
                ? const SizedBox.shrink()
                : ClipRect(
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20), // Reduced blur for cleaner look
                      child: Container(color: Colors.transparent),
                    ),
                  ),
          ),
        ),
        
        // 2. Interactive Layer
        SafeArea(
          bottom: false,
          child: SizedBox(
            height: 60,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  GlassIconButton(
                    icon: Icons.menu_rounded,
                    onPressed: () {
                      Scaffold.of(context).openDrawer();
                    },
                    isDark: theme.brightness == Brightness.dark,
                  ),
                  Expanded(
                    child: IgnorePointer(
                      child: Center(
                        child: Text(
                          loc.homeTitle,
                          style: TextStyle(
                            fontSize: 18, // Consistent sizing
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface.withOpacity(0.95),
                            letterSpacing: -0.5,
                          ),
                        ),
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

Widget _buildCategoryTabs(BuildContext context, AppLocalizations loc) {
  final theme = Theme.of(context);
  final locale = ref.watch(currentLocaleProvider);
  final isBangla = locale.languageCode == 'bn';
  
  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 16),
    height: 48, // Fixed height for consistency
    decoration: BoxDecoration(
      color: theme.colorScheme.onSurface.withOpacity(0.05),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: theme.colorScheme.onSurface.withOpacity(0.08),
        width: 1,
      ),
    ),
    child: TabBar(
      controller: _tabController,
      indicator: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      indicatorSize: TabBarIndicatorSize.tab,
      labelColor: theme.colorScheme.primary,
      unselectedLabelColor: theme.colorScheme.onSurface.withOpacity(0.6),
      labelStyle: const TextStyle(
        fontSize: 12, // Slightly smaller for elegance
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      ),
      unselectedLabelStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.3,
      ),
      indicatorPadding: const EdgeInsets.all(4),
      dividerColor: Colors.transparent, // Remove default divider
      tabs: [
        Tab(child: _buildTabContent(isBangla ? 'জাতীয়' : 'National', Icons.flag_rounded)),
        Tab(child: _buildTabContent(isBangla ? 'আন্তর্জাতিক' : 'International', Icons.public_rounded)),
        Tab(child: _buildTabContent(isBangla ? 'খেলা' : 'Sports', Icons.sports_soccer_rounded)),
        Tab(child: _buildTabContent(isBangla ? 'বিনোদন' : 'Entertainment', Icons.movie_rounded)),
      ],
    ),
  );
}

Widget _buildTabContent(String label, IconData icon) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(icon, size: 14),
      const SizedBox(width: 6), // Slightly more spacing
      Flexible(
        child: Text(
          label,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ),
    ],
  );
}

Widget _buildCategoryContent(
  BuildContext context,
  String category,
  List<NewsArticle> displayList,
  bool isLoading,
  String? error,
  bool hasMore,
  AppLocalizations loc,
  ThemeData theme,
) {
  return NotificationListener<ScrollNotification>(
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
      displacement: 60, // Add displacement for better visual
      child: CustomScrollView(
        controller: _scrollControllers[category],
        key: PageStorageKey('home_scroll_$category'),
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
                  vertical: 8, // Increased spacing
                ),
                child: GlassContainer(
                  borderColor: Colors.red.withOpacity(0.5),
                  backgroundColor: Colors.red.withOpacity(0.1),
                  child: ErrorDisplay(
                    error: AppFailure.serverError(error),
                    onRetry: _loadNews,
                  ),
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 8)),

          // Header
          SliverToBoxAdapter(
            child: ProfessionalHeader(
              articleCount: displayList.length,
              category: category == 'national' ? null : category,
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 8)),

          // Loading shimmer
          if (isLoading && displayList.isEmpty)
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
                        _getCategoryIcon(category),
                        size: 64,
                        color: Colors.white.withOpacity(0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _getEmptyMessage(category, loc),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white.withOpacity(0.5),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _loadNews,
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text(loc.retry),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary.withOpacity(0.9),
                          foregroundColor: theme.colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0, // Flat design
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
                        index == 0 ? 4 : 6, // Reduced vertical spacing between cards
                        16,
                        index == displayList.length - 1 ? 16 : 6,
                      ),
                      child: NewsCard(
                        key: ValueKey('${category}_${displayList[index].url}_$index'),
                        article: displayList[index],
                        onTap: () => _handleArticleTap(displayList[index]),
                      ),
                    );
                  } else if (hasMore) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator.adaptive(
                            strokeWidth: 2.5, // Thinner for elegance
                            valueColor: AlwaysStoppedAnimation(
                              theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                    );
                  } else {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 48, top: 24),
                      child: Center(
                        child: Text(
                          loc.endOfNews,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withOpacity(0.4), // Lighter for subtlety
                            fontStyle: FontStyle.italic,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  }
                },
                childCount: displayList.length + (hasMore ? 1 : (displayList.isEmpty ? 0 : 1)),
              ),
            ),
        ],
      ),
    ),
  );
}

IconData _getCategoryIcon(String category) {
  switch (category) {
    case 'national':
      return Icons.flag_rounded;
    case 'international':
      return Icons.public_rounded;
    case 'sports':
      return Icons.sports_soccer_rounded;
    case 'entertainment':
      return Icons.movie_rounded;
    default:
      return Icons.article_rounded;
  }
}

String _getEmptyMessage(String category, AppLocalizations loc) {
  switch (category) {
    case 'national':
      return loc.noNationalNews;
    case 'international':
      return loc.noInternationalNews;
    case 'sports':
      return loc.noSportsNews;
    case 'entertainment':
      return loc.noEntertainmentNews;
    default:
      return loc.noArticlesFound;
  }
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