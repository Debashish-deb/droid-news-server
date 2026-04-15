import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/di/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../widgets/premium_scaffold.dart';
import '../../../core/enums/theme_mode.dart';
import '../../../core/theme/theme_skeleton.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../providers/favorites_providers.dart';
import '../../providers/feature_providers.dart';
import '../../providers/tab_providers.dart';
import '../../providers/theme_providers.dart'
    show currentThemeModeProvider, themeSkeletonProvider;
import '../../widgets/app_drawer.dart' show AppDrawer;
import '../../widgets/bouncy_chip_segmented_row.dart';
import '../../widgets/category_chips_bar.dart' show ChipsBar;
import '../../widgets/premium_screen_header.dart'
    show PremiumHeaderIconButton, PremiumHeaderLeading;
import '../../widgets/publisher_brand_card.dart' show PublisherBrandLoadingCard;
import '../../widgets/sticky_header_delegate.dart';
import '../common/publisher_navigation.dart';
import '../publisher_layout/presentation/draggable_publisher_grid.dart';
import '../publisher_layout/publisher_layout_ordering.dart';
import '../publisher_layout/publisher_layout_provider.dart'
    show editModeProvider, publisherIdsProvider, publisherLayoutProvider;
import '../../../core/config/performance_config.dart';
import '../../providers/newspaper_providers.dart';
import 'widgets/newspaper_card.dart';

// Category tags moved to newspaper_providers.dart

class NewspaperScreen extends ConsumerStatefulWidget {
  const NewspaperScreen({super.key});

  @override
  ConsumerState<NewspaperScreen> createState() => _NewspaperScreenState();
}

