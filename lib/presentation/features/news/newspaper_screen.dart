import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/di/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';

import '../../../core/navigation/app_paths.dart';
import '../../../core/theme/theme.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../providers/favorites_providers.dart';
import '../../providers/feature_providers.dart';
import '../../providers/tab_providers.dart';
import '../../providers/theme_providers.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/category_chips_bar.dart';
import '../../widgets/glass_icon_button.dart';
import '../../widgets/sticky_header_delegate.dart';
import '../../widgets/unlock_article_dialog.dart';
import '../common/app_bar.dart';
import '../common/webview_args.dart';
import '../publisher_layout/presentation/draggable_publisher_grid.dart';
import '../publisher_layout/publisher_layout_provider.dart'
    show editModeProvider;

enum _PaperCat {
  national,
  international,
  regional,
  politics,
  economics,
  sports,
  education,
  technology,
}

const _paperCatTags = <_PaperCat, List<String>>{
  _PaperCat.national: ['national'],
  _PaperCat.international: ['international'],
  _PaperCat.regional: ['regional'],
  _PaperCat.politics: ['politics'],
  _PaperCat.economics: ['economics', 'business'],
  _PaperCat.sports: ['sports'],
  _PaperCat.education: ['education'],
  _PaperCat.technology: ['technology'],
};

final Map<_PaperCat, Set<String>> _paperCatTagSets = <_PaperCat, Set<String>>{
  for (final entry in _paperCatTags.entries)
    entry.key: entry.value.map((tag) => tag.toLowerCase().trim()).toSet(),
};

class NewspaperScreen extends ConsumerStatefulWidget {
  const NewspaperScreen({super.key});

  @override
  ConsumerState<NewspaperScreen> createState() => _NewspaperScreenState();
}

