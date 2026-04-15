import 'dart:async';
import 'dart:math' as math;
import '../../widgets/premium_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../../../core/di/providers.dart' show interstitialAdServiceProvider;
import '../../../core/enums/theme_mode.dart';
import '../../../l10n/generated/app_localizations.dart' show AppLocalizations;
import '../../widgets/app_drawer.dart';
import '../publisher_layout/presentation/draggable_publisher_grid.dart';
import '../../widgets/sticky_header_delegate.dart';
import '../../../core/theme/theme_skeleton.dart';
import '../../widgets/category_chips_bar.dart';
import '../../widgets/premium_screen_header.dart';
import '../../providers/favorites_providers.dart';
import '../../providers/theme_providers.dart';
import '../../providers/feature_providers.dart';
import '../../providers/tab_providers.dart';
import '../../widgets/publisher_brand_card.dart';
import '../common/publisher_navigation.dart';
import '../publisher_layout/publisher_layout_provider.dart'
    show editModeProvider, publisherIdsProvider, publisherLayoutProvider;
import '../publisher_layout/publisher_layout_ordering.dart';
import '../../../core/config/performance_config.dart';
import 'widgets/magazine_card.dart';

// ─────────────────────────────────────────────
// CATEGORY ENUM  (stable, O(1) comparison)
// ─────────────────────────────────────────────
import '../../providers/magazine_providers.dart';

// Category tags moved to magazine_providers.dart

// ─────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────
class MagazineScreen extends ConsumerStatefulWidget {
  const MagazineScreen({super.key});

  @override
  ConsumerState<MagazineScreen> createState() => _MagazineScreenState();
}

