// lib/features/home/home_screen.dart

import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import '/features/home/widgets/news_card.dart';
import '/features/home/widgets/shimmer_loading.dart';
import '/features/home/widgets/live_cricket_widget.dart';
import '/data/models/news_article.dart';
import '/data/services/rss_service.dart';
import '/widgets/app_drawer.dart';
import '/localization/l10n/app_localizations.dart';

// Register this in your MaterialApp:
// navigatorObservers: [routeObserver]
final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, RouteAware {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  late List<String> _categoryKeys;
  final Map<String, List<NewsArticle>> _articles = {};
  final Map<String, bool> _loadingStatus = {};
  late Map<String, List<String>> _rssFeeds;
  late Map<String, String> _localizedLabels;
  Locale? _lastLocale;

  String _searchQuery = '';
  int _itemsToDisplay = 20;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      routeObserver.subscribe(this, ModalRoute.of(context)!);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.localeOf(context);
    if (_lastLocale == locale) return;
    _lastLocale = locale;

    final loc = AppLocalizations.of(context)!;
    _rssFeeds = RssService.getSafeFeeds(locale) ?? {};
    _categoryKeys = _rssFeeds.keys.toList();

    _localizedLabels = {
      'latest': loc.latest,
      'national': loc.national,
      'business': loc.business,
      'sports': loc.sports,
      'technology': loc.technology,
      'entertainment': loc.entertainment,
      'lifestyle': loc.lifestyle,
      'blog': loc.blog,
    };

    _tabController = TabController(length: _categoryKeys.length, vsync: this)
      ..addListener(_resetView);

    _articles.clear();
    _loadingStatus.clear();
    _loadAllFeeds();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !_loadingStatus[_currentKey()]! &&
          _currentList().length > _itemsToDisplay) {
        setState(() {
          _itemsToDisplay =
              min(_itemsToDisplay + 10, _currentList().length);
        });
      }
    });
  }

  /// Safely resets the scroll & filters when switching categories or tapping Home.
  void _resetView() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    setState(() {
      _itemsToDisplay = 20;
      _searchQuery = '';
      _searchController.clear();
    });
  }

  /// Called by parent via GlobalKey when Home tab is tapped
  void resetFromNav() {
    _tabController.animateTo(0);
    _resetView();
  }

  @override
  void didPopNext() {
    _tabController.animateTo(0);
    _resetView();
    super.didPopNext();
  }

  String _currentKey() => _categoryKeys[_tabController.index];

  List<NewsArticle> _currentList() {
    final base = _articles[_currentKey()] ?? [];
    if (_searchQuery.isEmpty) return base;
    final q = _searchQuery.toLowerCase();
    return base.where((a) {
      return a.title.toLowerCase().contains(q) ||
          (a.description?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  Future<void> _loadAllFeeds() async {
    for (final category in _categoryKeys) {
      setState(() => _loadingStatus[category] = true);
      try {
        final news = await RssService.fetchRssFeeds(_rssFeeds[category]!);
        setState(() {
          _articles[category] = news;
          _loadingStatus[category] = false;
        });
      } catch (_) {
        setState(() => _loadingStatus[category] = false);
      }
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _tabController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_categoryKeys.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final currentKey = _currentKey();
    final isLoading = _loadingStatus[currentKey] ?? true;
    final displayList = _currentList();
    final itemCount = min(_itemsToDisplay, displayList.length);

    return Scaffold(
      appBar: AppBar(
        title: const Text('BDNewsHub 📰'),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: _categoryKeys.length,
              itemBuilder: (_, i) {
                final key = _categoryKeys[i];
                final label = _localizedLabels[key] ?? key;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: ChoiceChip(
                    label: Text(label,
                        style: const TextStyle(fontSize: 16)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    selected: _tabController.index == i,
                    onSelected: (_) => _tabController.animateTo(i),
                  ),
                );
              },
            ),
          ),
        ),
      ),
      drawer: const AppDrawer(),
      body: isLoading
          ? const ShimmerLoading()
          : RefreshIndicator(
              onRefresh: _loadAllFeeds,
              child: Column(
                children: [
                  // Search bar
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText:
                            AppLocalizations.of(context)!.search,
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(8),
                        ),
                      ),
                      onChanged: (v) => setState(() {
                        _searchQuery = v;
                        _itemsToDisplay = 20;
                      }),
                    ),
                  ),

                  // Article list
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(8),
                      itemCount: itemCount,
                      itemBuilder: (_, idx) =>
                          NewsCard(article: displayList[idx]),
                    ),
                  ),

                  // Full-width Glass/OLED panel with Live Cricket
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: BackdropFilter(
                        filter:
                            ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          height: 200,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                            ),
                          ),
                          child: const LiveCricketWidget(),
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
