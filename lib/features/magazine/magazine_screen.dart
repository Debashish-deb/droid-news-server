import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme_provider.dart';
import '../../core/services/favorites_providers.dart';
import '../../core/theme.dart';
import '/l10n/app_localizations.dart';
import '../../widgets/app_drawer.dart';
import '../../features/common/app_bar.dart';
import 'widgets/magazine_card.dart';
import '../../widgets/animated_theme_container.dart';
import '../../presentation/providers/theme_providers.dart';
import '../../presentation/providers/tab_providers.dart';

class MagazineScreen extends ConsumerStatefulWidget {
  const MagazineScreen({super.key});

  @override
  ConsumerState<MagazineScreen> createState() => _MagazineScreenState();
}

class _MagazineScreenState extends ConsumerState<MagazineScreen>
    with SingleTickerProviderStateMixin {
  final List<dynamic> magazines = <dynamic>[];
  bool _isLoading = true;

  late final TabController _tabController;
  late final ScrollController _scrollController;
  late final ScrollController _chipsController;
  late final List<GlobalKey> _chipKeys;

  DateTime? _lastBackPressed;
  bool _firstBuild = true; // Track first build for scroll reset

  static const int _categoriesCount = 8;
  // Removed static _gold, using Theme.of(context).colorScheme.tertiary instead

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _chipsController = ScrollController();
    _tabController = TabController(length: _categoriesCount, vsync: this)
      ..addListener(() {
        if (!_tabController.indexIsChanging) {
          // Tab changed
          _centerChip(_tabController.index);
          // Jump to top of content
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(0);
          }
          setState(() {});
        }
      });
    _chipKeys = List.generate(_categoriesCount, (_) => GlobalKey());
    _loadMagazines();

    // Listen to main tab changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Tab listener managed by Riverpod - removed;
      }
    });
  }

  void _onMainTabChanged() {
    if (!mounted) return;
    final int currentTab = ref.watch(currentTabIndexProvider);
    // This is tab 2 (Magazine)
    if (currentTab == 2 && _scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  // ────────────────────────────────────────────────
  // Data loading & helpers
  // ────────────────────────────────────────────────

  Future<void> _loadMagazines() async {
    setState(() => _isLoading = true);
    try {
      final String raw = await rootBundle.loadString('assets/data.json');
      final data = json.decode(raw);
      setState(() {
        magazines
          ..clear()
          ..addAll(data['magazines'] ?? <dynamic>[]);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Load failed: $e')));
    }
  }

  Future<bool> _onWillPop() async {
    final DateTime now = DateTime.now();
    if (_lastBackPressed == null ||
        now.difference(_lastBackPressed!) > const Duration(seconds: 2)) {
      _lastBackPressed = now;
      Fluttertoast.showToast(msg: 'Press back again to exit');
      return false;
    }
    return true;
  }

  // ────────────────────────────────────────────────
  // Categories & filtering
  // ────────────────────────────────────────────────

  List<String> _categories(BuildContext context) {
    final AppLocalizations loc = AppLocalizations.of(context)!;

    return <String>[
      loc.catFashion,
      loc.catScience,
      loc.catFinance,
      loc.catAffairs,
      loc.catTech,
      loc.catArts,
      loc.catLifestyle,
      loc.catSports,
    ];
  }

  List<dynamic> get _filteredMagazines {
    final List<String> cats = _categories(context);
    final Map<String, List<String>> keys = <String, List<String>>{
      cats[0]: <String>['fashion', 'style', 'aesthetics'],
      cats[1]: <String>['science', 'discovery', 'research'],
      cats[2]: <String>['finance', 'economics', 'business'],
      cats[3]: <String>['global', 'politics', 'world'],
      cats[4]: <String>['technology', 'tech'],
      cats[5]: <String>['arts', 'culture'],
      cats[6]: <String>['lifestyle', 'luxury', 'travel'],
      cats[7]: <String>['sports', 'performance'],
    };
    final String sel = cats[_tabController.index];
    final List<String> kws = keys[sel] ?? <String>[];
    return magazines.where((m) {
      final List<String> tags = List<String>.from(m['tags'] ?? <dynamic>[]);
      return tags.any(
        (String t) => kws.any((String kw) => t.toLowerCase().contains(kw)),
      );
    }).toList();
  }

  void _centerChip(int index) {
    final GlobalKey<State<StatefulWidget>> key = _chipKeys[index];
    if (key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 200),
        alignment: 0.5,
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Reset scroll when returning to this main tab
    if (!_firstBuild && _scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
      });
    }
    _firstBuild = false;
  }

  @override
  void dispose() {
    try {
      // Tab listener managed by Riverpod - removed;
    } catch (e) {
      // Context might be unavailable
    }
    _scrollController.dispose();
    _chipsController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // ────────────────────────────────────────────────
  // UI
  // ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final AppThemeMode themeMode = ref.watch(currentThemeModeProvider);
    final AppLocalizations loc = AppLocalizations.of(context)!;

    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;

    final AppThemeMode mode = themeMode;
    // Use getBackgroundGradient for correct Dark Mode colors (Black)
    final List<Color> colors = AppGradients.getBackgroundGradient(mode);
    final Color start = colors[0], end = colors[1];
    final List<String> categories = _categories(context);

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: scheme.surface,
        drawer: const AppDrawer(),
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // Backdrop gradient
            AnimatedThemeContainer(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[
                    colors[0].withOpacity(0.85),
                    colors[1].withOpacity(0.85),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),

            // Main scroll view
            CustomScrollView(
              controller:
                  _scrollController, // Attach controller for manual reset
              key: const PageStorageKey('magazine_scroll'),
              slivers: <Widget>[
                // ----- AppBar ------------------------------------------------
                SliverAppBar(
                  pinned: true,
                  backgroundColor: theme.appBarTheme.backgroundColor,
                  elevation: theme.appBarTheme.elevation,
                  centerTitle: true,
                  titleTextStyle: theme.appBarTheme.titleTextStyle,
                  title: AppBarTitle(loc.magazines),
                  iconTheme: theme.appBarTheme.iconTheme,
                ),

                // ----- Category chips --------------------------------------
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 48,
                    child: ListView.builder(
                      controller: _chipsController,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: categories.length,
                      itemBuilder: (BuildContext ctx, int i) {
                        final bool sel = i == _tabController.index;
                        return Padding(
                          key: _chipKeys[i],
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: ChoiceChip(
                            label: Text(categories[i]),
                            selected: sel,
                            onSelected: (_) {
                              _tabController.animateTo(i);
                              _centerChip(i);
                              if (_scrollController.hasClients) {
                                _scrollController.jumpTo(0);
                              }
                            },
                            backgroundColor: scheme.surface.withOpacity(0.5),
                            selectedColor: scheme.tertiary,
                            labelStyle: TextStyle(
                              color: sel ? Colors.black : scheme.onSurface,
                              fontWeight:
                                  sel ? FontWeight.bold : FontWeight.w600,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // ----- Magazine cards --------------------------------------
                SliverFillRemaining(
                  child:
                      _isLoading
                          ? Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation(
                                scheme.primary,
                              ),
                            ),
                          )
                          : _filteredMagazines.isEmpty
                          ? Center(
                            child: Text(
                              loc.noMagazines,
                              style: theme.textTheme.bodyLarge,
                            ),
                          )
                          : RefreshIndicator(
                            color: scheme.primary,
                            onRefresh: _loadMagazines,
                            child: ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.only(
                                left: 16,
                                right: 16,
                                top: 16,
                                bottom: 80,
                              ), // Bottom padding for nav bar
                              itemCount: _filteredMagazines.length,
                              itemBuilder: (_, int idx) {
                                final m = _filteredMagazines[idx];
                                final String id = m['id'].toString();
                                // Use Riverpod for favorites
                                final bool isFav = ref.watch(
                                  favoritesProvider.select(
                                    (state) => state.magazines.any(
                                      (mag) => mag['id'].toString() == id,
                                    ),
                                  ),
                                );
                                // Visual parameters tuned for better contrast
                                final Color cardColor =
                                    isDark
                                        ? scheme.surface.withOpacity(0.14)
                                        : theme.cardColor.withOpacity(0.04);

                                final Color borderColor =
                                    isDark
                                        ? Colors.white.withOpacity(0.35)
                                        : scheme.onSurface.withOpacity(0.35);

                                final BoxShadow subtleHalo =
                                    isDark
                                        ? BoxShadow(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .tertiary
                                              .withOpacity(0.06),
                                          blurRadius: 12,
                                          spreadRadius: 2,
                                          offset: const Offset(0, 6),
                                        )
                                        : const BoxShadow(
                                          color: Colors.transparent,
                                        );

                                final BoxShadow favouriteHalo = BoxShadow(
                                  color: scheme.primary.withOpacity(0.45),
                                  blurRadius: 26,
                                  spreadRadius: 4,
                                  offset: const Offset(0, 8),
                                );

                                return RepaintBoundary(
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                    margin: const EdgeInsets.only(bottom: 14),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(20),
                                      color: cardColor,
                                      border: Border.all(
                                        color: borderColor,
                                        width: 1.5,
                                      ),
                                      boxShadow: <BoxShadow>[
                                        isFav ? favouriteHalo : subtleHalo,
                                      ],
                                    ),
                                    child: MagazineCard(
                                      magazine: m,
                                      isFavorite: isFav,
                                      onFavoriteToggle:
                                          () => ref
                                              .read(favoritesProvider.notifier)
                                              .toggleMagazine(m),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