class _MagazineScreenState extends ConsumerState<MagazineScreen>
    with SingleTickerProviderStateMixin {
  static const Duration _kRichContentDelay = Duration(milliseconds: 100);
  static const Duration _kStartupStagedWindow = Duration(milliseconds: 250);
  static const String _layoutKey = 'magazines';

  late final TabController _tabController;
  late final ScrollController _scrollController;

  DateTime? _lastBackPressed;
  bool _hasActivatedTab = false;
  bool _richContentReady = false;
  bool _contentWarmupStarted = false;
  Timer? _richContentTimer;
  Timer? _logoPrecacheDebounce;
  List<MapEntry<String, ImageProvider>>? _pendingLogoPrecacheEntries;
  String? _queuedLogoPrecacheSignature;
  String? _lastLogoPrecacheSignature;

  String? _cachedLocale;
  List<String> _cachedLabels = const [];

  static final int _categoriesCount = MagazineCategory.values.length;
  static const bool _disableMotion = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ref.read(publisherAssetsDataProvider.future));
    });
    _hasActivatedTab = ref.read(currentTabIndexProvider) == 3;
    if (_hasActivatedTab) {
      _primeTabContent();
    }
    _scrollController = ScrollController();
    _tabController = TabController(length: _categoriesCount, vsync: this)
      ..addListener(_onTabChanged);

    ref.listenManual<int>(currentTabIndexProvider, (prev, next) {
      if (next == 3 && !_hasActivatedTab && mounted) {
        setState(() => _hasActivatedTab = true);
      }
      if (next == 3) {
        _primeTabContent();
      }
      if (next == 3) {
        _scheduleJumpToTopIfNeeded();
      }
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _scrollController.dispose();
    _richContentTimer?.cancel();
    _logoPrecacheDebounce?.cancel();
    super.dispose();
  }

  void _primeTabContent() {
    if (_contentWarmupStarted) return;
    _contentWarmupStarted = true;
    ref.read(magazineDataProvider.future).then((magazines) {
      if (!mounted) return;
      unawaited(
        ref
            .read(publisherLayoutProvider(_layoutKey).notifier)
            .loadOnce(extractPublisherIds(magazines)),
      );
      _scheduleLogoPrecache(
        ref.read(filteredMagazinesProvider),
        itemExtent: (MediaQuery.sizeOf(context).width - 32) / 3,
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _richContentReady) return;
      _richContentTimer?.cancel();
      final delay = _richContentPromotionDelay();
      _richContentTimer = Timer(delay, () {
        _richContentTimer = null;
        if (!mounted || _richContentReady) return;
        setState(() => _richContentReady = true);
      });
    });
  }

  Duration _richContentPromotionDelay() {
    final startedAt = ref.read(appSessionStartedAtProvider);
    final elapsed = DateTime.now().difference(startedAt);
    final remainingStartupWarmup = _kStartupStagedWindow - elapsed;
    if (remainingStartupWarmup > _kRichContentDelay) {
      return remainingStartupWarmup;
    }
    return _kRichContentDelay;
  }

  void _scheduleLogoPrecache(
    List<dynamic> magazines, {
    required double itemExtent,
  }) {
    final count = math.min(14, magazines.length);
    if (count <= 0) return;

    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = ((itemExtent * 0.58) * devicePixelRatio).round();
    final cacheHeight = ((itemExtent * 0.22) * devicePixelRatio).round();
    final entries = <MapEntry<String, ImageProvider>>[];
    final signatureBuffer = StringBuffer();

    for (var i = 0; i < count; i++) {
      final magazine = magazines[i];
      final logoPath = _resolveLogoPath(magazine);
      if (logoPath == null) continue;
      final id = magazine['id']?.toString() ?? logoPath;
      signatureBuffer.write('$id|');
      entries.add(
        MapEntry<String, ImageProvider>(
          logoPath,
          ResizeImage.resizeIfNeeded(
            cacheWidth,
            cacheHeight,
            AssetImage(logoPath),
          ),
        ),
      );
    }

    if (entries.isEmpty) return;

    final signature = '${signatureBuffer.toString()}@$cacheWidth:$cacheHeight';
    if (_lastLogoPrecacheSignature == signature ||
        _queuedLogoPrecacheSignature == signature) {
      return;
    }
    _queuedLogoPrecacheSignature = signature;
    _pendingLogoPrecacheEntries = entries;
    _logoPrecacheDebounce?.cancel();
    _logoPrecacheDebounce = Timer(
      const Duration(milliseconds: 180),
      _flushQueuedLogoPrecache,
    );
  }

  void _flushQueuedLogoPrecache() {
    _logoPrecacheDebounce = null;
    if (!mounted) {
      return;
    }
    if (_scrollController.hasClients &&
        _scrollController.position.isScrollingNotifier.value) {
      _logoPrecacheDebounce = Timer(
        const Duration(milliseconds: 120),
        _flushQueuedLogoPrecache,
      );
      return;
    }

    final signature = _queuedLogoPrecacheSignature;
    final entries = _pendingLogoPrecacheEntries;
    if (signature == null || entries == null || entries.isEmpty) {
      return;
    }

    _queuedLogoPrecacheSignature = null;
    _pendingLogoPrecacheEntries = null;
    _lastLogoPrecacheSignature = signature;

    for (final entry in entries) {
      precacheImage(entry.value, context);
    }
  }

  void _jumpToTopIfNeeded() {
    if (!_scrollController.hasClients) {
      return;
    }
    if (_scrollController.position.pixels <= 1) {
      return;
    }
    _scrollController.jumpTo(0);
  }

  void _scheduleJumpToTopIfNeeded() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _jumpToTopIfNeeded();
    });
  }

  String? _resolveLogoPath(Map<dynamic, dynamic> magazine) {
    final media = magazine['media'];
    if (media != null) {
      final logo = media['logo'];
      if (logo != null && logo.toString().startsWith('assets/')) {
        return logo.toString();
      }
    }
    final id = magazine['id']?.toString();
    return id != null ? 'assets/logos/$id.png' : null;
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    final i = _tabController.index;
    ref.read(magazineTabIndexProvider.notifier).state = i;
    _scheduleJumpToTopIfNeeded();
  }

  List<String> _labels(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    if (locale == _cachedLocale) return _cachedLabels;
    _cachedLocale = locale;
    _cachedLabels = [
      loc.fashion,
      loc.science,
      loc.economics,
      loc.worldAffairs,
      loc.technology,
      loc.arts,
      loc.lifestyle,
      loc.sports,
    ];
    return _cachedLabels;
  }

  Future<void> _openPublisher(
    BuildContext ctx,
    Map<String, dynamic> magazine,
  ) async {
    final loc = AppLocalizations.of(ctx);
    await openPublisherWebView(
      ctx,
      publisher: magazine,
      fallbackTitle: loc.unknownMagazine,
      noUrlMessage: loc.noUrlAvailable,
      onBeforeOpen: () =>
          ref.read(interstitialAdServiceProvider).onArticleViewed(),
    );
  }

  void _setEditMode(bool enabled) {
    final notifier = ref.read(editModeProvider(_layoutKey).notifier);
    if (notifier.state == enabled) {
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();

    if (enabled) {
      _primeTabContent();
      _scheduleLogoPrecache(
        ref.read(filteredMagazinesProvider),
        itemExtent: (MediaQuery.sizeOf(context).width - 32) / 3,
      );
    }

    notifier.state = enabled;
    HapticFeedback.selectionClick();
  }

  void _toggleEditMode() =>
      _setEditMode(!ref.read(editModeProvider(_layoutKey)));

  Widget _buildFastPublisherList(
    List<dynamic> publishers,
    AppThemeMode themeMode,
    ThemeSkeleton skeleton,
    double itemExtent,
  ) {
    return SliverFixedExtentList(
      itemExtent: itemExtent,
      delegate: SliverChildBuilderDelegate(
        (ctx, index) {
          final magazine = publishers[index];
          return KeyedSubtree(
            key: ValueKey(magazine['id']),
            child: MagazineCard(
              magazine: magazine,
              mode: themeMode,
              skeleton: skeleton,
              preferFlatSurface: true,
              lightweightMode: true,
              isFavorite: false,
              onFavoriteToggle: () {},
              onTap: () => _openPublisher(ctx, magazine),
            ),
          );
        },
        childCount: publishers.length,
        
      ),
    );
  }

  Widget _buildRichPublisherList(
    List<dynamic> publishers,
    AppThemeMode themeMode,
    ThemeSkeleton skeleton,
    double itemExtent, {
    required Set<String> favoriteMagazineIds,
  }) {
    return SliverFixedExtentList(
      itemExtent: itemExtent,
      delegate: SliverChildBuilderDelegate(
        (ctx, index) {
          final magazine = publishers[index];
          return KeyedSubtree(
            key: ValueKey(magazine['id']),
            child: MagazineCard(
              magazine: magazine,
              mode: themeMode,
              skeleton: skeleton,
              preferFlatSurface: true,
              lightweightMode: true,
              isFavorite: favoriteMagazineIds.contains(
                magazine['id']?.toString() ?? '',
              ),
              onFavoriteToggle: () {
                ref.read(favoritesProvider.notifier).toggleMagazine(magazine);
              },
              onTap: () => _openPublisher(ctx, magazine),
            ),
          );
        },
        childCount: publishers.length,
        
      ),
    );
  }

  Widget _buildLoadingPublisherList(double itemExtent) {
    return SliverPadding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 2, bottom: 80),
      sliver: SliverFixedExtentList(
        itemExtent: itemExtent,
        delegate: SliverChildBuilderDelegate(
          (ctx, index) => const PublisherBrandLoadingCard(),
          childCount: 6,
          
        ),
      ),
    );
  }

  // ... (existing imports updated via replace_file_content block)

  @override
  Widget build(BuildContext context) {
    final isActiveTab = ref.watch(currentTabIndexProvider) == 3;
    if (!_hasActivatedTab && !isActiveTab) {
      return ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: const SizedBox.expand(),
      );
    }

    final labels = _labels(context);
    final themeMode = ref.watch(currentThemeModeProvider);
    final skeleton = ref.watch(themeSkeletonProvider);
    final loc = AppLocalizations.of(context);
    final magsAsync = ref.watch(magazineDataProvider);
    final perf = PerformanceConfig.of(context);
    final forceStartupFastPath =
        DateTime.now().difference(ref.watch(appSessionStartedAtProvider)) <
        _kStartupStagedWindow;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isEditMode = ref.watch(editModeProvider(_layoutKey));
    final orderedPublisherIds = ref.watch(publisherIdsProvider(_layoutKey));
    final publisherCardExtent = (MediaQuery.sizeOf(context).width - 32) / 3;
    final enableStagedCards =
        forceStartupFastPath ||
        perf.isLowEndDevice ||
        perf.lowPowerMode ||
        perf.reduceEffects;
    final favMags = !enableStagedCards || _richContentReady || isEditMode
        ? ref.watch(favoriteMagazinesProvider)
        : const <dynamic>[];

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        if (isEditMode) {
          _setEditMode(false);
          return;
        }
        final now = DateTime.now();
        if (_lastBackPressed == null ||
            now.difference(_lastBackPressed!) > const Duration(seconds: 2)) {
          _lastBackPressed = now;
          Fluttertoast.showToast(msg: loc.pressBackToExit);
          return;
        }
        await SystemNavigator.pop();
      },
      child: PremiumScaffold(
        useBackground: false, // Hosted in MainNavigationScreen
        showBackgroundParticles: false,
        drawer: const AppDrawer(),
        title: isEditMode ? loc.editLayout : loc.magazines,
        headerLeading: PremiumHeaderLeading.menu,
        headerActions: [
          PremiumHeaderIconButton(
            icon: isEditMode ? Icons.check_rounded : Icons.edit_note_rounded,
            onPressed: _toggleEditMode,
            tooltip: isEditMode ? loc.done : loc.editLayout,
          ),
        ],
        floatingActionButton: isEditMode
            ? FloatingActionButton.extended(
                heroTag: 'magazine_edit_fab',
                onPressed: () => _setEditMode(false),
                label: Text(loc.saveLayout),
                icon: const Icon(Icons.check),
                backgroundColor: scheme.tertiary,
                foregroundColor: Colors.black,
              )
            : null,
        body: CustomScrollView(
          controller: _scrollController,
          cacheExtent: PerformanceConfig.of(context).isLowEndDevice ? 480 : 960,
          physics: PerformanceConfig.of(context).isLowEndDevice
              ? const ClampingScrollPhysics()
              : const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (!isEditMode)
              SliverPersistentHeader(
                pinned: true,
                delegate: StickyHeaderDelegate(
                  minHeight: 48,
                  maxHeight: 48,
                  child: _buildChipsBar(labels),
                ),
              ),
            magsAsync.when(
              data: (allMags) {
                final favoriteMagazineIds = favMags
                    .map((magazine) => magazine['id']?.toString() ?? '')
                    .where((id) => id.isNotEmpty)
                    .toSet();
                return SliverPadding(
                  padding: const EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 2,
                    bottom: 80,
                  ),
                  sliver: Consumer(
                    builder: (ctx, ref, _) {
                      final filtered = ref.watch(filteredMagazinesProvider);
                      final orderedFiltered = orderPublishersByLayout(
                        filtered,
                        orderedPublisherIds,
                      );
                      _scheduleLogoPrecache(
                        orderedFiltered,
                        itemExtent: publisherCardExtent,
                      );
                      final useFastPath =
                          enableStagedCards &&
                          !_richContentReady &&
                          !isEditMode;
                      if (orderedFiltered.isEmpty) {
                        return SliverToBoxAdapter(
                          child: Center(
                            child: Text(
                              loc.noMagazines,
                              style: theme.textTheme.bodyLarge,
                            ),
                          ),
                        );
                      }
                      if (useFastPath) {
                        return _buildFastPublisherList(
                          orderedFiltered,
                          themeMode,
                          skeleton,
                          publisherCardExtent,
                        );
                      }
                      if (!isEditMode) {
                        return _buildRichPublisherList(
                          orderedFiltered,
                          themeMode,
                          skeleton,
                          publisherCardExtent,
                          favoriteMagazineIds: favoriteMagazineIds,
                        );
                      }
                      return DraggablePublisherGrid(
                        layoutKey: _layoutKey,
                        publishers: orderedFiltered,
                        disableMotion: _disableMotion,
                        asSliver: true,
                        itemExtent: publisherCardExtent,
                        itemBuilder: (ctx, mag) => MagazineCard(
                          magazine: mag,
                          mode: themeMode,
                          skeleton: skeleton,
                          preferFlatSurface: true,
                          lightweightMode: true,
                          isFavorite: favoriteMagazineIds.contains(
                            mag['id']?.toString() ?? '',
                          ),
                          onFavoriteToggle: () {
                            ref
                                .read(favoritesProvider.notifier)
                                .toggleMagazine(mag);
                          },
                          onTap: () => _openPublisher(ctx, mag),
                        ),
                        isFavorite: (mag) => favoriteMagazineIds.contains(
                          mag['id']?.toString() ?? '',
                        ),
                        onFavoriteToggle: (mag) => () {
                          ref
                              .read(favoritesProvider.notifier)
                              .toggleMagazine(mag);
                        },
                        onPublisherTap: (mag) => _openPublisher(ctx, mag),
                      );
                    },
                  ),
                );
              },
              loading: () => _buildLoadingPublisherList(publisherCardExtent),
              error: (err, _) => SliverFillRemaining(
                child: Center(child: Text('${loc.error}: $err')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChipsBar(List<String> labels) {
    return Consumer(
      builder: (ctx, ref, _) {
        final tabIdx = ref.watch(magazineTabIndexProvider);
        return ChipsBar(
          items: labels,
          selectedIndex: tabIdx,
          disableMotion: _disableMotion,
          onTap: (i) {
            if (_tabController.index != i) {
              _tabController.animateTo(
                i,
                duration: _disableMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 120),
                curve: Curves.easeOutCubic,
              );
            } else {
              _scheduleJumpToTopIfNeeded();
            }
          },
        );
      },
    );
  }
}
