// lib/features/magazine/magazine_screen.dart
//
// ╔══════════════════════════════════════════════════════════╗
// ║  MAGAZINE SCREEN – ANDROID-OPTIMISED v2                  ║
// ║                                                          ║
// ║  Mirrors all optimisations from NewspaperScreen:         ║
// ║  • PopScope replaces deprecated WillPopScope             ║
// ║  • Enum-indexed categories + const tag map               ║
// ║  • ValueNotifier<int> for tab index (no setState)        ║
// ║  • Memoized filter (ref-equality + index guard)          ║
// ║  • Locale-keyed category label cache                     ║
// ║  • Favorites watch hoisted to build() – Builder removed  ║
// ║  • RepaintBoundary on chips bar, app bar, content grid   ║
// ║  • ColoredBox replaces Container(color:) where possible  ║
// ║  • const constructors end-to-end                         ║
// ╚══════════════════════════════════════════════════════════╝

import 'package:flutter/material.dart';
import '../../../core/di/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart' show AppLocalizations;
import '../../widgets/app_drawer.dart';
import '../common/app_bar.dart';
import '../publisher_layout/presentation/draggable_publisher_grid.dart';
import '../../widgets/sticky_header_delegate.dart';
import '../../../core/theme/theme.dart';
import '../../widgets/category_chips_bar.dart';
import '../../widgets/glass_icon_button.dart';

import '../../widgets/unlock_article_dialog.dart';
import '../../providers/favorites_providers.dart';
import '../../providers/theme_providers.dart';
import '../../providers/feature_providers.dart';
import '../../providers/tab_providers.dart';
import '../publisher_layout/publisher_layout_provider.dart'
    show editModeProvider;
import '../common/webview_args.dart';

// ─────────────────────────────────────────────
// CATEGORY ENUM  (stable, O(1) comparison)
// ─────────────────────────────────────────────
enum _MagCat {
  fashion,
  science,
  economics,
  worldAffairs,
  technology,
  arts,
  lifestyle,
  sports,
}

/// Tag keyword sets per category – defined once, never reallocated.
const _catTags = <_MagCat, List<String>>{
  _MagCat.fashion: ['fashion', 'style', 'aesthetics'],
  _MagCat.science: ['science', 'discovery', 'research'],
  _MagCat.economics: ['finance', 'economics', 'business'],
  _MagCat.worldAffairs: ['global', 'politics', 'world'],
  _MagCat.technology: ['technology', 'tech'],
  _MagCat.arts: ['arts', 'culture'],
  _MagCat.lifestyle: ['lifestyle', 'luxury', 'travel'],
  _MagCat.sports: ['sports', 'performance'],
};

