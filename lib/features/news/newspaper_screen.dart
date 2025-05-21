// lib/features/news/newspaper_screen.dart

// ✅ UPDATE: Enhance NewsCard styling, bring cards closer together
// NO other logic changes, only UI polish

// CHANGES IN LISTVIEW BUILDER:
// - Reduce spacing between cards (margin.bottom)
// - Apply tighter padding around list
// - Enhance card elevation and modern rounded style
// - Slight color overlay for glass look

import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '/core/theme_provider.dart';
import '/core/theme.dart';
import '/core/utils/favorites_manager.dart';
import '/l10n/app_localizations.dart';
import '/widgets/app_drawer.dart';
import '/features/common/appBar.dart';
import 'widgets/news_card.dart';

class NewspaperScreen extends StatefulWidget {
  const NewspaperScreen({Key? key}) : super(key: key);

  @override
  State<NewspaperScreen> createState() => _NewspaperScreenState();
}

class _NewspaperScreenState extends State<NewspaperScreen>
    with SingleTickerProviderStateMixin {
  final List<dynamic> _papers = [];
  bool _isLoading = true;

  TabController? _tabController;
  late final ScrollController _scrollController;
  late final ScrollController _chipsController;
  List<GlobalKey> _chipKeys = [];

  String _langFilter = 'All';
  final FavoritesManager _favorites = FavoritesManager.instance;
  DateTime? _lastBackPressed;
  bool _didInit = false;

  static const Color _gold = Color(0xFFFFD700);

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _chipsController = ScrollController();
    _favorites.loadFavorites();
    _loadPapers();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_tabController == null) {
      final cats = _categories;
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
  }

  Future<void> _loadPapers() async {
    setState(() => _isLoading = true);
    try {
      final raw = await rootBundle.loadString('assets/data.json');
      final data = jsonDecode(raw) as Map<String, dynamic>;
      setState(() {
        _papers
          ..clear()
          ..addAll(data['newspapers'] as List<dynamic>);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      final loc = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.loadError.replaceFirst('{message}', '$e'))),
      );
    }
  }

  List<String> get _categories {
    final loc = AppLocalizations.of(context)!;
    return [
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

  List<dynamic> get _filteredPapers {
    final loc = AppLocalizations.of(context)!;
    final selCat = _categories[_tabController!.index];
    final mapping = {
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
      final favIds = _favorites.favoriteNewspapers
          .map((n) => n['id'].toString())
          .toSet();
      return _papers.where((p) => favIds.contains(p['id'].toString())).toList();
    }

    return _papers.where((p) {
      final region = (p['region'] ?? '').toString().toLowerCase();
      final key = mapping[selCat];
      if (selCat == loc.national || selCat == loc.international) {
        if (region != key) return false;
        if (_langFilter == 'All') return true;
        final lang = (p['language'] ?? '').toString().toLowerCase();
        return (_langFilter == loc.bangla && lang == 'bn') ||
               (_langFilter == loc.english && lang == 'en');
      }
      return key != null && region == key;
    }).toList();
  }

  Future<bool> _onWillPop() async {
    final now = DateTime.now();
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
    final key = _chipKeys[index];
    if (key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 200),
        alignment: 0.5,
      );
    }
  }

  Widget _buildLanguageFilter(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final prov = context.watch<ThemeProvider>();
    final theme = Theme.of(context);
    final baseColor = prov.glassColor;
    final borderColor = prov.borderColor.withOpacity(0.3);

    Widget buildChip(String label) {
      final selected = _langFilter == label;
      return InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: () => setState(() => _langFilter = label),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? _gold.withOpacity(0.2) : baseColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: selected ? _gold : borderColor,
              width: 1.2,
            ),
          ),
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: selected
                  ? _gold
                  : theme.textTheme.bodyMedium?.color?.withOpacity(0.85),
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        buildChip(loc.bangla),
        const SizedBox(width: 12),
        buildChip(loc.english),
      ],
    );
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _scrollController.dispose();
    _chipsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final prov = context.watch<ThemeProvider>();
    final mode = prov.appThemeMode;
    final colors = AppGradients.getGradientColors(mode);
    final start = colors[0], end = colors[1];
    final theme = Theme.of(context);

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: Colors.transparent,
        drawer: const AppDrawer(),
        body: Stack(
          fit: StackFit.expand,
          children: [
            Container(
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
            ),
            CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  centerTitle: true,
                  title: AppBarTitle(loc.newspapers),
                  flexibleSpace: ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              start.withOpacity(0.8),
                              end.withOpacity(0.85),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 48,
                    child: ListView.builder(
                      controller: _chipsController,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: _categories.length,
                      itemBuilder: (ctx, i) {
                        final selected = i == _tabController!.index;
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
                            backgroundColor: prov.glassColor.withOpacity(0.05),
                            selectedColor: _gold,
                            labelStyle: TextStyle(
                              color: selected
                                  ? Colors.black
                                  : theme.textTheme.bodyMedium?.color,
                              fontWeight: selected ? FontWeight.bold : FontWeight.w600,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                if (_categories[_tabController!.index] == loc.national ||
                    _categories[_tabController!.index] == loc.international)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Center(child: _buildLanguageFilter(context)),
                    ),
                  ),
                SliverFillRemaining(
                  child: _isLoading
                      ? Center(
                          child: CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation(theme.colorScheme.primary),
                          ),
                        )
                      : _filteredPapers.isEmpty
                          ? Center(
                              child: Text(
                                loc.noPapersFound,
                                style: theme.textTheme.bodyLarge,
                              ),
                            )
                          : RefreshIndicator(
                              color: theme.colorScheme.primary,
                              onRefresh: _loadPapers,
                              child: ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                itemCount: _filteredPapers.length,
                                itemBuilder: (_, idx) {
                                  final paper = _filteredPapers[idx];
                                  final id = paper['id'].toString();
                                  final isFav = _favorites.isFavoriteNewspaper(id);

                                  return AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                    margin: const EdgeInsets.only(bottom: 8),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      color: theme.cardColor.withOpacity(0.08),
                                      border: Border.all(
                                        color: theme.colorScheme.onSurface.withOpacity(0.35),
                                        width: 1.4,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: theme.shadowColor.withOpacity(0.05),
                                          blurRadius: 12,
                                          offset: const Offset(0, 5),
                                        ),
                                      ],
                                    ),
                                    child: NewsCard(
                                      news: paper,
                                      isFavorite: isFav,
                                      onFavoriteToggle: () {
                                        _favorites.toggleNewspaper(paper);
                                        setState(() {});
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
