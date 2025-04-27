// Updated lib/features/search/search_screen.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/navigation_helper.dart';
import '../../localization/l10n/app_localizations.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();

  List<String> _searchResults = [];
  List<String> _recentSearches = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList('recent_searches') ?? [];
    setState(() => _recentSearches = history);
  }

  Future<void> _saveSearchQuery(String query) async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList('recent_searches') ?? [];
    if (history.contains(query)) history.remove(query);
    history.insert(0, query);
    if (history.length > 10) history.removeLast();
    await prefs.setStringList('recent_searches', history);
  }

  void _onSearch(String query) async {
    if (query.trim().isEmpty) return;

    setState(() => _isSearching = true);
    await Future.delayed(const Duration(milliseconds: 600));

    setState(() {
      _searchResults.clear();
      _isSearching = false;
    });

    final newResults = List.generate(
      5,
      (index) => 'Result for "$query" - Article ${index + 1}',
    );

    for (var result in newResults) {
      _searchResults.add(result);
      _listKey.currentState?.insertItem(_searchResults.length - 1, duration: const Duration(milliseconds: 400));
    }

    await _saveSearchQuery(query);
    await _loadRecentSearches();
  }

  void _clearSearch() {
    for (var i = _searchResults.length - 1; i >= 0; i--) {
      _listKey.currentState?.removeItem(
        i,
        (context, animation) => _buildAnimatedItem(_searchResults[i], animation),
        duration: const Duration(milliseconds: 400),
      );
    }
    _searchResults.clear();
    _searchController.clear();
  }

  Widget _buildAnimatedItem(String item, Animation<double> animation) {
    return SizeTransition(
      sizeFactor: animation,
      child: ListTile(
        leading: const Icon(Icons.article_outlined),
        title: Text(item),
        onTap: () {
          // TODO: Navigate to article detail
        },
      ),
    );
  }

  Widget _buildRecentTile(String query) {
    return ListTile(
      leading: const Icon(Icons.history),
      title: Text(query),
      onTap: () {
        _searchController.text = query;
        _onSearch(query);
      },
    );
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
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: _onSearch,
              decoration: InputDecoration(
                hintText: loc.searchHint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: _clearSearch,
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _isSearching
                  ? const Center(child: CircularProgressIndicator())
                  : _searchResults.isNotEmpty
                      ? AnimatedList(
                          key: _listKey,
                          initialItemCount: _searchResults.length,
                          itemBuilder: (context, index, animation) {
                            final item = _searchResults[index];
                            return _buildAnimatedItem(item, animation);
                          },
                        )
                      : ListView(
                          children: [
                            Text(
                              'Recent Searches',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            ..._recentSearches.map(_buildRecentTile),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
