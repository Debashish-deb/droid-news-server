// path: features/magazine/magazine_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../localization/l10n/app_localizations.dart';
import '../../widgets/app_drawer.dart';
import '../../core/utils/favorites_manager.dart';
import 'widgets/animated_background.dart';
import 'widgets/magazine_card.dart';

class MagazineScreen extends StatefulWidget {
  const MagazineScreen({super.key});

  @override
  State<MagazineScreen> createState() => _MagazineScreenState();
}

class _MagazineScreenState extends State<MagazineScreen> with SingleTickerProviderStateMixin {
  final List<dynamic> magazines = [];
  bool _isLoading = true;
  final ScrollController _scrollController = ScrollController();
  final ScrollController _listController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 9, vsync: this)
      ..addListener(() {
        setState(() {});
        _listController.jumpTo(0);
      });
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Load failed: $e')),
      );
    }
  }

  Future<void> _toggleFavorite(dynamic m) async {
    await FavoritesManager.instance.toggleMagazine(m);
    setState(() {});
  }

  List<dynamic> get _filteredMagazines {
    final loc = AppLocalizations.of(context)!;
    final categories = [
      loc.favorites,
      loc.catFashion,
      loc.catScience,
      loc.catFinance,
      loc.catAffairs,
      loc.catTech,
      loc.catArts,
      loc.catLifestyle,
      loc.catSports,
    ];

    final categoryKeywords = {
      loc.catFashion: ['fashion', 'style', 'aesthetics'],
      loc.catScience: ['science', 'discovery', 'research'],
      loc.catFinance: ['finance', 'economics', 'business'],
      loc.catAffairs: ['global', 'politics', 'world', 'international', 'defense'],
      loc.catTech: ['technology', 'innovation', 'tech'],
      loc.catArts: ['arts', 'culture', 'humanities', 'literature'],
      loc.catLifestyle: ['lifestyle', 'luxury', 'travel'],
      loc.catSports: ['sports', 'athletics', 'performance'],
    };

    final selCategory = categories[_tabController.index];
    List<dynamic> filtered;

    if (selCategory == loc.favorites) {
      final favIds = FavoritesManager.instance.favoriteMagazines.map((m) => m['id'].toString()).toSet();
      filtered = magazines.where((m) => favIds.contains(m['id'].toString())).toList();
    } else {
      final keys = categoryKeywords[selCategory] ?? [];
      filtered = magazines.where((m) {
        final tags = List<String>.from(m['tags'] ?? []);
        return tags.any((t) => keys.any((kw) => t.toLowerCase().contains(kw)));
      }).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((m) {
        final name = (m['name'] ?? '').toString().toLowerCase();
        final desc = (m['description'] ?? '').toString().toLowerCase();
        return name.contains(query) || desc.contains(query);
      }).toList();
    }

    return filtered;
  }

  Future<bool> _onWillPop() async {
    context.go('/home');
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final categories = [
      loc.favorites,
      loc.catFashion,
      loc.catScience,
      loc.catFinance,
      loc.catAffairs,
      loc.catTech,
      loc.catArts,
      loc.catLifestyle,
      loc.catSports,
    ];

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        drawer: const AppDrawer(),
        appBar: AppBar(
          centerTitle: true, // ✅ Center title
          title: Text(
            loc.magazines,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          automaticallyImplyLeading: false,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v),
                style: Theme.of(context).textTheme.bodyMedium,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: loc.searchHint,
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                ),
              ),
            ),
          ),
        ),
        body: Column(
          children: [
            SizedBox(
              height: 48,
              child: ListView.builder(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                itemBuilder: (context, i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(categories[i]),
                    selected: _tabController.index == i,
                    onSelected: (_) => _tabController.animateTo(i),
                  ),
                ),
              ),
            ),
            Expanded(
              child: AnimatedBackground(
                duration: const Duration(seconds: 30),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredMagazines.isEmpty
                        ? Center(child: Text(loc.noMagazines))
                        : RefreshIndicator(
                            onRefresh: _loadMagazines,
                            child: ListView.builder(
                              controller: _listController,
                              padding: const EdgeInsets.all(16),
                              itemCount: _filteredMagazines.length,
                              itemBuilder: (context, idx) {
                                final magazine = _filteredMagazines[idx];
                                final id = magazine['id'].toString();
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: MagazineCard(
                                    magazine: magazine,
                                    isFavorite: FavoritesManager.instance.isFavoriteMagazine(id),
                                    onFavoriteToggle: () => _toggleFavorite(magazine),
                                  ),
                                );
                              },
                            ),
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