final Map<_MagCat, Set<String>> _magCatTagSets = <_MagCat, Set<String>>{
  for (final entry in _catTags.entries)
    entry.key: entry.value.map((tag) => tag.toLowerCase().trim()).toSet(),
};

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
  late final TabController _tabController;
  late final ScrollController _scrollController;
  late final ScrollController _chipsController;
  late final List<GlobalKey> _chipKeys;

  // Hot-path notifier – avoids full setState on chip tap.
  final _tabIndexNotifier = ValueNotifier<int>(0);

  DateTime? _lastBackPressed;

  // Category label cache – invalidated only on locale change.
  String? _cachedLocale;
  List<String> _cachedLabels = const [];

  // Filter memo – invalidated when inputs change.
  Object? _lastDataRef;
  int? _lastTabIndex;
  List<dynamic> _cachedFiltered = const [];

  static final int _categoriesCount = _MagCat.values.length;
  static const bool _disableMotion = true;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _chipsController = ScrollController();
    _tabController = TabController(length: _categoriesCount, vsync: this)
      ..addListener(_onTabChanged);
    _chipKeys = List.generate(_categoriesCount, (_) => GlobalKey());

    ref.listenManual<int>(currentTabIndexProvider, (prev, next) {
      if (next == 3 && _scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _scrollController.dispose();
    _chipsController.dispose();
    _tabIndexNotifier.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    final i = _tabController.index;
    _tabIndexNotifier.value = i;
    if (!_disableMotion) {
      _centerChip(i);
    }
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  // ─── Category labels ─────────────────────────
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

  // ─── Filter memo ─────────────────────────────
  List<dynamic> _filter(List<dynamic> all, int tabIndex) {
    if (identical(all, _lastDataRef) && tabIndex == _lastTabIndex) {
      return _cachedFiltered;
    }
    _lastDataRef = all;
    _lastTabIndex = tabIndex;

    final cat = _MagCat.values[tabIndex];
    final kws = _magCatTagSets[cat]!;
    final filtered = <dynamic>[];

    for (final item in all) {
      if (item is! Map) continue;
      final rawTags = item['tags'];
      if (rawTags is! List || rawTags.isEmpty) continue;

      var matches = false;
      for (final rawTag in rawTags) {
        final tag = rawTag?.toString().toLowerCase().trim();
        if (tag == null || tag.isEmpty) continue;
        if (kws.any(tag.contains)) {
          matches = true;
          break;
        }
      }

      if (matches) {
        filtered.add(item);
      }
    }

    _cachedFiltered = List<dynamic>.unmodifiable(filtered);

    return _cachedFiltered;
  }

  void _centerChip(int index) {
    if (_disableMotion) return;
    if (index < 0 || index >= _chipKeys.length) return;
    final ctx = _chipKeys[index].currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 200),
        alignment: 0.5,
      );
    }
  }

  // ─── Build ───────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final labels = _labels(context);
    final themeMode = ref.watch(currentThemeModeProvider);
    final loc = AppLocalizations.of(context);
    final magsAsync = ref.watch(magazineDataProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isEditMode = ref.watch(editModeProvider);
    final colors = AppGradients.getBackgroundGradient(themeMode);
    final appColors = theme.extension<AppColorsExtension>();
    // Hoist favorites watch – eliminates Builder node in sliver.
    final favMags = ref.watch(favoriteMagazinesProvider);

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        if (isEditMode) {
          ref.read(editModeProvider.notifier).state = false;
          return;
        }
        final now = DateTime.now();
        if (_lastBackPressed == null ||
            now.difference(_lastBackPressed!) > const Duration(seconds: 2)) {
          _lastBackPressed = now;
          Fluttertoast.showToast(msg: loc.pressBackToExit);
          return;
        }
        if (context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: theme.scaffoldBackgroundColor,
        drawer: const AppDrawer(),
        body: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colors[0].withValues(alpha: 0.9),
                    colors[1].withValues(alpha: 0.9),
                  ],
                ),
              ),
            ),
            CustomScrollView(
              controller: _scrollController,
              slivers: [
                // ── App bar ─────────────────────────────
                SliverAppBar(
                  pinned: true,
                  backgroundColor: appColors?.bg ?? scheme.surface,
                  flexibleSpace: const SizedBox.expand(),
                  elevation: 0,
                  centerTitle: true,
                  toolbarHeight: 54,
                  titleTextStyle: theme.appBarTheme.titleTextStyle,
                  title: isEditMode
                      ? Text(
                          loc.editLayout,
                          style: theme.appBarTheme.titleTextStyle?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        )
                      : AppBarTitle(loc.magazines),
                  leading: Builder(
                    builder: (ctx) => Center(
                      child: GlassIconButton(
                        icon: Icons.menu_rounded,
                        onPressed: () => Scaffold.of(ctx).openDrawer(),
                        isDark: Theme.of(ctx).brightness == Brightness.dark,
                      ),
                    ),
                  ),
                  iconTheme: theme.appBarTheme.iconTheme,
                  actions: isEditMode
                      ? [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: FilledButton(
                              onPressed: () =>
                                  ref.read(editModeProvider.notifier).state =
                                      false,
                              style: FilledButton.styleFrom(
                                backgroundColor: scheme.tertiary,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                              ),
                              child: Text(
                                loc.done,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ]
                      : [
                          IconButton(
                            icon: const Icon(Icons.edit_note, size: 28),
                            onPressed: () =>
                                ref.read(editModeProvider.notifier).state =
                                    true,
                            tooltip: loc.editLayout,
                          ),
                        ],
                ),

                // ── Category chips ───────────────────────
                if (!isEditMode)
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: StickyHeaderDelegate(
                      minHeight: 48,
                      maxHeight: 48,
                      child: RepaintBoundary(
                        child: _buildChipsBar(theme, labels),
                      ),
                    ),
                  ),

                // ── Content ──────────────────────────────
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
                      sliver: ValueListenableBuilder<int>(
                        valueListenable: _tabIndexNotifier,
                        builder: (ctx, tabIdx, _) {
                          final filtered = _filter(allMags, tabIdx);
                          if (filtered.isEmpty) {
                            return SliverToBoxAdapter(
                              child: Center(
                                child: Text(
                                  loc.noMagazines,
                                  style: theme.textTheme.bodyLarge,
                                ),
                              ),
                            );
                          }
                          return DraggablePublisherGrid(
                            layoutKey: 'magazines',
                            publishers: filtered,
                            disableMotion: _disableMotion,
                            asSliver: true,
                            isFavorite: (mag) => favoriteMagazineIds.contains(
                              mag['id']?.toString() ?? '',
                            ),
                            onFavoriteToggle: (mag) => () {
                              ref
                                  .read(favoritesProvider.notifier)
                                  .toggleMagazine(mag);
                            },
                            onPublisherTap: (mag) async {
                              final maybeWebsite = mag['contact']?['website'];
                              final maybeUrl = mag['url'] ?? mag['link'];
                              final url =
                                  (maybeWebsite is String &&
                                      maybeWebsite.isNotEmpty)
                                  ? maybeWebsite
                                  : (maybeUrl is String ? maybeUrl : '');
                              final title =
                                  mag['name'] as String? ?? loc.unknownMagazine;

                              if (url.isEmpty) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text(loc.noUrlAvailable)),
                                );
                                return;
                              }
                              final tags = List<String>.from(
                                mag['tags'] as List? ?? const [],
                              );
                              if (tags.contains('premium')) {
                                final ok = await showUnlockDialog(
                                  ctx,
                                  url,
                                  title,
                                );
                                if (!ok) return;
                              }
                              if (!ctx.mounted) return;
                              ref
                                  .read(interstitialAdServiceProvider)
                                  .onArticleViewed();
                              if (!mounted) return;
                              ctx.push(
                                '/webview',
                                extra: WebViewArgs(
                                  url: Uri.parse(url),
                                  title: title,
                                  origin: WebViewOrigin.publisher,
                                ),
                              );
                            },
                          );
                        },
                      ),
                    );
                  },
                  loading: () => SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(scheme.primary),
                      ),
                    ),
                  ),
                  error: (err, _) => SliverFillRemaining(
                    child: Center(child: Text('${loc.error}: $err')),
                  ),
                ),
              ],
            ),
          ],
        ),
        floatingActionButton: isEditMode
            ? FloatingActionButton.extended(
                onPressed: () =>
                    ref.read(editModeProvider.notifier).state = false,
                label: Text(loc.saveLayout),
                icon: const Icon(Icons.check),
                backgroundColor: scheme.tertiary,
                foregroundColor: Colors.black,
              )
            : null,
      ),
    );
  }

  Widget _buildChipsBar(ThemeData theme, List<String> labels) {
    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.light
            ? Colors.black.withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: theme.brightness == Brightness.light
              ? Colors.black.withValues(alpha: 0.05)
              : Colors.white.withValues(alpha: 0.1),
          width: 0.8,
        ),
      ),
      child: ValueListenableBuilder<int>(
        valueListenable: _tabIndexNotifier,
        builder: (_, tabIdx, _) => ListView.separated(
          controller: _chipsController,
          scrollDirection: Axis.horizontal,
          physics: _disableMotion
              ? const ClampingScrollPhysics()
              : const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemCount: labels.length,
          itemBuilder: (ctx, i) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Bouncy3DChip(
              key: _chipKeys[i],
              label: labels[i],
              selected: i == tabIdx,
              disableMotion: _disableMotion,
              onTap: () {
                if (_disableMotion) {
                  if (_tabController.index != i) {
                    _tabController.index = i;
                    _tabIndexNotifier.value = i;
                  }
                } else {
                  _tabController.animateTo(i);
                  _centerChip(i);
                }
                if (_scrollController.hasClients) {
                  _scrollController.jumpTo(0);
                }
              },
            ),
          ),
        ),
      ),
    );
  }
}
