// lib/features/magazine/magazine_screen.dart

// 🛠 Reverted to 1-column list style with stylish container decoration

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '/core/theme_provider.dart';
import '/core/theme.dart';
import '/core/utils/favorites_manager.dart';
import '/l10n/app_localizations.dart';
import '../../widgets/app_drawer.dart';
import '../../features/common/appBar.dart';
import 'widgets/magazine_card.dart';

class MagazineScreen extends StatefulWidget {
  const MagazineScreen({Key? key}) : super(key: key);

  @override
  State<MagazineScreen> createState() => _MagazineScreenState();
}

class _MagazineScreenState extends State<MagazineScreen>
    with SingleTickerProviderStateMixin {
  final List<dynamic> magazines = [];
  bool _isLoading = true;

  late final TabController _tabController;
  late final ScrollController _scrollController;
  late final ScrollController _chipsController;
  late final List<GlobalKey> _chipKeys;

  DateTime? _lastBackPressed;

  static const int _categoriesCount = 8;
  static const Color _gold = Color(0xFFFFD700);

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _chipsController = ScrollController();
    _tabController = TabController(length: _categoriesCount, vsync: this)
      ..addListener(() {
        _centerChip(_tabController.index);
        setState(() {});
      });
    _chipKeys = List.generate(_categoriesCount, (_) => GlobalKey());
    _loadMagazines();
  }

  Future<void> _loadMagazines() async {
    setState(() => _isLoading = true);
    try {
      final raw = await rootBundle.loadString('assets/data.json');
      final data = json.decode(raw);
      setState(() {
        magazines
          ..clear()
          ..addAll(data['magazines'] ?? []);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Load failed: $e')));
    }
  }

  Future<bool> _onWillPop() async {
    final now = DateTime.now();
    if (_lastBackPressed == null ||
        now.difference(_lastBackPressed!) > const Duration(seconds: 2)) {
      _lastBackPressed = now;
      Fluttertoast.showToast(msg: "Press back again to exit");
      return false;
    }
    return true;
  }

  List<String> _categories(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return [
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
    final cats = _categories(context);
    final keys = {
      cats[0]: ['fashion', 'style', 'aesthetics'],
      cats[1]: ['science', 'discovery', 'research'],
      cats[2]: ['finance', 'economics', 'business'],
      cats[3]: ['global', 'politics', 'world'],
      cats[4]: ['technology', 'tech'],
      cats[5]: ['arts', 'culture'],
      cats[6]: ['lifestyle', 'luxury', 'travel'],
      cats[7]: ['sports', 'performance'],
    };
    final sel = cats[_tabController.index];
    final kws = keys[sel] ?? [];
    return magazines.where((m) {
      final tags = List<String>.from(m['tags'] ?? []);
      return tags.any((t) => kws.any((kw) => t.toLowerCase().contains(kw)));
    }).toList();
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

  void _toggleFavorite(dynamic m) async {
    await FavoritesManager.instance.toggleMagazine(m);
    setState(() {});
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _chipsController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final mode = context.watch<ThemeProvider>().appThemeMode;
    final gradientColors = AppGradients.getGradientColors(mode);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final categories = _categories(context);

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: scheme.background,
        drawer: const AppDrawer(),
        body: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    gradientColors[0].withOpacity(0.85),
                    gradientColors[1].withOpacity(0.85),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  backgroundColor: theme.appBarTheme.backgroundColor,
                  elevation: theme.appBarTheme.elevation,
                  centerTitle: true,
                  titleTextStyle: theme.appBarTheme.titleTextStyle,
                  title: AppBarTitle(loc.magazines),
                  iconTheme: theme.appBarTheme.iconTheme,
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 48,
                    child: ListView.builder(
                      controller: _chipsController,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: categories.length,
                      itemBuilder: (ctx, i) {
                        final sel = i == _tabController.index;
                        return Padding(
                          key: _chipKeys[i],
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: ChoiceChip(
                            label: Text(categories[i]),
                            selected: sel,
                            onSelected: (_) {
                              _tabController.animateTo(i);
                              _centerChip(i);
                            },
                            backgroundColor: scheme.surface.withOpacity(0.5),
                            selectedColor: _gold,
                            labelStyle: TextStyle(
                              color: sel ? Colors.black : scheme.onSurface,
                              fontWeight: sel ? FontWeight.bold : FontWeight.w600,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                SliverFillRemaining(
                  child: _isLoading
                      ? Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation(scheme.primary),
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
                                padding: const EdgeInsets.all(16),
                                itemCount: _filteredMagazines.length,
                                itemBuilder: (_, idx) {
                                  final m = _filteredMagazines[idx];
                                  final id = m['id'].toString();
                                  final isFav = FavoritesManager.instance.isFavoriteMagazine(id);

                                  return AnimatedContainer(
                                    duration: const Duration(milliseconds: 400),
                                    curve: Curves.easeInOut,
                                    margin: const EdgeInsets.only(bottom: 12),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(20),
                                      color: theme.cardColor.withOpacity(0.03),
                                      border: Border.all(
                                        color: theme.colorScheme.onSurface.withOpacity(0.35),
                                        width: 1.4,
                                      ),
                                      boxShadow: isFav
                                          ? [
                                              BoxShadow(
                                                color: theme.colorScheme.primary.withOpacity(0.25),
                                                blurRadius: 14,
                                                spreadRadius: 1,
                                                offset: const Offset(0, 6),
                                              ),
                                            ]
                                          : [],
                                    ),
                                    child: MagazineCard(
                                      magazine: m,
                                      isFavorite: isFav,
                                      onFavoriteToggle: () => _toggleFavorite(m),
                                      highlight: true,
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