class _NewspaperScreenState extends ConsumerState<NewspaperScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final ScrollController _scrollController;

  final _tabIndexNotifier = ValueNotifier<int>(0);
  final _langFilterNotifier = ValueNotifier<String?>(null); // en|bn|null

  DateTime? _lastBackPressed;

  String? _cachedLocale;
  List<String> _cachedCategories = const [];

  Object? _lastDataRef;
  int? _lastTabIndex;
  String? _lastLangFilter;
  List<dynamic> _cachedFiltered = const [];

  static final int _categoriesCount = _PaperCat.values.length;
  AppLocalizations get loc => AppLocalizations.of(context);

  static const bool _disableMotion = true;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _tabController = TabController(length: _categoriesCount, vsync: this)
      ..addListener(_onTabChanged);

    ref.listenManual<int>(currentTabIndexProvider, (prev, next) {
      if (next == 1 && _scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _scrollController.dispose();
    _tabIndexNotifier.dispose();
    _langFilterNotifier.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    final i = _tabController.index;
    _tabIndexNotifier.value = i;
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    if (_langFilterNotifier.value != null) {
      _langFilterNotifier.value = null;
    }
  }

  bool _isLanguageFilterCategory(int tabIndex) {
    return tabIndex == _PaperCat.national.index ||
        tabIndex == _PaperCat.international.index;
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

  List<dynamic> _filterPapers(
    List<dynamic> allPapers,
    int tabIndex,
    String? langFilter,
  ) {
    if (identical(allPapers, _lastDataRef) &&
        tabIndex == _lastTabIndex &&
        langFilter == _lastLangFilter) {
      return _cachedFiltered;
    }

    _lastDataRef = allPapers;
    _lastTabIndex = tabIndex;
    _lastLangFilter = langFilter;

    final cat = _PaperCat.values[tabIndex];
    final keywords = _paperCatTagSets[cat]!;
    final filtered = <dynamic>[];

    for (final paper in allPapers) {
      if (paper is! Map) continue;
      final rawTags = paper['tags'];
      if (rawTags is! List || rawTags.isEmpty) continue;

      var hasCategory = false;
      for (final rawTag in rawTags) {
        final tag = rawTag?.toString().toLowerCase().trim();
        if (tag == null || tag.isEmpty) continue;
        if (keywords.contains(tag)) {
          hasCategory = true;
          break;
        }
      }

      if (!hasCategory) continue;
      if (langFilter != null && paper['language'] != langFilter) {
        continue;
      }
      filtered.add(paper);
    }

    _cachedFiltered = List<dynamic>.unmodifiable(filtered);

    return _cachedFiltered;
  }

  Widget _buildLanguageFilter(
    BuildContext context, {
    required String? selected,
  }) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: theme.brightness == Brightness.light
              ? Colors.black.withValues(alpha: 0.02)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: theme.brightness == Brightness.light
                ? Colors.black.withValues(alpha: 0.05)
                : Colors.white.withValues(alpha: 0.1),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Bouncy3DChip(
              label: l.all,
              selected: selected == null,
              disableMotion: _disableMotion,
              onTap: () => _langFilterNotifier.value = null,
            ),
            const SizedBox(width: 8),
            Bouncy3DChip(
              label: l.bangla,
              selected: selected == 'bn',
              disableMotion: _disableMotion,
              onTap: () => _langFilterNotifier.value = 'bn',
            ),
            const SizedBox(width: 8),
            Bouncy3DChip(
              label: l.english,
              selected: selected == 'en',
              disableMotion: _disableMotion,
              onTap: () => _langFilterNotifier.value = 'en',
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = _categories(context);
    final themeMode = ref.watch(currentThemeModeProvider);
    final papersAsync = ref.watch(newspaperDataProvider);
    final favPapers = ref.watch(favoriteNewspapersProvider);

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isEditMode = ref.watch(editModeProvider);
    final colors = AppGradients.getBackgroundGradient(themeMode);

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
          children: <Widget>[
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    colors[0].withValues(alpha: 0.9),
                    colors[1].withValues(alpha: 0.9),
                  ],
                ),
              ),
            ),
            CustomScrollView(
              controller: _scrollController,
              slivers: <Widget>[
                SliverAppBar(
                  pinned: true,
                  backgroundColor: scheme.surface,
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
                      : AppBarTitle(loc.news),
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
                            icon: const Icon(Icons.edit_note_rounded, size: 28),
                            onPressed: () =>
                                ref.read(editModeProvider.notifier).state =
                                    true,
                            tooltip: loc.editLayout,
                          ),
                        ],
                ),

                if (!isEditMode)
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: StickyHeaderDelegate(
                      minHeight: 54, // Match ChipsBar height
                      maxHeight: 54,
                      child: RepaintBoundary(
                        child: ValueListenableBuilder<int>(
                          valueListenable: _tabIndexNotifier,
                          builder: (ctx, tabIdx, _) => ChipsBar(
                            items: categories,
                            selectedIndex: tabIdx,
                            autoCenter: false,
                            disableMotion: _disableMotion,
                            onTap: (i) {
                              if (_tabController.index != i) {
                                _tabController.index = i;
                                _tabIndexNotifier.value = i;
                              }
                              if (_scrollController.hasClients) {
                                _scrollController.jumpTo(0);
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ),

                if (!isEditMode)
                  SliverToBoxAdapter(
                    child: ValueListenableBuilder<int>(
                      valueListenable: _tabIndexNotifier,
                      builder: (ctx, tabIdx, _) {
                        if (!_isLanguageFilterCategory(tabIdx)) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Center(
                            child: ValueListenableBuilder<String?>(
                              valueListenable: _langFilterNotifier,
                              builder: (ctx, selected, _) =>
                                  _buildLanguageFilter(ctx, selected: selected),
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
                      sliver: ValueListenableBuilder<int>(
                        valueListenable: _tabIndexNotifier,
                        builder: (ctx, tabIdx, _) {
                          return ValueListenableBuilder<String?>(
                            valueListenable: _langFilterNotifier,
                            builder: (ctx, langFilter, _) {
                              final filtered = _filterPapers(
                                allPapers,
                                tabIdx,
                                langFilter,
                              );

                              if (filtered.isEmpty) {
                                return SliverToBoxAdapter(
                                  child: Center(
                                    child: Text(
                                      loc.noNewspapers,
                                      style: theme.textTheme.bodyLarge,
                                    ),
                                  ),
                                );
                              }

                              return DraggablePublisherGrid(
                                layoutKey: 'newspapers',
                                publishers: filtered,
                                disableMotion: _disableMotion,
                                asSliver: true,
                                isFavorite: (paper) => favoritePaperIds
                                    .contains(paper['id']?.toString() ?? ''),
                                onFavoriteToggle: (paper) => () {
                                  ref
                                      .read(favoritesProvider.notifier)
                                      .toggleNewspaper(paper);
                                },
                                onPublisherTap: (paper) async {
                                  final tags = List<String>.from(
                                    paper['tags'] as List? ?? const [],
                                  );
                                  final isPremium = tags.contains('premium');
                                  final maybeWebsite =
                                      paper['contact']?['website'];
                                  final maybeUrl =
                                      paper['url'] ?? paper['link'];
                                  final url =
                                      (maybeWebsite is String &&
                                          maybeWebsite.isNotEmpty)
                                      ? maybeWebsite
                                      : (maybeUrl is String ? maybeUrl : '');
                                  final title =
                                      paper['name'] as String? ??
                                      loc.unknownNewspaper;

                                  if (url.isEmpty) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(
                                        content: Text(loc.noUrlAvailable),
                                      ),
                                    );
                                    return;
                                  }

                                  if (isPremium) {
                                    final unlocked = await showUnlockDialog(
                                      ctx,
                                      url,
                                      title,
                                    );
                                    if (!unlocked) return;
                                  }
                                  if (!ctx.mounted) return;

                                  ref
                                      .read(interstitialAdServiceProvider)
                                      .onArticleViewed();

                                  if (!mounted) return;
                                  final parsed = Uri.tryParse(url);
                                  if (parsed == null) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(
                                        content: Text(loc.invalidArticleData),
                                      ),
                                    );
                                    return;
                                  }

                                  final uri = parsed.hasScheme
                                      ? parsed
                                      : Uri.tryParse('https://$url');
                                  if (uri == null) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(
                                        content: Text(loc.invalidArticleData),
                                      ),
                                    );
                                    return;
                                  }

                                  ctx.push(
                                    AppPaths.webview,
                                    extra: WebViewArgs(
                                      url: uri,
                                      title: title,
                                      origin: WebViewOrigin.publisher,
                                    ),
                                  );
                                },
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
                icon: const Icon(CupertinoIcons.check_mark),
                backgroundColor: scheme.tertiary,
                foregroundColor: Colors.black,
              )
            : null,
      ),
    );
  }
}
