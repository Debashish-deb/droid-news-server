// lib/features/search/search_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:string_similarity/string_similarity.dart';

import '../../core/navigation_helper.dart';
import '/l10n/app_localizations.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final List<String> _dataSet = ['Prothom Alo', 'Daily Star', 'Jugantor', 'Kaler Kantho', 'BBC Bangla', 'Anandabazar', 'Dhaka Tribune', 'News24', 'Rtv', 'Bangladesh Pratidin', 'Desh TV', 'Time Magazine', 'The Economist', 'Forbes', 'Nat Geo', 'Science Today'];
  List<String> _suggestions = [];
  List<String> _recentSearches = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
    _searchController.addListener(_updateSuggestions);
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _recentSearches = prefs.getStringList('recent_searches') ?? []);
  }

  Future<void> _saveSearchQuery(String query) async {
    final prefs = await SharedPreferences.getInstance();
    final updated = [query, ..._recentSearches.where((q) => q != query)];
    await prefs.setStringList('recent_searches', updated.take(10).toList());
    setState(() => _recentSearches = updated.take(10).toList());
  }

  void _updateSuggestions() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() => _suggestions = []);
    } else {
      final matches = _dataSet
          .where((entry) => entry.toLowerCase().contains(query))
          .toList();

      matches.sort((a, b) => b.similarityTo(query).compareTo(a.similarityTo(query)));

      setState(() => _suggestions = matches.take(5).toList());
    }
  }

  void _onSelect(String query) async {
    _searchController.text = query;
    await _saveSearchQuery(query);

    if (query.toLowerCase().contains('magazine')) {
      NavigationHelper.goMagazines(context);
    } else if (query.toLowerCase().contains('newspaper') ||
        _dataSet.any((d) => d.toLowerCase() == query.toLowerCase())) {
      NavigationHelper.goNewspaper(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No match found for "$query"')),
      );
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
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

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
        child: Column(children: [
          TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onSubmitted: _onSelect,
            decoration: InputDecoration(
              hintText: loc.searchHint,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: _clearQuery,
                    )
                  : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          if (_suggestions.isNotEmpty)
            Expanded(
              child: ListView(
                children: _suggestions.map((s) => ListTile(
                  title: Text(s),
                  onTap: () => _onSelect(s),
                )).toList(),
              ),
            )
          else
            Expanded(
              child: ListView(
                children: [
                  if (_recentSearches.isNotEmpty)
                    Text('Recent Searches', style: theme.textTheme.titleMedium),
                  ..._recentSearches.map((q) => ListTile(
                        leading: const Icon(Icons.history),
                        title: Text(q),
                        onTap: () => _onSelect(q),
                      )),
                ],
              ),
            )
        ]),
      ),
    );
  }
}
