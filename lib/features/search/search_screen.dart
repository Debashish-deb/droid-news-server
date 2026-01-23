// lib/features/search/search_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:string_similarity/string_similarity.dart';

import '../../core/navigation_helper.dart';
import '../../core/utils/analytics_service.dart';
import '../../l10n/app_localizations.dart';

import 'package:go_router/go_router.dart';
import '../../data/services/hive_service.dart';
import '../../data/models/news_article.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../presentation/providers/app_settings_providers.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final List<String> _dataSet = <String>[
    'Prothom Alo',
    'Daily Star',
    'Jugantor',
    'Kaler Kantho',
    'BBC Bangla',
    'Anandabazar',
    'Dhaka Tribune',
    'News24',
    'Rtv',
    'Bangladesh Pratidin',
    'Desh TV',
    'Time Magazine',
    'The Economist',
    'Forbes',
    'Nat Geo',
    'Science Today',
  ];
  List<String> _suggestions = <String>[];
  List<String> _recentSearches = <String>[];
  List<NewsArticle> _cachedArticles = <NewsArticle>[];

  // New filters
  String _selectedSource = 'All';
  String _selectedDateRange = 'All Time';

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
    _loadCachedArticles();
    _searchController.addListener(_updateSuggestions);
  }

  Future<void> _loadRecentSearches() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(
      () =>
          _recentSearches =
              prefs.getStringList('recent_searches') ?? <String>[],
    );
  }

  Future<void> _loadCachedArticles() async {
    // Ensure Hive is ready, though HomeScreen likely did it.
    if (HiveService.hasArticles('latest')) {
      setState(() {
        _cachedArticles = HiveService.getArticles('latest');
      });
    }
  }

  Future<void> _saveSearchQuery(String query) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> updated = <String>[
      query,
      ..._recentSearches.where((String q) => q != query),
    ];
    await prefs.setStringList('recent_searches', updated.take(10).toList());
    setState(() => _recentSearches = updated.take(10).toList());
  }

  void _updateSuggestions() {
    final String query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() => _suggestions = <String>[]);
    } else {
      // 1. Matches from static dataset
      final List<String> staticMatches =
          _dataSet
              .where((String entry) => entry.toLowerCase().contains(query))
              .toList();

      // 2. Matches from cached news with filters
      final filteredArticles = _cachedArticles.where((NewsArticle a) {
        final textMatch =
            a.title.toLowerCase().contains(query) ||
            a.description.toLowerCase().contains(query);

        // Source filter
        final sourceMatch =
            _selectedSource == 'All' ||
            a.source.toLowerCase().contains(_selectedSource.toLowerCase());

        // Date filter
        bool dateMatch = true;
        if (_selectedDateRange != 'All Time') {
          final now = DateTime.now();
          final articleDate = a.publishedAt;
          if (_selectedDateRange == 'Today') {
            dateMatch = articleDate.isAfter(
              now.subtract(const Duration(days: 1)),
            );
          } else if (_selectedDateRange == 'This Week') {
            dateMatch = articleDate.isAfter(
              now.subtract(const Duration(days: 7)),
            );
          } else if (_selectedDateRange == 'This Month') {
            dateMatch = articleDate.isAfter(
              now.subtract(const Duration(days: 30)),
            );
          }
        }

        return textMatch && sourceMatch && dateMatch;
      });

      final List<String> newsMatches =
          filteredArticles.map((NewsArticle a) => a.title).take(10).toList();

      // Combine and Dedup
      final Set<String> unique = <String>{...staticMatches, ...newsMatches};
      final List<String> matches = unique.toList();

      matches.sort(
        (String a, String b) =>
            b.similarityTo(query).compareTo(a.similarityTo(query)),
      );

      setState(() => _suggestions = matches.take(10).toList());
    }
  }

  void _onSelect(String query) async {
    _searchController.text = query;
    await _saveSearchQuery(query);

    // Track search analytics
    await AnalyticsService.logSearch(query);

    // 1. Check if it matches a News Article exactly
    final NewsArticle matchedArticle = _cachedArticles.firstWhere(
      (NewsArticle a) => a.title == query,
      orElse:
          () => NewsArticle(
            title: '',
            url: '',
            source: '',
            publishedAt: DateTime.now(),
          ), // Dummy
    );

    if (matchedArticle.url.isNotEmpty) {
      if (!mounted) return;
      // Navigate to WebView
      GoRouter.of(context).push(
        '/webview',
        extra: <String, dynamic>{
          'url': matchedArticle.url,
          'title': matchedArticle.title,
          'description': matchedArticle.description,
          'imageUrl': matchedArticle.imageUrl,
          'source': matchedArticle.source,
          'publishedAt': matchedArticle.publishedAt.toIso8601String(),
          'dataSaver': ref.read(dataSaverProvider),
        },
      );
      return;
    }

    // 2. Existing logic
    if (query.toLowerCase().contains('magazine')) {
      if (!mounted) return;
      NavigationHelper.goMagazines(context);
    } else if (query.toLowerCase().contains('newspaper') ||
        _dataSet.any((String d) => d.toLowerCase() == query.toLowerCase())) {
      if (!mounted) return;
      NavigationHelper.goNewspaper(context);
    } else {
      if (!mounted) return;
      final AppLocalizations loc = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(loc.noMatchFound(query))));
    }
  }

  void _clearQuery() {
    _searchController.clear();
    setState(() => _suggestions.clear());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations loc = AppLocalizations.of(context)!;

    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.searchHint),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => NavigationHelper.goHome(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: _onSelect,
              decoration: InputDecoration(
                hintText: loc.searchHint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon:
                    _searchController.text.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: _clearQuery,
                        )
                        : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Advanced Filters
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedSource,
                    decoration: InputDecoration(
                      labelText: loc.sourceLabel,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'All',
                        child: Text(loc.allSources),
                      ),
                      const DropdownMenuItem(
                        value: 'Prothom Alo',
                        child: Text('Prothom Alo'),
                      ),
                      const DropdownMenuItem(
                        value: 'Daily Star',
                        child: Text('Daily Star'),
                      ),
                      const DropdownMenuItem(value: 'BBC', child: Text('BBC')),
                      const DropdownMenuItem(
                        value: 'JagoNews24',
                        child: Text('JagoNews24'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedSource = value ?? 'All');
                      if (_searchController.text.isNotEmpty) {
                        _updateSuggestions();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedDateRange,
                    decoration: InputDecoration(
                      labelText: loc.dateLabel,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'All Time',
                        child: Text(loc.allTime),
                      ),
                      DropdownMenuItem(value: 'Today', child: Text(loc.today)),
                      DropdownMenuItem(
                        value: 'This Week',
                        child: Text(loc.thisWeek),
                      ),
                      DropdownMenuItem(
                        value: 'This Month',
                        child: Text(loc.thisMonth),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedDateRange = value ?? 'All Time');
                      if (_searchController.text.isNotEmpty) {
                        _updateSuggestions();
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_suggestions.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  itemCount: _suggestions.length,
                  itemBuilder: (context, index) {
                    final suggestion = _suggestions[index];
                    return ListTile(
                      title: Text(suggestion),
                      onTap: () => _onSelect(suggestion),
                    );
                  },
                ),
              )
            else
              Expanded(
                child: _recentSearches.isEmpty
                    ? const SizedBox.shrink()
                    : ListView.builder(
                        itemCount: _recentSearches.length + 1, // +1 for header
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return Text(
                              loc.recentSearches,
                              style: theme.textTheme.titleMedium,
                            );
                          }
                          final query = _recentSearches[index - 1];
                          return ListTile(
                            leading: const Icon(Icons.history),
                            title: Text(query),
                            onTap: () => _onSelect(query),
                          );
                        },
                      ),
              ),
          ],
        ),
      ),
    );
  }
}