class _NewspaperScreenState extends ConsumerState<NewspaperScreen>
    with SingleTickerProviderStateMixin {
  static const Duration _kRichContentDelay = Duration(milliseconds: 100);
  static const Duration _kStartupStagedWindow = Duration(milliseconds: 250);
  static const String _layoutKey = 'newspapers';

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

  String? _cachedLocale;
  List<String> _cachedCategories = const [];
  String? _lastLogoPrecacheSignature;

  // Manual caching removed; handled by filteredNewspapersProvider
  static final int _categoriesCount = NewspaperCategory.values.length;
  AppLocalizations get loc => AppLocalizations.of(context);

  static const bool _disableMotion = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ref.read(publisherAssetsDataProvider.future));
    });
    _hasActivatedTab = ref.read(currentTabIndexProvider) == 1;
    if (_hasActivatedTab) {
      _primeTabContent();
    }
    _scrollController = ScrollController();
    _tabController = TabController(length: _categoriesCount, vsync: this)
      ..addListener(_onTabChanged);

    ref.listenManual<int>(currentTabIndexProvider, (prev, next) {
      if (next == 1 && !_hasActivatedTab && mounted) {
        setState(() => _hasActivatedTab = true);
      }
      if (next == 1) {
        _primeTabContent();
      }
      if (next == 1) {
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
    ref.read(newspaperDataProvider.future).then((papers) {
      if (!mounted) return;
      unawaited(
        ref
            .read(publisherLayoutProvider(_layoutKey).notifier)
            .loadOnce(extractPublisherIds(papers)),
      );
      _scheduleLogoPrecache(
        ref.read(filteredNewspapersProvider),
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
    List<dynamic> papers, {
    required double itemExtent,
  }) {
    final count = math.min(14, papers.length);
    if (count <= 0) {
      return;
    }

    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = ((itemExtent * 0.58) * devicePixelRatio).round();
    final cacheHeight = ((itemExtent * 0.22) * devicePixelRatio).round();
    final entries = <MapEntry<String, ImageProvider>>[];
    final signatureBuffer = StringBuffer();

    for (var i = 0; i < count; i++) {
      final paper = papers[i];
      final logoPath = _resolveLogoPath(paper);
      if (logoPath == null) {
        continue;
      }
      final id = paper['id']?.toString() ?? logoPath;
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

    if (entries.isEmpty) {
      return;
    }

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

  String? _resolveLogoPath(Map<dynamic, dynamic> paper) {
    final media = paper['media'];
    if (media != null) {
      final logo = media['logo'];
      if (logo != null && logo.toString().startsWith('assets/')) {
        return logo.toString();
      }
    }
    final id = paper['id']?.toString();
    return id != null ? 'assets/logos/$id.png' : null;
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    final i = _tabController.index;
    ref.read(newspaperTabIndexProvider.notifier).state = i;
    _scheduleJumpToTopIfNeeded();
    ref.read(newspaperLangFilterProvider.notifier).state = null;
  }

  bool _isLanguageFilterCategory(int tabIndex) {
    return tabIndex == NewspaperCategory.national.index ||
        tabIndex == NewspaperCategory.international.index;
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
        ref.read(filteredNewspapersProvider),
        itemExtent: (MediaQuery.sizeOf(context).width - 32) / 3,
      );
    }

    notifier.state = enabled;
    HapticFeedback.selectionClick();
  }

  void _toggleEditMode() =>
      _setEditMode(!ref.read(editModeProvider(_layoutKey)));

  Future<void> _openPublisher(
    BuildContext ctx,
    Map<String, dynamic> paper,
  ) async {
    await openPublisherWebView(
      ctx,
      publisher: paper,
      fallbackTitle: loc.unknownNewspaper,
      noUrlMessage: loc.noUrlAvailable,
      onBeforeOpen: () =>
          ref.read(interstitialAdServiceProvider).onArticleViewed(),
    );
  }

  List<String> _categories(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    if (locale == _cachedLocale) return _cachedCategories;

    final l = AppLocalizations.of(context);
    _cachedLocale = locale;
    _cachedCategories = [
      l.national,
      l.international,
      l.regional,
      l.politics,
      l.economics,
      l.sports,
      l.education,
      l.technology,
    ];
    return _cachedCategories;
  }

  // Filtering moved to filteredNewspapersProvider

  Widget _buildLanguageFilter(
    BuildContext context, {
    required String? selected,
  }) {
    final l = AppLocalizations.of(context);
    return BouncyChipSegmentedRow<String?>(
      options: <SegmentedChipOption<String?>>[
        SegmentedChipOption<String?>(value: null, label: l.all),
        SegmentedChipOption<String?>(value: 'bn', label: l.bangla),
        SegmentedChipOption<String?>(value: 'en', label: l.english),
      ],
      selectedValue: selected,
      disableMotion: _disableMotion,
      onSelected: (value) =>
          ref.read(newspaperLangFilterProvider.notifier).state = value,
    );
  }

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
          final paper = publishers[index];
          return KeyedSubtree(
            key: ValueKey(paper['id']),
            child: NewspaperCard(
              news: paper,
              mode: themeMode,
              skeleton: skeleton,
              preferFlatSurface: true,
              lightweightMode: true,
              isFavorite: false,
              onFavoriteToggle: () {},
              searchQuery: '',
              onTap: () => _openPublisher(ctx, paper),
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
    required Set<String> favoritePaperIds,
  }) {
    return SliverFixedExtentList(
      itemExtent: itemExtent,
      delegate: SliverChildBuilderDelegate(
        (ctx, index) {
          final paper = publishers[index];
          return KeyedSubtree(
            key: ValueKey(paper['id']),
            child: NewspaperCard(
              news: paper,
              mode: themeMode,
              skeleton: skeleton,
              preferFlatSurface: true,
              lightweightMode: true,
              isFavorite: favoritePaperIds.contains(
                paper['id']?.toString() ?? '',
              ),
              onFavoriteToggle: () {
                ref.read(favoritesProvider.notifier).toggleNewspaper(paper);
              },
              searchQuery: '',
              onTap: () => _openPublisher(ctx, paper),
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

  @override
  Widget build(BuildContext context) {
    final isActiveTab = ref.watch(currentTabIndexProvider) == 1;
    if (!_hasActivatedTab && !isActiveTab) {
      return ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: const SizedBox.expand(),
      );
    }

    final categories = _categories(context);
    final themeMode = ref.watch(currentThemeModeProvider);
    final skeleton = ref.watch(themeSkeletonProvider);
    final papersAsync = ref.watch(newspaperDataProvider);
    final perf = PerformanceConfig.of(context);
    final forceStartupFastPath =
        DateTime.now().difference(ref.watch(appSessionStartedAtProvider)) <
        _kStartupStagedWindow;

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isEditMode = ref.watch(editModeProvider(_layoutKey));
    final orderedPublisherIds = ref.watch(publisherIdsProvider(_layoutKey));
    final enableStagedCards =
        forceStartupFastPath ||
        perf.isLowEndDevice ||
        perf.lowPowerMode ||
        perf.reduceEffects;
    final favPapers = !enableStagedCards || _richContentReady || isEditMode
        ? ref.watch(favoriteNewspapersProvider)
        : const <dynamic>[];
    final publisherCardExtent = (MediaQuery.sizeOf(context).width - 32) / 3;

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
        title: isEditMode ? loc.editLayout : loc.news,
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
                heroTag: 'newspaper_edit_fab',
                onPressed: () => _setEditMode(false),
                label: Text(loc.saveLayout),
                icon: const Icon(CupertinoIcons.check_mark),
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
          slivers: <Widget>[
            if (!isEditMode)
              SliverPersistentHeader(
                pinned: true,
                delegate: StickyHeaderDelegate(
                  minHeight: 48,
                  maxHeight: 48,
                  child: Consumer(
                    builder: (ctx, ref, _) {
                      final tabIdx = ref.watch(newspaperTabIndexProvider);
                      return ChipsBar(
                        items: categories,
                        selectedIndex: tabIdx,
                        autoCenter: false,
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
                  ),
                ),
              ),
            if (!isEditMode)
              SliverToBoxAdapter(
                child: Consumer(
                  builder: (ctx, ref, _) {
                    final tabIdx = ref.watch(newspaperTabIndexProvider);
                    if (!_isLanguageFilterCategory(tabIdx)) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Center(
                        child: Consumer(
                          builder: (ctx, ref, _) {
                            final selected = ref.watch(
                              newspaperLangFilterProvider,
                            );
                            return _buildLanguageFilter(
                              ctx,
                              selected: selected,
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            papersAsync.when(
              data: (allPapers) {
                final favoritePaperIds = favPapers
                    .map((paper) => paper['id']?.toString() ?? '')
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
                      final filtered = ref.watch(filteredNewspapersProvider);
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
                              loc.noNewspapers,
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
                          favoritePaperIds: favoritePaperIds,
                        );
                      }

                      return DraggablePublisherGrid(
                        layoutKey: _layoutKey,
                        publishers: orderedFiltered,
                        disableMotion: _disableMotion,
                        asSliver: true,
                        itemExtent: publisherCardExtent,
                        itemBuilder: (ctx, paper) => NewspaperCard(
                          news: paper,
                          mode: themeMode,
                          skeleton: skeleton,
                          preferFlatSurface: true,
                          lightweightMode: true,
                          isFavorite: favoritePaperIds.contains(
                            paper['id']?.toString() ?? '',
                          ),
                          onFavoriteToggle: () {
                            ref
                                .read(favoritesProvider.notifier)
                                .toggleNewspaper(paper);
                          },
                          searchQuery: '',
                          onTap: () => _openPublisher(ctx, paper),
                        ),
                        isFavorite: (paper) => favoritePaperIds.contains(
                          paper['id']?.toString() ?? '',
                        ),
                        onFavoriteToggle: (paper) => () {
                          ref
                              .read(favoritesProvider.notifier)
                              .toggleNewspaper(paper);
                        },
                        onPublisherTap: (paper) => _openPublisher(ctx, paper),
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
}
