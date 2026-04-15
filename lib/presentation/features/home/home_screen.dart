import 'dart:async';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart'
    hide localLearningEngineProvider, networkQualityProvider;
import '../../../core/navigation/navigation_helper.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/theme/theme.dart';
import '../../../core/config/performance_config.dart';
import '../../../core/persistence/offline_handler.dart';
import '../../../core/architecture/failure.dart' show AppFailure;
import '../../../l10n/generated/app_localizations.dart';

import '../../providers/news_providers.dart';
import '../../providers/tab_providers.dart';
import '../../providers/language_providers.dart';
import '../../providers/app_settings_providers.dart';
import '../../providers/feature_providers.dart'
    show localLearningEngineProvider;
import '../../providers/network_providers.dart';

import '../../../../domain/entities/news_article.dart';
import '../../../../infrastructure/network/app_network_service.dart';

import '../../widgets/app_drawer.dart';
import '../../widgets/error_widget.dart';
import '../../widgets/animated_theme_container.dart';
import '../../widgets/banner_ad_widget.dart';
import '../../widgets/bouncy_chip_segmented_row.dart';
import '../../widgets/premium_screen_header.dart';
import '../../widgets/premium_theme_icon.dart';
import '../../widgets/premium_scaffold.dart';
import '../../widgets/glass_container.dart';

import '../common/news_detail_args.dart';
import 'widgets/news_card.dart';
import 'widgets/news_feed_skeleton.dart';
import 'widgets/professional_header.dart';

extension _CtxColors on BuildContext {
  AppColorsExtension get colors {
    final theme = Theme.of(this);
    return theme.extension<AppColorsExtension>() ?? _fallbackColors(theme);
  }
}

