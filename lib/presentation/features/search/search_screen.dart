// lib/features/search/search_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/di/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../domain/entities/news_article.dart';
import 'providers/search_provider.dart';
import 'providers/search_intelligence_provider.dart';
import '../home/widgets/news_card.dart';
import '../../widgets/category_chips_bar.dart';

import '../../../core/utils/source_logos.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/enums/theme_mode.dart';
import '../../providers/theme_providers.dart';
import '../../widgets/app_drawer.dart';
import 'dart:ui';
import '../../widgets/glass_pill_button.dart';
import '../../widgets/glass_icon_button.dart';
import '../../widgets/animated_theme_container.dart';
import '../../../core/theme/theme.dart';
import '../common/app_bar.dart';
import '../../../core/navigation/app_paths.dart';

import '../../widgets/unlock_article_dialog.dart';
import 'package:go_router/go_router.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  AppLocalizations get loc => AppLocalizations.of(context);
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleArticleTap(NewsArticle article) async {
    final bool isPremiumContent = article.tags?.contains('premium') == true;

    if (isPremiumContent) {
      final bool unlocked = await showUnlockDialog(
        context,
        article.url,
        article.title,
      );
      if (!unlocked) return;
    }

    ref.read(interstitialAdServiceProvider).onArticleViewed();

    if (!mounted) return;
    context.push(AppPaths.newsDetail, extra: article);
  }

  // Enhanced Search Implementation
  List<MapEntry<String, String>> _publisherSuggestions = [];

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    // 1. Filter Local Publishers immediately
    if (query.isNotEmpty) {
      final normalizedQuery = query.toLowerCase();
      setState(() {
        _publisherSuggestions = SourceLogos.logos.entries
            .where((e) => e.key.toLowerCase().contains(normalizedQuery))
            .take(6)
            .toList();
      });
    } else {
      setState(() {
        _publisherSuggestions = [];
      });
      // Clear topic search state when query is emptied
      ref.read(searchProvider.notifier).clearTopicSearch();
    }

    // 2. Debounce API Search
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.isNotEmpty) {
        ref.read(searchProvider.notifier).search(query);
      }
    });
  }

  void _onSearchSubmitted(String query) {
    if (query.isNotEmpty) {
      if (_debounce?.isActive ?? false) _debounce!.cancel();
      ref.read(searchProvider.notifier).search(query);
      _searchFocusNode.unfocus();
    }
  }

  void _onTrendingTopicTap(TrendingTopic topic) {
    _searchController.text = topic.label;
    ref.read(searchProvider.notifier).searchByTopic(topic.label);
    _searchFocusNode.unfocus();
    setState(() {
      _publisherSuggestions = [];
    });
  }

  Future<void> _launchGoogleSearch(String query) async {
    if (query.isEmpty) return;
    final Uri url = Uri.parse(
      'https://www.google.com/search?q=${Uri.encodeComponent(query)}',
    );
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Could not launch Google search: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final themeMode = ref.watch(currentThemeModeProvider);

    final hPadding = MediaQuery.of(context).size.width * 0.05;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        centerTitle: true,
        toolbarHeight: 64,
        title: AppBarTitle(loc.search),
        leading: Builder(
          builder: (context) => Center(
            child: GlassIconButton(
              icon: Icons.menu_rounded,
              onPressed: () => Scaffold.of(context).openDrawer(),
              isDark: isDark,
            ),
          ),
        ),
        leadingWidth: 64,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(color: Colors.transparent),
          ),
        ),
      ),
      drawer: const AppDrawer(),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: AnimatedThemeContainer(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppGradients.getBackgroundGradient(
                      themeMode,
                    )[0].withValues(alpha: 0.85),
                    AppGradients.getBackgroundGradient(
                      themeMode,
                    )[1].withValues(alpha: 0.85),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: hPadding),
              child: Column(
                children: [
                  _buildGlassSearchBox(context, isDark),
                  Expanded(
                    child: _buildBody(
                      context,
                      ref.watch(searchProvider),
                      ref.watch(searchIntelligenceProvider),
                      _searchController.text.isNotEmpty,
                      ref.watch(searchProvider).searchResults.isNotEmpty,
                      isDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassSearchBox(BuildContext context, bool isDark) {
    final themeMode = ref.watch(currentThemeModeProvider);
    final isBangladesh = themeMode == AppThemeMode.bangladesh;
    final selectionColor = ref.watch(navIconColorProvider);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      height: 64,
      decoration: BoxDecoration(
        color: (isDark || isBangladesh)
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.black.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: (isDark || isBangladesh)
              ? Colors.white.withValues(alpha: 0.25)
              : Colors.black.withValues(alpha: 0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          if (isDark || isBangladesh)
            BoxShadow(
              color: selectionColor.withValues(alpha: 0.2),
              blurRadius: 15,
              spreadRadius: 2,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              autofocus: true,
              style: TextStyle(
                fontSize: 18,
                color: (isDark || isBangladesh) ? Colors.white : Colors.black,
                fontFamily: AppTypography.fontFamily,
                fontWeight: FontWeight.w600,
              ),
              cursorColor: selectionColor,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context).search,
                hintStyle: TextStyle(
                  color: (isDark || isBangladesh)
                      ? Colors.white54
                      : Colors.black45,
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                ),
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Icon(
                    Icons.search_rounded,
                    color: (isDark || isBangladesh)
                        ? Colors.white70
                        : Colors.black54,
                    size: 26,
                  ),
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GlassIconButton(
                          icon: Icons.close_rounded,
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                            _searchFocusNode.requestFocus();
                          },
                          isDark: isDark || isBangladesh,
                          size: 18,
                          backgroundColor: Colors.black.withValues(alpha: 0.2),
                        ),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
              onChanged: _onSearchChanged,
              onSubmitted: _onSearchSubmitted,
              textInputAction: TextInputAction.search,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    SearchState searchState,
    SearchIntelligenceState intelligenceState,
    bool isSearching,
    bool hasResults,
    bool isDark,
  ) {
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);

    if (isSearching) {
      final aiSuggestions = intelligenceState.filterSuggestions(
        _searchController.text,
        limit: 10,
      );
      if (hasResults && _publisherSuggestions.isEmpty) {
        // Topic search mode: show results with publisher info
        return _buildTopicResultsView(
          searchState.searchResults,
          searchState.activeTopicQuery,
          searchState.showGoogleFallback,
          isDark,
        );
      }

      // Suggestions Mode (Publishers + Google + Articles Mix)
      return ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // 1. Publisher Suggestions Grid
          if (_publisherSuggestions.isNotEmpty) ...[
            _glass(
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(loc.publishersLabel, theme.colorScheme.primary),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 3.5,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                    itemCount: _publisherSuggestions.length,
                    itemBuilder: (context, index) {
                      final entry = _publisherSuggestions[index];
                      return _buildSuggestionTile(
                        entry.key,
                        entry.value,
                        isDark,
                        true,
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 2. AI suggestions (latest + trending aware)
          if (aiSuggestions.isNotEmpty) ...[
            _glass(
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(loc.aiTrendingTopics, theme.colorScheme.primary),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: aiSuggestions.map((query) {
                      return Bouncy3DChip(
                        label: query,
                        selected: false,
                        baseColor: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.grey.shade100,
                        onTap: () {
                          _searchController.text = query;
                          _onSearchSubmitted(query);
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 3. Google Search Option
          _glass(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(
                  loc.searchOnGoogle(_searchController.text),
                  theme.colorScheme.primary,
                ),
                const SizedBox(height: 12),
                _buildGoogleSearchTile(_searchController.text, isDark),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 4. Actual results
          if (hasResults)
            _glass(
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(loc.resultsLabel, theme.colorScheme.primary),
                  const SizedBox(height: 12),
                  ...searchState.searchResults.map((article) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: NewsCard(
                        article: article,
                        onTap: () => _handleArticleTap(article),
                      ),
                    );
                  }),
                ],
              ),
            ),

          // Google fallback
          if (searchState.showGoogleFallback && !hasResults)
            _glass(
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(loc.noMatchesFound, theme.colorScheme.primary),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Text(
                      'No articles found in your feeds. Try searching on Google:',
                      style: TextStyle(
                        color: isDark ? Colors.white60 : Colors.black54,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildGoogleSearchTile(_searchController.text, isDark),
                ],
              ),
            ),

          const SizedBox(height: 100),
        ],
      );
    }

    // ─────────────────────────────────────────────
    // DEFAULT VIEW: Recent + Trending Topics
    // ─────────────────────────────────────────────
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        // Recent Searches
        if (searchState.recentSearches.isNotEmpty) ...[
          _glass(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _header(
                        loc.recentSearches,
                        theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GlassIconButton(
                      onPressed: () =>
                          ref.read(searchProvider.notifier).clearHistory(),
                      icon: Icons.delete_sweep_rounded,
                      isDark: isDark,
                      backgroundColor: Colors.red.withValues(alpha: 0.1),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: searchState.recentSearches.map((term) {
                    return Bouncy3DChip(
                      label: term,
                      selected: false,
                      baseColor: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.grey.shade100,
                      onTap: () {
                        _searchController.text = term;
                        _onSearchSubmitted(term);
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // ── TRENDING TOPICS ──────────────────────────
        _glass(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(loc.aiTrendingTopics, theme.colorScheme.primary),
              const SizedBox(height: 12),
              if (intelligenceState.isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (intelligenceState.trendingTopics.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    loc.noMatchesFound,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                )
              else
                _buildTrendingTopicsGrid(
                  intelligenceState.trendingTopics,
                  isDark,
                  theme,
                ),
            ],
          ),
        ),

        const SizedBox(height: 100),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // TRENDING TOPICS GRID
  // ─────────────────────────────────────────────
  Widget _buildTrendingTopicsGrid(
    List<TrendingTopic> topics,
    bool isDark,
    ThemeData theme,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 10,
      children: topics.map((topic) {
        return _TrendingTopicChip(
          topic: topic,
          isDark: isDark,
          accentColor: theme.colorScheme.primary,
          onTap: () => _onTrendingTopicTap(topic),
        );
      }).toList(),
    );
  }

  // ─────────────────────────────────────────────
  // TOPIC RESULTS VIEW (with publisher logos)
  // ─────────────────────────────────────────────
  Widget _buildTopicResultsView(
    List<NewsArticle> results,
    String? topicQuery,
    bool showGoogleFallback,
    bool isDark,
  ) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        // Back button
        if (topicQuery != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                GlassIconButton(
                  icon: Icons.arrow_back_rounded,
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                  isDark: isDark,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${results.length} articles for "$topicQuery"',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black54,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

        // Results with publisher info
        ...results.map((article) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ArticleWithPublisher(
              article: article,
              isDark: isDark,
              onTap: () => _handleArticleTap(article),
            ),
          );
        }),

        // Google fallback if no results
        if (showGoogleFallback && results.isEmpty && topicQuery != null)
          _glass(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(
                        Icons.search_off_rounded,
                        size: 48,
                        color: isDark ? Colors.white24 : Colors.black26,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No articles found in your feeds',
                        style: TextStyle(
                          color: isDark ? Colors.white60 : Colors.black54,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      _buildGoogleSearchTile(topicQuery, isDark),
                    ],
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildSuggestionTile(
    String title,
    String? iconPath,
    bool isDark,
    bool isPublisher,
  ) {
    return GestureDetector(
      onTap: () {
        _searchController.text = title;
        _onSearchSubmitted(title);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.grey.shade300,
          ),
        ),
        child: Row(
          children: [
            if (iconPath != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Image.asset(
                  iconPath,
                  width: 20,
                  height: 20,
                  errorBuilder: (_, _, _) => const Icon(Icons.public, size: 20),
                ),
              )
            else
              Icon(
                Icons.search,
                size: 18,
                color: isDark ? Colors.white54 : Colors.grey,
              ),

            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoogleSearchTile(String query, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GlassPillButton(
        onPressed: () => _launchGoogleSearch(query),
        label: loc.searchOnGoogle(query),
        icon: Icons.public,
        isPrimary: true,
        isDark: isDark,
      ),
    );
  }

  Widget _glass(Widget child) {
    final themeMode = ref.watch(currentThemeModeProvider);
    final bool isLight = themeMode == AppThemeMode.light;
    final bool isBangladesh = themeMode == AppThemeMode.bangladesh;
    final bool isDark = themeMode == AppThemeMode.dark;

    final Color faceColor = isBangladesh
        ? const Color(0xFF00392C).withValues(alpha: 0.35)
        : (isLight
              ? Colors.white.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.06));

    final Color highlightColor = isBangladesh
        ? const Color(0xFF006A4E).withValues(alpha: 0.2)
        : (isLight
              ? Colors.grey.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.1));

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              color: faceColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: highlightColor.withValues(alpha: 0.15),
                width: 1.5,
              ),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark || isBangladesh
                    ? [
                        Colors.white.withValues(alpha: 0.2),
                        Colors.white.withValues(alpha: 0.05),
                        Colors.white.withValues(alpha: 0.01),
                      ]
                    : [
                        Colors.white.withValues(alpha: 0.95),
                        Colors.white.withValues(alpha: 0.7),
                        Colors.white.withValues(alpha: 0.5),
                      ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 
                    isDark || isBangladesh ? 0.4 : 0.12,
                  ),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 
                    isDark || isBangladesh ? 0.03 : 0.15,
                  ),
                  blurRadius: 8,
                  spreadRadius: -4,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 20,
                  right: 20,
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.0),
                          Colors.white.withValues(alpha: 
                            isDark || isBangladesh ? 0.5 : 0.9,
                          ),
                          Colors.white.withValues(alpha: 
                            isDark || isBangladesh ? 0.5 : 0.9,
                          ),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                        stops: const [0.0, 0.2, 0.8, 1.0],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  top: 20,
                  bottom: 20,
                  child: Container(
                    width: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.0),
                          Colors.white.withValues(alpha: 
                            isDark || isBangladesh ? 0.2 : 0.4,
                          ),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [child],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(String title, Color color) {
    final themeMode = ref.watch(currentThemeModeProvider);
    final Color accentColor;
    if (themeMode == AppThemeMode.bangladesh) {
      accentColor = Colors.redAccent;
    } else if (themeMode == AppThemeMode.light) {
      accentColor = Colors.blueAccent;
    } else {
      accentColor = const Color(0xFFFFC107);
    }

    final theme = Theme.of(context);
    final headerBgColor = theme.scaffoldBackgroundColor;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            height: 1.5,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.0),
                  accentColor.withValues(alpha: 0.5),
                  accentColor.withValues(alpha: 0.5),
                  Colors.white.withValues(alpha: 0.0),
                ],
                stops: const [0.0, 0.3, 0.7, 1.0],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              color: headerBgColor.withValues(alpha: 0.9),
              child: Text(
                title.toUpperCase(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: accentColor,
                  letterSpacing: 2.0,
                  fontFamily: AppTypography.fontFamily,
                  shadows: [
                    Shadow(color: accentColor.withValues(alpha: 0.4), blurRadius: 10),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// TRENDING TOPIC CHIP (with article count badge)
// ─────────────────────────────────────────────
class _TrendingTopicChip extends StatelessWidget {
  const _TrendingTopicChip({
    required this.topic,
    required this.isDark,
    required this.accentColor,
    required this.onTap,
  });

  final TrendingTopic topic;
  final bool isDark;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isDark
              ? accentColor.withValues(alpha: 0.15)
              : accentColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: accentColor.withValues(alpha: isDark ? 0.35 : 0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: isDark ? 0.15 : 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.trending_up_rounded,
              size: 14,
              color: accentColor.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 6),
            Text(
              topic.label,
              style: TextStyle(
                color: isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black87,
                fontWeight: FontWeight.w600,
                fontSize: 13,
                fontFamily: AppTypography.fontFamily,
              ),
            ),
            if (topic.articleCount > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${topic.articleCount}',
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
            // Show top publisher logo if available
            if (topic.publishers.isNotEmpty &&
                topic.publishers.first.logoPath != null) ...[
              const SizedBox(width: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.asset(
                  topic.publishers.first.logoPath!,
                  width: 16,
                  height: 16,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ARTICLE CARD WITH PUBLISHER INFO
// ─────────────────────────────────────────────
class _ArticleWithPublisher extends StatelessWidget {
  const _ArticleWithPublisher({
    required this.article,
    required this.isDark,
    required this.onTap,
  });

  final NewsArticle article;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final logoPath = _resolvePublisherLogo(article.source);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Publisher header
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Row(
            children: [
              if (logoPath != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.asset(
                      logoPath,
                      width: 18,
                      height: 18,
                      errorBuilder: (_, _, _) => Icon(
                        Icons.public_rounded,
                        size: 18,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(
                    Icons.public_rounded,
                    size: 18,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
              Flexible(
                child: Text(
                  article.source,
                  style: TextStyle(
                    color: isDark ? Colors.white60 : Colors.black54,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        // Article card
        NewsCard(article: article, onTap: onTap),
      ],
    );
  }

  String? _resolvePublisherLogo(String sourceName) {
    if (SourceLogos.logos.containsKey(sourceName)) {
      return SourceLogos.logos[sourceName];
    }
    final lower = sourceName.toLowerCase();
    for (final entry in SourceLogos.logos.entries) {
      if (entry.key.toLowerCase().contains(lower) ||
          lower.contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }
    return null;
  }
}
