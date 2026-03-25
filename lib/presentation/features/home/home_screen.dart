import 'dart:async';
import 'dart:io';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import '../../../core/di/providers.dart' hide networkQualityProvider;
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/navigation/app_paths.dart';
import '../../providers/news_providers.dart';
import '../../providers/tab_providers.dart';
import '../../providers/language_providers.dart';
import '../../providers/theme_providers.dart';
import '../../providers/app_settings_providers.dart';
import '../../providers/feature_providers.dart' show assetsLoaderProvider;
import '../../providers/network_providers.dart';
import '../../../core/enums/theme_mode.dart';
import '../../../core/theme/theme.dart';
import '../../../core/config/performance_config.dart';
import '../../../core/persistence/offline_handler.dart';
import '../../../../domain/entities/news_article.dart';
import '../../../../infrastructure/network/app_network_service.dart';
import '../../../core/architecture/failure.dart' show AppFailure;
import '../../widgets/app_drawer.dart';
import '../../widgets/error_widget.dart';
import '../../widgets/animated_theme_container.dart';
import 'widgets/news_card.dart';
import 'widgets/professional_header.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../widgets/glass_icon_button.dart';
import '../../widgets/premium_theme_icon.dart';
import '../../widgets/unlock_article_dialog.dart';
import '../../widgets/category_chips_bar.dart';
import '../common/news_detail_args.dart';
import 'widgets/news_feed_skeleton.dart';

// ── Pre-computed constants so nothing is created at runtime ──────────────────

const List<String> _kCategories = <String>['latest', 'trending'];

