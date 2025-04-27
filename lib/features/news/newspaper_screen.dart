// path: features/news/newspaper_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/favorites_manager.dart';
import '../../widgets/app_drawer.dart';
import '../../localization/l10n/app_localizations.dart';
import 'widgets/animated_background.dart';
import 'widgets/news_card.dart';

class NewspaperScreen extends StatefulWidget {
  const NewspaperScreen({super.key});

  @override
  State<NewspaperScreen> createState() => _NewspaperScreenState();
}

class _NewspaperScreenState extends State<NewspaperScreen> with SingleTickerProviderStateMixin {
  final List<dynamic> _papers = [];
  bool _isLoading = true;
  final ScrollController _listController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _langFilter = 'All';
  late TabController _tabController;

  FavoritesManager favoritesManager = FavoritesManager.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 9, vsync: this)
      ..addListener(() {
        setState(() {
          _langFilter = 'All';
        });
        _listController.jumpTo(0);
      });
    favoritesManager.loadFavorites();
    _loadPapers();
  }

  Future<void> _loadPapers() async {
    setState(() => _isLoading = true);
    try {
      final raw = await rootBundle.loadString('assets/data.json');
      final jsonData = jsonDecode(raw) as Map<String, dynamic>;
      setState(() {
        _papers
          ..clear()
          ..addAll(jsonData['newspapers'] as List<dynamic>);
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
      loc.favorites,
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
    final selCategory = _categories[_tabController.index];

    final map = {
      loc.businessFinance: 'business',
      loc.digitalTech: 'tech',
      loc.sportsNews: 'sports',
      loc.entertainmentArts: 'entertainment',
      loc.worldPolitics: 'defense',
      loc.blog: 'blog',
      loc.national: 'national',
      loc.international: 'international',
    };

    var filtered = <dynamic>[];

    if (selCategory == loc.favorites) {
      final favIds = favoritesManager.favoriteNewspapers.map((n) => n['id'].toString()).toSet();
      filtered = _papers.where((p) => favIds.contains(p['id'].toString())).toList();
    } else {
      filtered = _papers.where((p) {
        final region = (p['region'] ?? '').toString().toLowerCase();
        final key = map[selCategory];
        if (selCategory == loc.national || selCategory == loc.international) {
          if (region != key) return false;
          if (_langFilter == 'All') return true;
          final lang = (p['language'] ?? '').toString().toLowerCase();
          return (_langFilter == loc.bangla && lang == 'bn') ||
                 (_langFilter == loc.english && lang == 'en');
        }
        return key != null && region == key;
      }).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((p) {
        final name = (p['name'] ?? '').toString().toLowerCase();
        final desc = (p['description'] ?? '').toString().toLowerCase();
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

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        drawer: const AppDrawer(),
        appBar: AppBar(
          centerTitle: true, // ✅ CENTER the title as you asked
          title: Text(
            loc.newspapers,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          automaticallyImplyLeading: false,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                style: Theme.of(context).textTheme.bodyMedium,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: loc.searchPapers,
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
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                itemBuilder: (context, i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(_categories[i]),
                    selected: _tabController.index == i,
                    onSelected: (_) => _tabController.animateTo(i),
                  ),
                ),
              ),
            ),
            if ([_categories[1], _categories[2]].contains(_categories[_tabController.index]))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [loc.allLanguages, loc.bangla, loc.english].map((lang) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: ChoiceChip(
                        label: Text(lang),
                        selected: _langFilter == lang,
                        onSelected: (_) => setState(() => _langFilter = lang),
                      ),
                    );
                  }).toList(),
                ),
              ),
            Expanded(
              child: AnimatedBackground(
                duration: const Duration(seconds: 30),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredPapers.isEmpty
                        ? Center(child: Text(loc.noPapersFound))
                        : RefreshIndicator(
                            onRefresh: _loadPapers,
                            child: ListView.builder(
                              controller: _listController,
                              padding: const EdgeInsets.all(16),
                              itemCount: _filteredPapers.length,
                              itemBuilder: (context, idx) {
                                final paper = _filteredPapers[idx];
                                final id = paper['id'].toString();
                                return NewsCard(
                                  news: paper,
                                  searchQuery: _searchQuery,
                                  isFavorite: favoritesManager.isFavoriteNewspaper(id),
                                  onFavoriteToggle: () => setState(() {
                                    favoritesManager.toggleNewspaper(paper);
                                  }),
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
