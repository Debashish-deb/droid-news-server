import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '/core/theme_provider.dart';
import '/core/theme.dart';
import '/core/services/favorites_providers.dart';
import '../../widgets/app_drawer.dart';
import '../../l10n/app_localizations.dart';
import '../../features/common/app_bar.dart';
import 'widgets/newspaper_card.dart';
import '../../widgets/animated_theme_container.dart';
import '../../presentation/providers/theme_providers.dart';
import '../../presentation/providers/tab_providers.dart';

class NewspaperScreen extends ConsumerStatefulWidget {
  const NewspaperScreen({super.key});

  @override
  ConsumerState<NewspaperScreen> createState() => _NewspaperScreenState();
}

class _NewspaperScreenState extends ConsumerState<NewspaperScreen>
    with SingleTickerProviderStateMixin {
  final List<dynamic> _papers = <dynamic>[];
  bool _isLoading = true;

  TabController? _tabController;
  late final ScrollController _scrollController;
  late final ScrollController _chipsController;
  List<GlobalKey> _chipKeys = <GlobalKey<State<StatefulWidget>>>[];

  String _langFilter = 'All';
  DateTime? _lastBackPressed;
  bool _didInit = false;
  bool _firstBuild = true; // Track first build for scroll reset

  // Removed static _gold

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _chipsController = ScrollController();
    _loadPapers();

    // Listen to tab changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Tab listener managed by Riverpod - removed;
      }
    });
  }

  void _onTabChanged() {
    if (!mounted) return;
    final int currentTab = ref.watch(currentTabIndexProvider);
    // This is tab 1 (Newspaper)
    if (currentTab == 1 && _scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_tabController == null) {
      final List<String> cats = _categories;
      _tabController = TabController(length: cats.length, vsync: this)
        ..addListener(() {
          setState(() => _langFilter = 'All');
          _scrollController.jumpTo(0);
          _centerChip(_tabController!.index);
        });
      _chipKeys = List.generate(cats.length, (_) => GlobalKey());
    }
    if (!_didInit) {
      _didInit = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _centerChip(0);
      });
    }

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

  Future<void> _loadPapers() async {
    setState(() => _isLoading = true);
    try {
      final String raw = await rootBundle.loadString('assets/data.json');
      final Map<String, dynamic> data = jsonDecode(raw) as Map<String, dynamic>;
      setState(() {
        _papers
          ..clear()
          ..addAll(data['newspapers'] as List<dynamic>);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load content: $e')));
    }
  }

  List<String> get _categories {
    // Only access context safely if mounted check not needed for localizations
    // or if we trust build context availability.
    final AppLocalizations loc = AppLocalizations.of(context)!;

    return <String>[
      loc.national,
      loc.international,
      loc.businessFinance,
      loc.digitalTech,
      loc.sportsNews,
      loc.entertainmentArts,
      loc.worldPolitics,
      loc.blog,
    ];
  }

  List<dynamic> _getFilteredPapers() {
    final AppLocalizations loc = AppLocalizations.of(context)!;

    final String selCat = _categories[_tabController!.index];
    final Map<String, String> mapping = <String, String>{
      loc.businessFinance: 'business',
      loc.digitalTech: 'tech',
      loc.sportsNews: 'sports',
      loc.entertainmentArts: 'entertainment',
      loc.worldPolitics: 'defense',
      loc.blog: 'blog',
      loc.national: 'national',
      loc.international: 'international',
    };

    if (selCat == loc.favorites) {
      // Use Riverpod for favorites
      final favoriteNewspapers = ref.read(favoriteNewspapersProvider);
      final Set<String> favIds =
          favoriteNewspapers
              .map((Map<String, dynamic> n) => n['id'].toString())
              .toSet();
      return _papers.where((p) => favIds.contains(p['id'].toString())).toList();
    }

    return _papers.where((p) {
      final String region = (p['region'] ?? '').toString().toLowerCase();
      final String? key = mapping[selCat];
      if (selCat == loc.national || selCat == loc.international) {
        if (region != key) return false;
        if (_langFilter == 'All') return true;
        final String lang = (p['language'] ?? '').toString().toLowerCase();
        return (_langFilter == loc.bangla && lang == 'bn') ||
            (_langFilter == loc.english && lang == 'en');
      }
      return key != null && region == key;
    }).toList();
  }

  Future<bool> _onWillPop() async {
    final DateTime now = DateTime.now();
    if (context.canPop()) {
      context.pop();
      return false;
    }
    if (_lastBackPressed == null ||
        now.difference(_lastBackPressed!) > const Duration(seconds: 2)) {
      _lastBackPressed = now;
      Fluttertoast.showToast(msg: "Press back again to exit");
      return false;
    }
    return true;
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

  Widget _buildLanguageFilter(BuildContext context) {
    final AppLocalizations loc = AppLocalizations.of(context)!;

    final themeMode = ref.watch(currentThemeModeProvider);

    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    final List<String> langs = <String>[loc.bangla, loc.english];

    return Center(
      child: Wrap(
        spacing: 12,
        children:
            langs.map((String lang) {
              final bool selected = _langFilter == lang;
              return ChoiceChip(
                label: Text(lang),
                selected: selected,
                onSelected: (_) => setState(() => _langFilter = lang),
                backgroundColor: ref
                    .watch(glassColorProvider)
                    .withOpacity(0.05),
                selectedColor: scheme.tertiary,
                labelStyle: TextStyle(
                  color:
                      selected
                          ? Colors.black
                          : theme.textTheme.bodyMedium?.color,
                  fontWeight: selected ? FontWeight.bold : FontWeight.w600,
                ),
              );
            }).toList(),
      ),
    );
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
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppThemeMode themeMode = ref.watch(currentThemeModeProvider);
    final AppLocalizations loc = AppLocalizations.of(context)!;

    // Use Riverpod for papers list
    final List<dynamic> filteredPapers = _getFilteredPapers();

    final AppThemeMode mode = themeMode;
    // Use getBackgroundGradient to ensure correct Dark Mode colors (Black, not White)
    final List<Color> colors = AppGradients.getBackgroundGradient(mode);
    final Color start = colors[0], end = colors[1];
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: Colors.transparent,
        drawer: const AppDrawer(),
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // Background gradient
            AnimatedThemeContainer(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[start.withOpacity(0.9), end.withOpacity(0.9)],
                ),
              ),
            ),

            // Main scroll view
            CustomScrollView(
              controller:
                  _scrollController, // Attach controller for manual reset
              key: const PageStorageKey('newspaper_scroll'),
              slivers: <Widget>[
                // AppBar
                SliverAppBar(
                  pinned: true,
                  backgroundColor: theme.appBarTheme.backgroundColor,
                  elevation: theme.appBarTheme.elevation,
                  centerTitle: true,
                  title: AppBarTitle(loc.newspapers),
                  iconTheme: theme.appBarTheme.iconTheme,
                  titleTextStyle: theme.appBarTheme.titleTextStyle,
                ),

                // Category chips
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 48,
                    child: ListView.builder(
                      controller: _chipsController,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: _categories.length,
                      itemBuilder: (BuildContext ctx, int i) {
                        final bool selected = i == _tabController!.index;
                        return Padding(
                          key: _chipKeys[i],
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: ChoiceChip(
                            label: Text(_categories[i]),
                            selected: selected,
                            onSelected: (_) {
                              _tabController!.animateTo(i);
                              _centerChip(i);
                            },
                            backgroundColor: ref
                                .watch(glassColorProvider)
                                .withOpacity(0.05),
                            selectedColor: scheme.tertiary,
                            labelStyle: TextStyle(
                              color:
                                  selected
                                      ? scheme.onPrimary
                                      : scheme.onSurface,
                              fontWeight:
                                  selected ? FontWeight.bold : FontWeight.w600,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // Language filter for national/international
                if (_categories[_tabController!.index] == loc.national ||
                    _categories[_tabController!.index] == loc.international)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Center(child: _buildLanguageFilter(context)),
                    ),
                  ),

                // Article list
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
                          : filteredPapers.isEmpty
                          ? Center(
                            child: Text(
                              loc.noPapersFound,
                              style: theme.textTheme.bodyLarge,
                            ),
                          )
                          : RefreshIndicator(
                            color: scheme.primary,
                            onRefresh: _loadPapers,
                            child: GridView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.only(
                                left: 12,
                                right: 12,
                                top: 12,
                                bottom: 80,
                              ), // Bottom padding for nav bar
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 1, // Single card per row
                                    childAspectRatio:
                                        3.0, // Wide banner style (Magazine-like)
                                    crossAxisSpacing: 4,
                                    mainAxisSpacing: 4,
                                  ),
                              itemCount: filteredPapers.length,
                              itemBuilder: (_, int idx) {
                                final paper = filteredPapers[idx];
                                final String id = paper['id'].toString();
                                // Use Riverpod for favorites state
                                final bool isFav = ref.watch(
                                  favoritesProvider.select(
                                    (state) => state.newspapers.any(
                                      (n) => n['id'].toString() == id,
                                    ),
                                  ),
                                );

                                return RepaintBoundary(
                                  child: NewspaperCard(
                                    news: paper,
                                    isFavorite: isFav,
                                    onFavoriteToggle: () {
                                      ref
                                          .read(favoritesProvider.notifier)
                                          .toggleNewspaper(paper);
                                    },
                                    searchQuery: '',
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