const Map<String, IconData> _kCategoryIcons = {
  'latest': Icons.newspaper_rounded,
  'trending': Icons.trending_up_rounded,
};

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final TabController _tabController;
  late final Map<String, bool> _loadMoreInFlight = {};
  late final ScrollController _chipsScrollController;
  late final List<GlobalKey> _chipKeys;

  final ValueNotifier<bool> _showScrollToTop = ValueNotifier(false);

  List<Particle>? _particles; // null until first needed
  late final AnimationController _particleController;
  bool _particlesEnabled = false;

  bool _isOffline = false;
  bool _showOfflineBanner = false;
  bool _isAppInForeground = true;
  Timer? _refreshTimer;
  Timer? _offlineBannerTimer;
  Timer? _deferredStartupSyncTimer;
  StreamSubscription<bool>? _connectivitySub;
  final List<ProviderSubscription<dynamic>> _providerSubscriptions =
      <ProviderSubscription<dynamic>>[];
  bool _primeInFlight = false;
  bool _pendingPrimeAfterLocaleChange = false;
  bool _startupCachePrimed = false;
  DateTime? _lastPrimeCompletedAt;

  // ── Cached heavy colors (recomputed only on theme change) ────────────────
  Color? _cachedGradientStart;
  Color? _cachedGradientEnd;
  AppThemeMode? _cachedGradientMode;

  AppLocalizations get loc => AppLocalizations.of(context);
  String get _activeCategory => _kCategories[_tabController.index];

  void _diag(String message) {
    if (!kDebugMode) return;
    debugPrint(message);
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    final savedCategory = ref.read(homeCategoryProvider);
    final initialIndex = _kCategories.indexOf(savedCategory);
    _diag(
      '🏠 [startup_diag] Home init category | saved=$savedCategory, initialIndex=$initialIndex, fallback=${initialIndex >= 0 ? _kCategories[initialIndex] : _kCategories.first}',
    );

    _tabController = TabController(
      length: _kCategories.length,
      vsync: this,
      initialIndex: initialIndex >= 0 ? initialIndex : 0,
    );
    _tabController.addListener(_onTabChanged);
    if (initialIndex < 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref
              .read(homeCategoryProvider.notifier)
              .setCategory(_kCategories.first);
        }
      });
    }

    _chipsScrollController = ScrollController();
    _chipKeys = [];
    for (int i = 0; i < _kCategories.length; i++) {
      _chipKeys.add(GlobalKey());
    }

    // Particles: a single, very-slow ticker – only drives repaints, not logic
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    );

    _initConnectivity();
    _setupProviderListeners();

    // Defer heavy work until first frame is on screen
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_initializeApp());
      _maybeEnableParticles();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeEnableParticles();
  }

  void _maybeEnableParticles() {
    final perf = PerformanceConfig.of(context);
    final enabled =
        !perf.reduceEffects &&
        !perf.reduceMotion &&
        !perf.lowPowerMode &&
        !perf.isLowEndDevice &&
        perf.performanceTier == DevicePerformanceTier.flagship;
    if (enabled == _particlesEnabled) return;
    _particlesEnabled = enabled;
    if (enabled) {
      _particles ??= _buildParticles();
      _particleController.repeat();
      if (kDebugMode && Platform.environment.containsKey('FLUTTER_TEST')) {
        _particleController.stop();
      }
    } else {
      _particleController.stop();
    }
  }

  List<Particle> _buildParticles() {
    final rng = math.Random();
    return List.generate(
      6,
      (_) => Particle(
        // Keep density low to preserve battery and thermals.
        x: rng.nextDouble(),
        y: rng.nextDouble(),
        size: rng.nextDouble() * 3 + 1,
        speed: rng.nextDouble() * 0.10 + 0.03,
        delay: rng.nextDouble() * 2,
        color: Colors.white.withValues(alpha: rng.nextDouble() * 0.12 + 0.04),
      ),
    );
  }

  void _setupProviderListeners() {
    // All listeners use listenManual so they don't force rebuilds of the whole tree
    _providerSubscriptions.add(
      ref.listenManual<Locale>(currentLocaleProvider, (prev, next) {
        if (!mounted) return;
        if (prev != null && prev != next) {
          // Locale flips can happen while initial prime is in-flight.
          // Queue one forced prime so the active feed always matches locale.
          if (_primeInFlight) {
            _pendingPrimeAfterLocaleChange = true;
            return;
          }
          unawaited(_primeHomeCategories(force: true));
        }
      }),
    );

    _providerSubscriptions.add(
      ref.listenManual<bool>(dataSaverProvider, (prev, next) {
        if (!mounted) return;
        if (prev != null && prev != next) _setupAutoRefresh();
      }),
    );

    _providerSubscriptions.add(
      ref.listenManual<NetworkQuality>(networkQualityProvider, (prev, next) {
        if (!mounted) return;
        if (prev != null && prev != next) _setupAutoRefresh();
      }),
    );

    _providerSubscriptions.add(
      ref.listenManual<int>(currentTabIndexProvider, (prev, next) {
        if (!mounted) return;
        if (next == 0) _scrollToTop();
      }),
    );

    _providerSubscriptions.add(
      ref.listenManual<String>(homeCategoryProvider, (prev, next) {
        if (!mounted) return;
        if (_kCategories.length <= 1) return;
        if (prev != next) {
          final idx = _kCategories.indexOf(next);
          if (idx != -1 && _tabController.index != idx) {
            _tabController.animateTo(idx);
          }
        }
      }),
    );
  }

  void _initConnectivity() async {
    _isOffline = await OfflineHandler.isOffline();
    _connectivitySub = OfflineHandler().onConnectivityChanged.listen((offline) {
      if (!mounted) return;
      setState(() => _isOffline = offline);
      if (offline) {
        _showOfflineBanner = true;
        _offlineBannerTimer?.cancel();
        _offlineBannerTimer = Timer(const Duration(seconds: 5), () {
          if (mounted) setState(() => _showOfflineBanner = false);
        });
      } else {
        if (_showOfflineBanner) setState(() => _showOfflineBanner = false);
        if (_startupCachePrimed) {
          _loadNews();
        }
      }
    });
  }

  Future<void> _initializeApp() async {
    _isOffline = await OfflineHandler.isOffline();
    if (!mounted) return;
    ref.read(hiveServiceProvider).init(_kCategories).catchError((e) {
      debugPrint('⚠️ Hive init failed: $e');
    });
    // Pre-warm static publisher datasets so newspaper/magazine screens open fast.
    unawaited(ref.read(assetsLoaderProvider).loadData());

    // Startup must stay cache-first to avoid network pressure before first
    // interaction. Schedule refresh shortly after first content paints.
    await _primeHomeCategories(allowNetworkSync: false);
    if (!mounted) return;
    _startupCachePrimed = true;

    if (!_isOffline) {
      _scheduleDeferredStartupSync();
    }

    _setupAutoRefresh();
  }

  Future<void> _primeHomeCategories({
    bool force = false,
    bool allowNetworkSync = true,
    bool ignoreCooldown = false,
  }) async {
    if (_primeInFlight) {
      _diag('🏠 [startup_diag] Prime categories skipped (already in flight)');
      return;
    }
    final now = DateTime.now();
    if (!force &&
        !ignoreCooldown &&
        _lastPrimeCompletedAt != null &&
        now.difference(_lastPrimeCompletedAt!) < const Duration(seconds: 20)) {
      _diag('🏠 [startup_diag] Prime categories skipped (cooldown active)');
      return;
    }
    _primeInFlight = true;
    _diag(
      '🏠 [startup_diag] Prime categories start | force=$force, active=$_activeCategory',
    );
    try {
      final activeCategory = _activeCategory;

      // Prime only what the user can see first; avoid eager multi-feed work
      // during the first interactive seconds after login.
      if (activeCategory != 'latest') {
        await _loadNews(category: activeCategory, syncWithNetwork: false);
        _diag(
          '🏠 [startup_diag] Primed visible category cache: $activeCategory',
        );
      }

      // Refresh latest feed first. Trending is derived from this dataset.
      await _loadNews(
        force: force,
        category: 'latest',
        syncWithNetwork: allowNetworkSync,
      );

      // Warm secondary tab from cache only, without extra network pressure.
      if (activeCategory == 'latest') {
        unawaited(_loadNews(category: 'trending', syncWithNetwork: false));
      }

      _diag('🏠 [startup_diag] Startup sync requested for latest only');
      _lastPrimeCompletedAt = DateTime.now();
    } finally {
      _primeInFlight = false;
      if (_pendingPrimeAfterLocaleChange && mounted) {
        _pendingPrimeAfterLocaleChange = false;
        unawaited(_primeHomeCategories(force: true));
      }
    }
  }

  void _scheduleDeferredStartupSync() {
    _deferredStartupSyncTimer?.cancel();
    _deferredStartupSyncTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted || _isOffline || !_isAppInForeground) return;
      _diag('🏠 [startup_diag] Running deferred startup sync');
      unawaited(_primeHomeCategories(ignoreCooldown: true));
    });
  }

  // ── Tab / Scroll helpers ──────────────────────────────────────────────────

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    if (_kCategories.length > 1) {
      final cat = _kCategories[_tabController.index];
      ref.read(homeCategoryProvider.notifier).setCategory(cat);
      _centerChip(_tabController.index);
      final state = ref.read(newsProvider);
      _diag(
        '🏠 [startup_diag] Tab changed | category=$cat, count=${state.getArticles(cat).length}, loading=${state.isLoading(cat)}',
      );
      if (state.getArticles(cat).isEmpty && !state.isLoading(cat)) {
        unawaited(_loadNews(category: cat));
      }
    }
  }

  void _centerChip(int index) {
    if (index < 0 || index >= _chipKeys.length) return;
    final ctx = _chipKeys[index].currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      alignment: 0.5,
    );
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (!mounted) return false;

    final pos = notification.metrics;
    final offset = pos.pixels;

    // Update FAB without setState
    if (_showScrollToTop.value != (offset > 300)) {
      _showScrollToTop.value = offset > 300;
    }

    // Infinite scroll trigger
    if (offset > (pos.maxScrollExtent - 480) &&
        !(_loadMoreInFlight[_activeCategory] ?? false) &&
        !ref.read(newsProvider).isLoading(_activeCategory)) {
      _loadMoreInFlight[_activeCategory] = true;
      unawaited(
        _loadMoreNews(
          category: _activeCategory,
        ).whenComplete(() => _loadMoreInFlight[_activeCategory] = false),
      );
    }
    return false;
  }

  void _scrollToTop() {
    final ctrl = PrimaryScrollController.maybeOf(context);
    if (ctrl != null && ctrl.hasClients) {
      ctrl.animateTo(
        0.0,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
      );
    }
  }

  // ── News loading ──────────────────────────────────────────────────────────

  Future<void> _loadNews({
    bool force = false,
    String? category,
    bool syncWithNetwork = true,
  }) async {
    if (!mounted) return;
    final locale = ref.read(currentLocaleProvider);
    final target = category ?? _activeCategory;
    final shouldSyncWithNetwork = syncWithNetwork && !_isOffline;
    await ref
        .read(newsProvider.notifier)
        .loadNews(
          target,
          locale,
          force: force,
          syncWithNetwork: shouldSyncWithNetwork,
        );
  }

  Future<void> _loadMoreNews({String? category}) async {
    if (!mounted) return;
    final locale = ref.read(currentLocaleProvider);
    final target = category ?? _activeCategory;
    await ref.read(newsProvider.notifier).loadMoreNews(target, locale);
  }

  // ── Auto-refresh (battery-aware) ──────────────────────────────────────────

  void _setupAutoRefresh() {
    _refreshTimer?.cancel();
    if (!_isAppInForeground) return;

    final perf = PerformanceConfig.of(context);
    final dataSaver = ref.read(dataSaverProvider);
    final quality = ref.read(networkQualityProvider);

    Duration interval;
    if (perf.lowPowerMode || dataSaver) {
      interval = const Duration(hours: 1);
    } else if (quality == NetworkQuality.poor ||
        quality == NetworkQuality.offline) {
      interval = const Duration(hours: 2);
    } else {
      interval = const Duration(minutes: 30);
    }

    _refreshTimer = Timer.periodic(interval, (_) {
      if (mounted && !_isOffline && _isAppInForeground) _loadNews();
    });
  }

  // ── Article tap ───────────────────────────────────────────────────────────

  Future<void> _handleArticleTap(NewsArticle article) async {
    if (article.tags?.contains('premium') == true) {
      final unlocked = await showUnlockDialog(
        context,
        article.url,
        article.title,
      );
      if (!unlocked) return;
    }
    ref.read(interstitialAdServiceProvider).onArticleViewed();

    final currentCategory = _activeCategory;
    final feedArticles = List<NewsArticle>.from(
      ref.read(newsProvider).getArticles(currentCategory),
    );
    final index = feedArticles.indexWhere((a) => a.url == article.url);
    final args = NewsDetailArgs(
      article: article,
      articles: feedArticles,
      initialIndex: index >= 0 ? index : 0,
    );

    if (!mounted) return;
    context.push(AppPaths.newsDetail, extra: args);
  }

  // ── App lifecycle ─────────────────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _isAppInForeground = false;
        _refreshTimer?.cancel();
        if (_particlesEnabled) _particleController.stop();
        break;
      case AppLifecycleState.resumed:
        _isAppInForeground = true;
        _setupAutoRefresh();
        if (_particlesEnabled) _particleController.repeat();
        break;
      default:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController
      ..removeListener(_onTabChanged)
      ..dispose();
    _chipsScrollController.dispose();
    _particleController.dispose();
    _showScrollToTop.dispose();
    _refreshTimer?.cancel();
    _offlineBannerTimer?.cancel();
    _deferredStartupSyncTimer?.cancel();
    _connectivitySub?.cancel();
    for (final sub in _providerSubscriptions) {
      sub.close();
    }
    _providerSubscriptions.clear();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(currentThemeModeProvider);
    final perf = PerformanceConfig.of(context);
    final isLoading = ref.watch(
      newsProvider.select((state) => state.isLoading(_activeCategory)),
    );

    // Compute gradient only when theme changes
    if (_cachedGradientStart == null ||
        _cachedGradientEnd == null ||
        _cachedGradientMode != themeMode) {
      final colors = AppGradients.getBackgroundGradient(themeMode);
      _cachedGradientStart = colors[0];
      _cachedGradientEnd = colors[1];
      _cachedGradientMode = themeMode;
    }
    final start = _cachedGradientStart!;
    final end = _cachedGradientEnd!;

    return Scaffold(
      backgroundColor: Colors.transparent,
      drawer: const AppDrawer(),
      body: Builder(
        builder: (scaffoldCtx) => Stack(
          children: [
            // ── 1. Gradient background (cheapest layer) ──────────────────
            Positioned.fill(
              child: RepaintBoundary(
                child: AnimatedThemeContainer(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        start.withValues(alpha: 0.9),
                        end.withValues(alpha: 0.9),
                      ],
                    ),
                  ),
                  child: _particlesEnabled && _particles != null
                      ? _ParticleBackground(
                          particles: _particles!,
                          controller: _particleController,
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ),

            // ── 2. Fixed top chrome + scrollable feed content ──────────────
            Column(
              children: [
                RepaintBoundary(
                  child: _GlassAppBar(
                    scaffoldContext: scaffoldCtx,
                    gradientStart: start,
                    reduceEffects: perf.reduceEffects,
                    enableBlur:
                        !perf.reduceEffects &&
                        !perf.lowPowerMode &&
                        !perf.isLowEndDevice &&
                        perf.performanceTier == DevicePerformanceTier.flagship,
                    onRefresh: () => _loadNews(force: true),
                    isRefreshing: isLoading,
                  ),
                ),
                if (_kCategories.length > 1) ...[
                  RepaintBoundary(
                    child: _CategoryChipsBar(
                      tabController: _tabController,
                      chipsController: _chipsScrollController,
                      chipKeys: _chipKeys,
                      onTabSelected: (i) {
                        _tabController.animateTo(i);
                        _centerChip(i);
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (_showOfflineBanner)
                  _OfflineBanner(
                    onDismiss: () => setState(() => _showOfflineBanner = false),
                  ),
                Expanded(
                  child: NotificationListener<ScrollNotification>(
                    onNotification: _onScrollNotification,
                    child: _NewsTabBarView(
                      tabController: _tabController,
                      isOffline: _isOffline,
                      onLoadNews: _loadNews,
                      onArticleTap: _handleArticleTap,
                    ),
                  ),
                ),
              ],
            ),

            // ── 3. Scroll-to-top FAB (ValueListenableBuilder = 0 rebuilds upstream) ─
            Positioned(
              bottom: 116,
              right: 20,
              child: _ScrollToTopFab(
                visible: _showScrollToTop,
                onTap: _scrollToTop,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SUB-WIDGETS  (extracted so the parent tree never rebuilds them needlessly)
// ─────────────────────────────────────────────────────────────────────────────

/// Category chips – only rebuilds when tab index changes
class _CategoryChipsBar extends StatelessWidget {
  const _CategoryChipsBar({
    required this.tabController,
    required this.chipsController,
    required this.chipKeys,
    required this.onTabSelected,
  });

  final TabController tabController;
  final ScrollController chipsController;
  final List<GlobalKey> chipKeys;
  final ValueChanged<int> onTabSelected;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final labels = <String>[loc.latest, loc.trending];
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SizedBox(
      height: 48,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          // Skip BackdropFilter here – it forces a compositing layer on every
          // scroll pixel when inside a ListView. Use a semi-opaque fill instead.
          color: isDark ? const Color(0x14FFFFFF) : const Color(0x0D000000),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: isDark ? const Color(0x1AFFFFFF) : const Color(0x0D000000),
            width: 0.8,
          ),
        ),
        child: AnimatedBuilder(
          animation: tabController,
          builder: (context, _) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
              child: Row(
                children: List.generate(_kCategories.length, (i) {
                  final selected = i == tabController.index;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: i == _kCategories.length - 1 ? 0 : 4,
                      ),
                      child: Bouncy3DChip(
                        key: chipKeys[i],
                        label: labels[i],
                        selected: selected,
                        expanded: true,
                        onTap: () => onTabSelected(i),
                      ),
                    ),
                  );
                }),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Glass app-bar – no Riverpod watch, receives everything via constructor
class _GlassAppBar extends StatelessWidget {
  const _GlassAppBar({
    required this.scaffoldContext,
    required this.gradientStart,
    required this.reduceEffects,
    required this.enableBlur,
    required this.onRefresh,
    this.isRefreshing = false,
  });

  final BuildContext scaffoldContext;
  final Color gradientStart;
  final bool reduceEffects;
  final bool enableBlur;
  final VoidCallback onRefresh;
  final bool isRefreshing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topPad = MediaQuery.of(context).padding.top;
    final baseColor =
        theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface;
    final loc = AppLocalizations.of(context);

    return SizedBox(
      height: topPad + 60,
      child: Stack(
        children: [
          // Visual background (pointer-ignored)
          IgnorePointer(
            child: SizedBox(
              height: topPad + 60,
              child: reduceEffects
                  ? ColoredBox(color: baseColor.withValues(alpha: 0.94))
                  : DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            gradientStart.withValues(alpha: 0.98),
                            gradientStart.withValues(alpha: 0.85),
                            gradientStart.withValues(alpha: 0.60),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.4, 0.7, 1.0],
                        ),
                      ),
                      child: enableBlur
                          ? ClipRect(
                              child: BackdropFilter(
                                filter: ui.ImageFilter.blur(
                                  sigmaX: 10,
                                  sigmaY: 10,
                                ),
                                child: const ColoredBox(
                                  color: Colors.transparent,
                                ),
                              ),
                            )
                          : const ColoredBox(color: Colors.transparent),
                    ),
            ),
          ),
          // Interactive content
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
                      onPressed: () =>
                          Scaffold.of(scaffoldContext).openDrawer(),
                      isDark: theme.brightness == Brightness.dark,
                    ),
                    Expanded(
                      child: IgnorePointer(
                        child: Center(
                          child: Text(
                            loc.homeTitle,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.95,
                              ),
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    GlassIconButton(
                      icon: Icons.refresh_rounded,
                      onPressed: isRefreshing ? null : onRefresh,
                      isDark: theme.brightness == Brightness.dark,
                      isLoading: isRefreshing,
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

/// Offline banner
class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.onDismiss});
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: GlassContainer(
        borderColor: const Color(0x80FFA000),
        backgroundColor: const Color(0x1AFFA000),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              const Icon(
                Icons.wifi_off_rounded,
                color: Color(0xFFFFB74D),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  loc.offlineShowingCached,
                  style: const TextStyle(
                    color: Color(0xE6FFFFFF),
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
              TextButton(
                onPressed: onDismiss,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  loc.ok,
                  style: const TextStyle(
                    color: Color(0xFFFFB74D),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Scroll-to-top FAB – driven by ValueNotifier, never rebuilds parent
class _ScrollToTopFab extends StatelessWidget {
  const _ScrollToTopFab({required this.visible, required this.onTap});
  final ValueNotifier<bool> visible;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: visible,
      builder: (_, show, child) => AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        opacity: show ? 1.0 : 0.0,
        child: IgnorePointer(ignoring: !show, child: child),
      ),
      child: GlassContainer(
        borderRadius: BorderRadius.circular(50),
        child: IconButton(
          onPressed: onTap,
          icon: const PremiumThemeIcon(Icons.arrow_upward_rounded),
          style: IconButton.styleFrom(
            backgroundColor: const Color(0x336C63FF),
            foregroundColor: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// News content for all tabs.
/// Each page watches only its own category slice to prevent whole-tab rebuilds.
class _NewsTabBarView extends StatelessWidget {
  const _NewsTabBarView({
    required this.tabController,
    required this.isOffline,
    required this.onLoadNews,
    required this.onArticleTap,
  });

  final TabController tabController;
  final bool isOffline;
  final Future<void> Function({bool force, String? category}) onLoadNews;
  final Future<void> Function(NewsArticle) onArticleTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context);

    return TabBarView(
      controller: tabController,
      children: _kCategories.map((cat) {
        return RepaintBoundary(
          child: _CategoryPageContainer(
            key: ValueKey('page_$cat'),
            category: cat,
            isOffline: isOffline,
            onLoadNews: onLoadNews,
            onArticleTap: onArticleTap,
            theme: theme,
            loc: loc,
          ),
        );
      }).toList(),
    );
  }
}

class _CategoryPageContainer extends ConsumerWidget {
  const _CategoryPageContainer({
    required super.key,
    required this.category,
    required this.isOffline,
    required this.onLoadNews,
    required this.onArticleTap,
    required this.theme,
    required this.loc,
  });

  final String category;
  final bool isOffline;
  final Future<void> Function({bool force, String? category}) onLoadNews;
  final Future<void> Function(NewsArticle) onArticleTap;
  final ThemeData theme;
  final AppLocalizations loc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final articles = ref.watch(
      newsProvider.select((state) => state.getArticles(category)),
    );
    final isLoading = ref.watch(
      newsProvider.select((state) => state.isLoading(category)),
    );
    final error = ref.watch(
      newsProvider.select((state) => state.getError(category)),
    );
    final hasMore = ref.watch(
      newsProvider.select((state) => state.hasMore(category)),
    );

    return _CategoryPage(
      key: ValueKey('category_state_$category'),
      category: category,
      articles: articles,
      isLoading: isLoading,
      error: error,
      hasMore: hasMore,
      isOffline: isOffline,
      onRefresh: () => onLoadNews(force: true, category: category),
      onRetry: () => onLoadNews(category: category),
      onArticleTap: onArticleTap,
      theme: theme,
      loc: loc,
    );
  }
}

/// A single category page – AutomaticKeepAlive keeps scroll position alive
class _CategoryPage extends StatefulWidget {
  const _CategoryPage({
    required super.key,
    required this.category,
    required this.articles,
    required this.isLoading,
    required this.error,
    required this.hasMore,
    required this.isOffline,
    required this.onRefresh,
    required this.onRetry,
    required this.onArticleTap,
    required this.theme,
    required this.loc,
  });

  final String category;
  final List<NewsArticle> articles;
  final bool isLoading;
  final String? error;
  final bool hasMore;
  final bool isOffline;
  final Future<void> Function() onRefresh;
  final VoidCallback onRetry;
  final Future<void> Function(NewsArticle) onArticleTap;
  final ThemeData theme;
  final AppLocalizations loc;

  @override
  State<_CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<_CategoryPage> {
  @override
  Widget build(BuildContext context) {
    return RefreshIndicator.adaptive(
      onRefresh: widget.onRefresh,
      color: widget.theme.colorScheme.primary,
      backgroundColor: widget.theme.colorScheme.surface,
      displacement: 60,
      child: CustomScrollView(
        cacheExtent: 900,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          // Error banner
          if (widget.error != null && !widget.isOffline)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: GlassContainer(
                  borderColor: const Color(0x80FF5252),
                  backgroundColor: const Color(0x1AFF5252),
                  child: ErrorDisplay(
                    error: AppFailure.serverError(widget.error!),
                    onRetry: widget.onRetry,
                  ),
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 8)),

          SliverToBoxAdapter(
            child: ProfessionalHeader(
              articleCount: widget.articles.length,
              category: widget.category == 'national' ? null : widget.category,
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 8)),

          // Loading shimmer
          if (widget.isLoading && widget.articles.isEmpty)
            const SliverFillRemaining(child: NewsFeedSkeleton())
          // Empty state
          else if (widget.articles.isEmpty && widget.error == null)
            SliverFillRemaining(
              child: _EmptyState(
                category: widget.category,
                theme: widget.theme,
                loc: widget.loc,
                onRetry: widget.onRetry,
              ),
            )
          // Articles
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                _buildItem,
                childCount:
                    widget.articles.length + (widget.articles.isEmpty ? 0 : 1),
                addAutomaticKeepAlives: false,
                addSemanticIndexes: false,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildItem(BuildContext ctx, int index) {
    final articles = widget.articles;
    if (index < articles.length) {
      final article = articles[index];
      return Padding(
        // Pre-computed EdgeInsets to avoid object creation per-frame
        padding: EdgeInsets.fromLTRB(
          16,
          index == 0 ? 4 : 6,
          16,
          index == articles.length - 1 ? 16 : 6,
        ),
        child: NewsCard(
          key: ValueKey('${widget.category}_${article.url}_$index'),
          article: article,
          onTap: () => widget.onArticleTap(article),
          showSentimentBadge: false,
        ),
      );
    }
    // Footer: loader or end-of-feed
    return (widget.hasMore && widget.isLoading)
        ? Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator.adaptive(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation(
                    widget.theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
          )
        : (!widget.hasMore)
        ? Padding(
            padding: const EdgeInsets.only(bottom: 48, top: 24),
            child: Center(
              child: Text(
                widget.loc.endOfNews,
                style: widget.theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0x66FFFFFF),
                  fontStyle: FontStyle.italic,
                  fontSize: 13,
                ),
              ),
            ),
          )
        : const SizedBox(height: 16);
  }
}

/// Empty state widget (const-eligible inner layout)
class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.category,
    required this.theme,
    required this.loc,
    required this.onRetry,
  });

  final String category;
  final ThemeData theme;
  final AppLocalizations loc;
  final VoidCallback onRetry;

  String _emptyMessage() {
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

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _kCategoryIcons[category] ?? Icons.article_rounded,
              size: 64,
              color: const Color(0x4DFFFFFF),
            ),
            const SizedBox(height: 16),
            Text(
              _emptyMessage(),
              style: theme.textTheme.titleMedium?.copyWith(
                color: const Color(0x80FFFFFF),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(loc.retry),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary.withValues(
                  alpha: 0.9,
                ),
                foregroundColor: theme.colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  PARTICLE BACKGROUND  (isolated RepaintBoundary – never triggers parent)
// ─────────────────────────────────────────────────────────────────────────────

class _ParticleBackground extends StatelessWidget {
  const _ParticleBackground({
    required this.particles,
    required this.controller,
  });

  final List<Particle> particles;
  final Animation<double> controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, _) => CustomPaint(
        painter: _ParticlePainter(particles: particles, t: controller.value),
        size: Size.infinite,
      ),
    );
  }
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter({required this.particles, required this.t});

  final List<Particle> particles;
  final double t;

  // Reuse a single Paint object
  final Paint _paint = Paint()..style = PaintingStyle.fill;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final time = t + p.delay;
      final yFrac = (p.y + time * p.speed) % 1.0;
      final opacity =
          p.color.opacity *
          (0.5 + 0.5 * math.sin(time * math.pi * 2 + p.x * math.pi));
      final r =
          p.size *
          (1 + 0.15 * math.sin(time * math.pi * 2 + p.delay * math.pi));

      _paint.color = p.color.withValues(alpha: opacity);
      canvas.drawCircle(
        Offset(p.x * size.width, yFrac * size.height),
        r,
        _paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.t != t;
}

// ─────────────────────────────────────────────────────────────────────────────
//  DATA CLASS
// ─────────────────────────────────────────────────────────────────────────────

class Particle {
  const Particle({
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