AppColorsExtension _fallbackColors(ThemeData theme) {
  final scheme = theme.colorScheme;
  final isDark = theme.brightness == Brightness.dark;
  final onSurfaceVariant = scheme.onSurfaceVariant;

  return AppColorsExtension(
    bg: scheme.surface,
    surface: scheme.surface,
    card: isDark ? scheme.surfaceContainerHighest : scheme.surface,
    cardBorder: scheme.outlineVariant.withValues(alpha: isDark ? 0.48 : 0.72),
    textPrimary: scheme.onSurface,
    textSecondary: onSurfaceVariant,
    textHint: onSurfaceVariant.withValues(alpha: isDark ? 0.74 : 0.82),
    goldStart: const Color(0xFFD4A853),
    goldMid: const Color(0xFFB8893C),
    goldGlow: const Color(0x33D4A853),
    successGreen: const Color(0xFF22C55E),
    errorRed: scheme.error,
    proBlue: scheme.primary,
    slideBlue: AppColors.slideBlue,
    slideGreen: AppColors.slideGreen,
    slideRed: AppColors.slideRed,
  );
}

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
  static const Duration _kStartupCacheSettleDelay = Duration(milliseconds: 200);
  late int _selectedCategoryIndex;
  late final Map<String, bool> _loadMoreInFlight = {};

  final ValueNotifier<bool> _showScrollToTop = ValueNotifier(false);

  bool _isOffline = false;
  bool _showOfflineBanner = false;
  bool _isAppInForeground = true;
  bool _isElementActive = false;
  bool _isDisposed = false;
  bool _didStartLifecycleDependentWork = false;
  bool _performanceLowPowerMode = false;
  DevicePerformanceTier _performanceTier = DevicePerformanceTier.midRange;
  Timer? _refreshTimer;
  Timer? _offlineBannerTimer;
  Timer? _deferredStartupSyncTimer;
  Timer? _startupFeedRetryTimer;
  Timer? _startupInitTimer;
  Timer? _localePrimeRetryTimer;
  StreamSubscription<bool>? _connectivitySub;
  final List<ProviderSubscription<dynamic>> _providerSubscriptions =
      <ProviderSubscription<dynamic>>[];
  bool _primeInFlight = false;
  bool _pendingPrimeAfterLocaleChange = false;
  bool _startupCachePrimed = false;
  DateTime? _lastPrimeCompletedAt;

  AppLocalizations get loc => AppLocalizations.of(context);
  String get _activeCategory => _kCategories[_selectedCategoryIndex];
  bool get _canReadProviders => mounted && _isElementActive && !_isDisposed;

  void _diag(String message) {
    if (!kDebugMode) return;
    debugPrint(message);
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _isElementActive = true;
    WidgetsBinding.instance.addObserver(this);

    final savedCategory = ref.read(homeCategoryProvider);
    final initialIndex = _kCategories.indexOf(savedCategory);
    _diag(
      '🏠 [startup_diag] Home init category | saved=$savedCategory, initialIndex=$initialIndex, fallback=${initialIndex >= 0 ? _kCategories[initialIndex] : _kCategories.first}',
    );

    _selectedCategoryIndex = initialIndex >= 0 ? initialIndex : 0;
    if (initialIndex < 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_canReadProviders) {
          ref
              .read(homeCategoryProvider.notifier)
              .setCategory(_kCategories.first);
        }
      });
    }
    _setupProviderListeners();
    _initConnectivity();
    unawaited(_initializeApp());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final perf = PerformanceConfig.of(context);
    final previousTier = _performanceTier;
    final previousLowPowerMode = _performanceLowPowerMode;
    _performanceTier = perf.performanceTier;
    _performanceLowPowerMode = perf.lowPowerMode;

    if (!_didStartLifecycleDependentWork ||
        previousTier != _performanceTier ||
        previousLowPowerMode != _performanceLowPowerMode) {
      _didStartLifecycleDependentWork = true;
      _setupAutoRefresh();
    }
  }

  @override
  void activate() {
    super.activate();
    _isElementActive = true;
  }

  @override
  void deactivate() {
    _isElementActive = false;
    super.deactivate();
  }

  void _setupProviderListeners() {
    // All listeners use listenManual so they don't force rebuilds of the whole tree
    _providerSubscriptions.add(
      ref.listenManual<Locale>(currentLocaleProvider, (prev, next) {
        if (!_canReadProviders) return;
        if (prev != null && prev != next) {
          final newsState = ref.read(newsProvider);
          if (_primeInFlight || newsState.isLoading(_activeCategory)) {
            _queuePrimeAfterLocaleChange();
            return;
          }
          // Locale flips can happen while initial prime is in-flight.
          // Queue one forced prime so the active feed always matches locale.
          unawaited(
            _primeHomeCategories(
              force: true,
              includeLatestSeed: _activeCategory == 'latest',
            ),
          );
        }
      }),
    );

    _providerSubscriptions.add(
      ref.listenManual<bool>(dataSaverProvider, (prev, next) {
        if (!_canReadProviders) return;
        if (prev != null && prev != next) _setupAutoRefresh();
      }),
    );

    _providerSubscriptions.add(
      ref.listenManual<NetworkQuality>(networkQualityProvider, (prev, next) {
        if (!_canReadProviders) return;
        if (prev != null && prev != next) _setupAutoRefresh();
      }),
    );

    _providerSubscriptions.add(
      ref.listenManual<int>(currentTabIndexProvider, (prev, next) {
        if (!_isElementActive || _isDisposed || !mounted) return;
        if (next == 0) _scrollToTop();
      }),
    );

    _providerSubscriptions.add(
      ref.listenManual<String>(homeCategoryProvider, (prev, next) {
        if (!_canReadProviders) return;
        if (_kCategories.length <= 1) return;
        if (prev != next) {
          final idx = _kCategories.indexOf(next);
          if (idx != -1 && idx != _selectedCategoryIndex) {
            _setActiveCategoryIndex(idx, updateProvider: false);
          }
        }
      }),
    );
  }

  void _queuePrimeAfterLocaleChange() {
    _pendingPrimeAfterLocaleChange = true;
    _localePrimeRetryTimer?.cancel();
    _localePrimeRetryTimer = Timer(const Duration(milliseconds: 900), () {
      if (!_canReadProviders) return;
      final newsState = ref.read(newsProvider);
      if (_primeInFlight || newsState.isLoading(_activeCategory)) {
        _queuePrimeAfterLocaleChange();
        return;
      }
      _pendingPrimeAfterLocaleChange = false;
      unawaited(
        _primeHomeCategories(
          force: true,
          includeLatestSeed: _activeCategory == 'latest',
        ),
      );
    });
  }

  void _initConnectivity() async {
    _isOffline = await OfflineHandler.isOffline();
    _connectivitySub = OfflineHandler().onConnectivityChanged.listen((offline) {
      if (!_canReadProviders) return;
      setState(() => _isOffline = offline);
      if (offline) {
        _showOfflineBanner = true;
        _offlineBannerTimer?.cancel();
        _offlineBannerTimer = Timer(const Duration(seconds: 5), () {
          if (_isElementActive && !_isDisposed && mounted) {
            setState(() => _showOfflineBanner = false);
          }
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
    if (!_canReadProviders) return;

    // Startup must stay cache-first to avoid network pressure before first
    // interaction. Schedule refresh shortly after first content paints.
    await _primeHomeCategories(
      allowNetworkSync: false,
      includeLatestSeed: _activeCategory == 'latest',
    );
    if (!_canReadProviders) return;
    _startupCachePrimed = true;

    // Give the local article stream a brief window to publish cached content
    // before deciding whether the visible feed still needs rescue sync.
    await Future<void>.delayed(_kStartupCacheSettleDelay);
    if (!_canReadProviders) return;

    final visibleCategory = _activeCategory;
    final hasVisibleCache = ref
        .read(newsProvider)
        .getArticles(visibleCategory)
        .isNotEmpty;
    if (!_isOffline) {
      _scheduleDeferredStartupSync(
        category: visibleCategory,
        prioritizeVisibleContent: !hasVisibleCache,
      );
      _scheduleStartupFeedWatchdog(category: visibleCategory);
    }

    _setupAutoRefresh();
  }

  Future<void> _primeHomeCategories({
    bool force = false,
    bool allowNetworkSync = true,
    bool ignoreCooldown = false,
    bool includeLatestSeed = false,
  }) async {
    if (!_canReadProviders) return;
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
        if (!_canReadProviders) return;
        _diag(
          '🏠 [startup_diag] Primed visible category cache: $activeCategory',
        );
      }

      if (includeLatestSeed || activeCategory == 'latest') {
        // Refresh latest feed when it is visible or when the app has already
        // cleared the first-paint-sensitive startup window.
        await _loadNews(
          force: force,
          category: 'latest',
          syncWithNetwork: allowNetworkSync,
        );
        if (!_canReadProviders) return;
        _diag('🏠 [startup_diag] Startup sync requested for latest only');
      } else {
        _diag(
          '🏠 [startup_diag] Skipped latest seed during first paint '
          '(active=$activeCategory)',
        );
      }
      _lastPrimeCompletedAt = DateTime.now();
    } finally {
      _primeInFlight = false;
      if (_pendingPrimeAfterLocaleChange && _canReadProviders) {
        _pendingPrimeAfterLocaleChange = false;
        unawaited(
          _primeHomeCategories(
            force: true,
            includeLatestSeed: _activeCategory == 'latest',
          ),
        );
      }
    }
  }

  void _scheduleDeferredStartupSync({
    required String category,
    bool prioritizeVisibleContent = false,
  }) {
    final delay = switch ((_performanceTier, prioritizeVisibleContent)) {
      (DevicePerformanceTier.flagship, true) => const Duration(seconds: 1),
      (DevicePerformanceTier.flagship, false) => const Duration(seconds: 4),
      (DevicePerformanceTier.midRange, true) => const Duration(seconds: 2),
      (DevicePerformanceTier.midRange, false) => const Duration(seconds: 6),
      (DevicePerformanceTier.budget, true) ||
      (DevicePerformanceTier.lowEnd, true) => const Duration(seconds: 3),
      (DevicePerformanceTier.budget, false) ||
      (DevicePerformanceTier.lowEnd, false) => const Duration(seconds: 8),
    };
    _deferredStartupSyncTimer?.cancel();
    _deferredStartupSyncTimer = Timer(delay, () {
      if (!_canReadProviders || _isOffline || !_isAppInForeground) return;
      final targetCategory = _activeCategory;
      final newsState = ref.read(newsProvider);
      if (newsState.isLoading(targetCategory)) {
        _diag(
          '🏠 [startup_diag] Deferred startup sync skipped '
          '(category loading: $targetCategory)',
        );
        return;
      }
      if (prioritizeVisibleContent) {
        final visibleArticles = newsState.getArticles(targetCategory);
        if (visibleArticles.isNotEmpty) {
          _diag(
            '🏠 [startup_diag] Deferred startup sync downgraded '
            '(visible category already ready: $targetCategory)',
          );
          _scheduleDeferredStartupSync(category: targetCategory);
          return;
        }
      }
      _diag(
        '🏠 [startup_diag] Running deferred startup sync '
        '(category=$targetCategory, '
        'prioritizeVisibleContent=$prioritizeVisibleContent, '
        'scheduledFrom=$category)',
      );
      unawaited(_loadNews(category: targetCategory));
    });
  }

  void _scheduleStartupFeedWatchdog({String? category, int attempt = 0}) {
    _startupFeedRetryTimer?.cancel();
    final targetCategory = category ?? _activeCategory;
    final baseDelay = switch (_performanceTier) {
      DevicePerformanceTier.flagship => const Duration(seconds: 4),
      DevicePerformanceTier.midRange => const Duration(seconds: 5),
      DevicePerformanceTier.budget ||
      DevicePerformanceTier.lowEnd => const Duration(seconds: 7),
    };
    final delay = attempt == 0 ? baseDelay : const Duration(seconds: 2);

    _startupFeedRetryTimer = Timer(delay, () {
      if (!_canReadProviders || _isOffline || !_isAppInForeground) return;
      final state = ref.read(newsProvider);
      final targetArticles = state.getArticles(targetCategory);
      if (targetArticles.isNotEmpty || state.isLoading(targetCategory)) {
        return;
      }
      final locale = ref.read(currentLocaleProvider);
      final notifier = ref.read(newsProvider.notifier);
      if (notifier.hadRecentSuccessfulNetworkSync(targetCategory, locale)) {
        _diag(
          '🏠 [startup_diag] Startup feed watchdog waiting for post-sync stream hydration '
          '(category=$targetCategory, attempt=$attempt)',
        );
        if (attempt == 0) {
          _scheduleStartupFeedWatchdog(
            category: targetCategory,
            attempt: attempt + 1,
          );
        }
        return;
      }
      _diag(
        '🏠 [startup_diag] Startup feed watchdog retrying sync '
        '(category=$targetCategory, attempt=$attempt)',
      );
      unawaited(_loadNews(category: targetCategory, force: true));
    });
  }

  // ── Tab / Scroll helpers ──────────────────────────────────────────────────

  void _setActiveCategoryIndex(int index, {bool updateProvider = true}) {
    if (index < 0 || index >= _kCategories.length) return;
    if (!_canReadProviders) return;
    if (_selectedCategoryIndex != index) {
      setState(() => _selectedCategoryIndex = index);
    }
    final cat = _kCategories[index];
    if (updateProvider) {
      ref.read(homeCategoryProvider.notifier).setCategory(cat);
    }
    final state = ref.read(newsProvider);
    _diag(
      '🏠 [startup_diag] Category switched | category=$cat, count=${state.getArticles(cat).length}, loading=${state.isLoading(cat)}',
    );
    if (state.getArticles(cat).isEmpty && !state.isLoading(cat)) {
      unawaited(_loadNews(category: cat));
    }
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (!_canReadProviders) return false;

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
    if (!_isElementActive || _isDisposed || !mounted) return;
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
    bool manualAdOpportunity = false,
  }) async {
    if (!_canReadProviders) return;
    final locale = ref.read(currentLocaleProvider);
    final target = category ?? _activeCategory;
    final shouldSyncWithNetwork = syncWithNetwork && !_isOffline;
    try {
      final notifier = ref.read(newsProvider.notifier);
      await notifier.loadNews(
        target,
        locale,
        force: force,
        syncWithNetwork: shouldSyncWithNetwork,
      );
      if (manualAdOpportunity && _canReadProviders) {
        unawaited(ref.read(interstitialAdServiceProvider).onManualRefresh());
      }
    } catch (e) {
      _diag('🏠 loadNews failed | category=$target, error=$e');
    }
  }

  Future<void> _loadMoreNews({String? category}) async {
    if (!_canReadProviders) return;
    final locale = ref.read(currentLocaleProvider);
    final target = category ?? _activeCategory;
    try {
      final notifier = ref.read(newsProvider.notifier);
      await notifier.loadMoreNews(target, locale);
    } catch (e) {
      _diag('🏠 loadMoreNews failed | category=$target, error=$e');
    }
  }

  // ── Auto-refresh (battery-aware) ──────────────────────────────────────────

  void _setupAutoRefresh() {
    _refreshTimer?.cancel();
    if (!_isAppInForeground || !_canReadProviders) return;

    final dataSaver = ref.read(dataSaverProvider);
    final quality = ref.read(networkQualityProvider);

    Duration interval;
    if (_performanceLowPowerMode || dataSaver) {
      interval = const Duration(hours: 1);
    } else if (quality == NetworkQuality.poor ||
        quality == NetworkQuality.offline) {
      interval = const Duration(hours: 2);
    } else {
      interval = const Duration(minutes: 30);
    }

    _refreshTimer = Timer.periodic(interval, (_) {
      if (_canReadProviders && !_isOffline && _isAppInForeground) _loadNews();
    });
  }

  // ── Article tap ───────────────────────────────────────────────────────────

  Future<void> _handleArticleTap(NewsArticle article) async {
    unawaited(ref.read(interstitialAdServiceProvider).onArticleViewed());
    ref.read(localLearningEngineProvider).trackOpen(article);

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
    await NavigationHelper.openNewsDetail<void>(context, args);
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
        break;
      case AppLifecycleState.resumed:
        _isAppInForeground = true;
        _setupAutoRefresh();
        break;
      default:
        break;
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _isElementActive = false;
    WidgetsBinding.instance.removeObserver(this);
    _showScrollToTop.dispose();
    _refreshTimer?.cancel();
    _offlineBannerTimer?.cancel();
    _deferredStartupSyncTimer?.cancel();
    _startupFeedRetryTimer?.cancel();
    _startupInitTimer?.cancel();
    _localePrimeRetryTimer?.cancel();
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
    return PremiumScaffold(
      useBackground: false, // Hosted in MainNavigationScreen
      drawer: const AppDrawer(),
      title: loc.homeTitle,
      headerLeading: PremiumHeaderLeading.menu,
      headerActions: [
        Consumer(
          builder: (context, ref, child) {
            final isLoading = ref.watch(
              newsProvider.select((state) => state.isLoading(_activeCategory)),
            );
            return PremiumHeaderIconButton(
              icon: isLoading
                  ? Icons.hourglass_top_rounded
                  : Icons.refresh_rounded,
              onPressed: isLoading
                  ? () {}
                  : () {
                      unawaited(
                        _loadNews(force: true, manualAdOpportunity: true),
                      );
                    },
              tooltip: 'Refresh',
            );
          },
        ),
      ],
      body: Stack(
        children: [
          // ── 1. Content layer ──────────────
          Column(
            children: [
              if (_kCategories.length > 1) ...[
                _CategoryChipsBar(
                  selectedIndex: _selectedCategoryIndex,
                  onTabSelected: _setActiveCategoryIndex,
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
                  child: _NewsCategoryStack(
                    selectedIndex: _selectedCategoryIndex,
                    isOffline: _isOffline,
                    onLoadNews: _loadNews,
                    onArticleTap: _handleArticleTap,
                  ),
                ),
              ),
            ],
          ),

          // ── 2. Scroll-to-top FAB ─
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
    );
  }
}

class _CategoryChipsBar extends StatelessWidget {
  const _CategoryChipsBar({
    required this.selectedIndex,
    required this.onTabSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final labels = <String>[loc.latest, loc.trending];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: BouncyChipSegmentedRow<int>(
        options: <SegmentedChipOption<int>>[
          SegmentedChipOption<int>(value: 0, label: labels[0]),
          SegmentedChipOption<int>(value: 1, label: labels[1]),
        ],
        selectedValue: selectedIndex,
        fillAvailableWidth: true,
        spacing: 4,
        onSelected: onTabSelected,
      ),
    );
  }
}

/// News content for all categories.
/// Each page watches only its own category slice to prevent whole-stack rebuilds.
class _NewsCategoryStack extends StatefulWidget {
  const _NewsCategoryStack({
    required this.selectedIndex,
    required this.isOffline,
    required this.onLoadNews,
    required this.onArticleTap,
  });

  final int selectedIndex;
  final bool isOffline;
  final Future<void> Function({
    bool force,
    String? category,
    bool syncWithNetwork,
    bool manualAdOpportunity,
  }) onLoadNews;
  final Future<void> Function(NewsArticle) onArticleTap;

  @override
  State<_NewsCategoryStack> createState() => _NewsCategoryStackState();
}

class _NewsCategoryStackState extends State<_NewsCategoryStack> {
  late final Set<int> _initializedIndices;

  @override
  void initState() {
    super.initState();
    _initializedIndices = {widget.selectedIndex};
  }

  @override
  void didUpdateWidget(_NewsCategoryStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedIndex != oldWidget.selectedIndex) {
      _initializedIndices.add(widget.selectedIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context);

    return IndexedStack(
      index: widget.selectedIndex,
      children: List.generate(_kCategories.length, (index) {
        if (!_initializedIndices.contains(index)) {
          return const SizedBox.shrink(); // Lazy load the category page
        }
        final cat = _kCategories[index];
        return _CategoryPageContainer(
          key: ValueKey('page_$cat'),
          category: cat,
          isOffline: widget.isOffline,
          onLoadNews: widget.onLoadNews,
          onArticleTap: widget.onArticleTap,
          theme: theme,
          loc: loc,
        );
      }),
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
    final colors = context.colors;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: GlassContainer(
        borderColor: colors.goldStart.withValues(alpha: 0.5),
        backgroundColor: colors.goldStart.withValues(alpha: 0.1),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              const Icon(
                Icons.wifi_off_rounded,
                color: Color(0xFFFFB74D), // Stay gold for visibility
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  loc.offlineShowingCached,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
              TextButton(
                onPressed: onDismiss,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  minimumSize: const Size(64, 44),
                  tapTargetSize: MaterialTapTargetSize.padded,
                ),
                child: Text(
                  loc.ok,
                  style: TextStyle(
                    color: colors.goldStart,
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
          icon: PremiumThemeIcon(
            Icons.arrow_upward_rounded,
            bangladeshColor: context.colors.goldStart,
          ),
          style: IconButton.styleFrom(
            backgroundColor: context.colors.proBlue.withValues(alpha: 0.2),
            foregroundColor: context.colors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _CategoryPageContainer extends ConsumerWidget {
  const _CategoryPageContainer({
    required this.category,
    required this.isOffline,
    required this.onLoadNews,
    required this.onArticleTap,
    required this.theme,
    required this.loc,
    super.key,
  });

  final String category;
  final bool isOffline;
  final Future<void> Function({
    bool force,
    String? category,
    bool syncWithNetwork,
    bool manualAdOpportunity,
  })
  onLoadNews;
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
      onRefresh: () => onLoadNews(
        force: true,
        category: category,
        manualAdOpportunity: true,
      ),
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
    super.key,
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

class _CategoryPageState extends State<_CategoryPage>
    with AutomaticKeepAliveClientMixin<_CategoryPage> {
  static const int _firstInlineAdAfterArticles = 5;
  static const int _inlineAdEveryArticles = 5;

  List<NewsArticle> _cachedVisibleArticles = const <NewsArticle>[];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _cachedVisibleArticles = widget.articles;
  }

  @override
  void didUpdateWidget(covariant _CategoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.articles, widget.articles) ||
        oldWidget.articles.length != widget.articles.length) {
      _cachedVisibleArticles = widget.articles;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final perf = PerformanceConfig.of(context);
    final visibleArticles = _cachedVisibleArticles;
    return RefreshIndicator.adaptive(
      onRefresh: widget.onRefresh,
      color: widget.theme.colorScheme.primary,
      backgroundColor: widget.theme.colorScheme.surface,
      displacement: 60,
      child: CustomScrollView(
        key: PageStorageKey<String>('home_category_${widget.category}'),
        cacheExtent: perf.isLowEndDevice
            ? 220
            : (perf.performanceTier == DevicePerformanceTier.midRange
                  ? 420
                  : 640),
        physics: perf.isLowEndDevice
            ? const ClampingScrollPhysics()
            : const AlwaysScrollableScrollPhysics(),
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
                  borderColor: context.colors.errorRed.withValues(alpha: 0.5),
                  backgroundColor: context.colors.errorRed.withValues(
                    alpha: 0.1,
                  ),
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
              articleCount: visibleArticles.length,
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
                childCount: _contentChildCount(visibleArticles.length) + 1,
                addSemanticIndexes: false,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildItem(BuildContext ctx, int index) {
    final articles = _cachedVisibleArticles;
    final contentCount = _contentChildCount(articles.length);

    if (index < contentCount) {
      if (_isInlineAdSlot(index)) {
        return const BannerAdWidget(
          framed: true,
          margin: EdgeInsets.fromLTRB(16, 6, 16, 6),
        );
      }

      final article = articles[_articleIndexForDisplayIndex(index)];
      return Padding(
        // Pre-computed EdgeInsets to avoid object creation per-frame
        padding: EdgeInsets.fromLTRB(
          16,
          _articleIndexForDisplayIndex(index) == 0 ? 4 : 6,
          16,
          _articleIndexForDisplayIndex(index) == articles.length - 1 ? 16 : 6,
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
                  color: context.colors.textHint,
                  fontStyle: FontStyle.italic,
                  fontSize: 13,
                ),
              ),
            ),
          )
        : const SizedBox(height: 16);
  }

  int _contentChildCount(int articleCount) {
    return articleCount + _inlineAdCount(articleCount);
  }

  int _inlineAdCount(int articleCount) {
    if (articleCount <= _firstInlineAdAfterArticles) {
      return 0;
    }
    return 1 +
        ((articleCount - _firstInlineAdAfterArticles - 1) ~/
            _inlineAdEveryArticles);
  }

  bool _isInlineAdSlot(int displayIndex) {
    if (displayIndex < _firstInlineAdAfterArticles) {
      return false;
    }
    return (displayIndex - _firstInlineAdAfterArticles) %
            (_inlineAdEveryArticles + 1) ==
        0;
  }

  int _articleIndexForDisplayIndex(int displayIndex) {
    if (displayIndex <= _firstInlineAdAfterArticles) {
      return displayIndex;
    }
    final adsBefore =
        ((displayIndex - _firstInlineAdAfterArticles - 1) ~/
            (_inlineAdEveryArticles + 1)) +
        1;
    return displayIndex - adsBefore;
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
              color: context.colors.textHint.withValues(alpha: 0.4),
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
