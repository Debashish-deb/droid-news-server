// lib/features/search/search_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/di/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/performance_config.dart';

import '../../widgets/premium_scaffold.dart';
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
import '../../widgets/premium_screen_header.dart';
import '../../../core/navigation/navigation_helper.dart';
import '../../widgets/platform_surface_treatment.dart';

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
    unawaited(ref.read(interstitialAdServiceProvider).onArticleViewed());

    if (!mounted) return;
    await NavigationHelper.openNewsDetail<void>(context, article);
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    // Update the controller provider for memoized suggestions
    ref.read(searchControllerProvider.notifier).state = query;

    if (query.isEmpty) {
      ref.read(searchProvider.notifier).clearTopicSearch();
    }

    // Debounce API Search
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
      // Logic handled by providers
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
    final perf = PerformanceConfig.of(context);
    final bool lowEffects =
        perf.reduceEffects ||
        perf.lowPowerMode ||
        perf.isLowEndDevice ||
        perf.performanceTier != DevicePerformanceTier.flagship;

    final hPadding = MediaQuery.of(context).size.width * 0.05;

    return PremiumScaffold(
      useBackground: false, // Hosted in MainNavigationScreen
      showBackgroundParticles: false,
      drawer: const AppDrawer(),
      title: loc.search,
      headerLeading: PremiumHeaderLeading.menu,
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: hPadding),
          child: Column(
            children: [
              _buildGlassSearchBox(context, isDark, lowEffects: lowEffects),
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
    );
  }

  Widget _buildGlassSearchBox(
    BuildContext context,
    bool isDark, {
    required bool lowEffects,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final themeMode = ref.watch(currentThemeModeProvider);
    final isBangladesh = themeMode.name == 'bangladesh';
    final preferMaterialChrome = preferAndroidMaterialSurfaceChrome(context);
    final selectionColor = ref.watch(navIconColorProvider);
    final shellColor = preferMaterialChrome
        ? materialSurfaceOverlayColor(
            scheme,
            surfaceAlpha: isDark || isBangladesh ? 0.94 : 0.98,
            tintAlpha: isDark || isBangladesh ? 0.08 : 0.05,
          )
        : Color.alphaBlend(
            selectionColor.withValues(
              alpha: isDark || isBangladesh ? 0.08 : 0.03,
            ),
            (isDark || isBangladesh)
                ? scheme.surface.withValues(alpha: 0.76)
                : scheme.surface.withValues(alpha: 0.94),
          );
    final outlineColor = selectionColor.withValues(
      alpha: isDark || isBangladesh ? 0.22 : 0.14,
    );
    final shadowColor = theme.colorScheme.shadow.withValues(
      alpha: isDark || isBangladesh ? 0.18 : 0.10,
    );

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      height: 64,
      decoration: BoxDecoration(
        color: shellColor,
        borderRadius: AppRadius.xxlBorder,
        border: Border.all(color: outlineColor, width: 1.5),
        boxShadow: lowEffects
            ? const <BoxShadow>[]
            : [
                BoxShadow(
                  color: shadowColor,
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
        borderRadius: AppRadius.xxlBorder,
        child: lowEffects || preferMaterialChrome
            ? _buildSearchFieldContent(
                context,
                isDark: isDark,
                isBangladesh: isBangladesh,
                selectionColor: selectionColor,
              )
            : BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: _buildSearchFieldContent(
                  context,
                  isDark: isDark,
                  isBangladesh: isBangladesh,
                  selectionColor: selectionColor,
                ),
              ),
      ),
    );
  }

  Widget _buildSearchFieldContent(
    BuildContext context, {
    required bool isDark,
    required bool isBangladesh,
    required Color selectionColor,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        autofocus: true,
        style:
            theme.textTheme.titleMedium?.copyWith(
              fontSize: 18,
              color: scheme.onSurface,
              fontFamily: AppTypography.fontFamily,
              fontWeight: FontWeight.w600,
            ) ??
            TextStyle(
              fontSize: 18,
              color: scheme.onSurface,
              fontFamily: AppTypography.fontFamily,
              fontWeight: FontWeight.w600,
            ),
        cursorColor: selectionColor,
        decoration: InputDecoration(
          hintText: AppLocalizations.of(context).search,
          hintStyle:
              theme.textTheme.bodyLarge?.copyWith(
                color: scheme.onSurfaceVariant,
                fontSize: 18,
                fontWeight: FontWeight.w400,
              ) ??
              TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 18,
                fontWeight: FontWeight.w400,
              ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Icon(
              Icons.search_rounded,
              color: scheme.onSurfaceVariant,
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
                    backgroundColor: scheme.surfaceContainerHighest.withValues(
                      alpha: isDark || isBangladesh ? 0.78 : 0.92,
                    ),
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
    final perf = PerformanceConfig.of(context);
    final bool lowEffects =
        perf.reduceEffects ||
        perf.lowPowerMode ||
        perf.isLowEndDevice ||
        perf.performanceTier != DevicePerformanceTier.flagship;

    if (isSearching) {
      final aiSuggestions = intelligenceState.filterSuggestions(
        _searchController.text,
        limit: 10,
      );
      final publisherSuggestions = ref.watch(publisherSuggestionsProvider);

      if (hasResults && publisherSuggestions.isEmpty) {
        // Topic search mode: show results with publisher info
        return _buildTopicResultsView(
          searchState.searchResults,
          searchState.activeTopicQuery,
          searchState.showGoogleFallback,
          isDark,
        );
      }

      // Suggestions Mode (Publishers + Google + Articles Mix)
      return CustomScrollView(
        physics: lowEffects
            ? const ClampingScrollPhysics()
            : const BouncingScrollPhysics(),
        slivers: [
          const SliverPadding(padding: EdgeInsets.only(top: 8)),

          // 1. Publisher Suggestions Grid
          if (publisherSuggestions.isNotEmpty)
            _sliverGlass(
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(loc.publishersLabel, theme.colorScheme.primary),
                  const SizedBox(height: 12),
                  GridView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 2.2,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                    itemCount: publisherSuggestions.length,
                    itemBuilder: (context, index) {
                      final entry = publisherSuggestions[index];
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

          if (publisherSuggestions.isNotEmpty)
            const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // 2. AI suggestions (latest + trending aware)
          if (aiSuggestions.isNotEmpty)
            _sliverGlass(
              Column(
                mainAxisSize: MainAxisSize.min,
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

          if (aiSuggestions.isNotEmpty)
            const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // 3. Google Search Option
          _sliverGlass(
            Column(
              mainAxisSize: MainAxisSize.min,
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

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // 4. Actual results
          if (hasResults)
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                if (index == 0) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _header(loc.resultsLabel, theme.colorScheme.primary),
                      const SizedBox(height: 12),
                    ],
                  );
                }
                final article = searchState.searchResults[index - 1];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: NewsCard(
                    article: article,
                    onTap: () => _handleArticleTap(article),
                  ),
                );
              }, childCount: searchState.searchResults.length + 1),
            ),

          // Google fallback
          if (searchState.showGoogleFallback && !hasResults)
            _sliverGlass(
              Column(
                mainAxisSize: MainAxisSize.min,
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

          const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
        ],
      );
    }

    // ─────────────────────────────────────────────
    // DEFAULT VIEW: Recent + Trending Topics
    // ─────────────────────────────────────────────
    return CustomScrollView(
      physics: lowEffects
          ? const ClampingScrollPhysics()
          : const BouncingScrollPhysics(),
      slivers: [
        const SliverPadding(padding: EdgeInsets.only(top: 8)),
        if (searchState.recentSearches.isNotEmpty)
          _sliverGlass(
            Column(
              mainAxisSize: MainAxisSize.min,
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
                      backgroundColor: theme.colorScheme.primary.withValues(
                        alpha: 0.1,
                      ),
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

        if (searchState.recentSearches.isNotEmpty)
          const SliverToBoxAdapter(child: SizedBox(height: 16)),

        // ── TRENDING TOPICS ──────────────────────────
        _sliverGlass(
          Column(
            mainAxisSize: MainAxisSize.min,
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

        const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
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
    final perf = PerformanceConfig.of(context);
    final bool lowEffects =
        perf.reduceEffects ||
        perf.lowPowerMode ||
        perf.isLowEndDevice ||
        perf.performanceTier != DevicePerformanceTier.flagship;
    return CustomScrollView(
      physics: lowEffects
          ? const ClampingScrollPhysics()
          : const BouncingScrollPhysics(),
      slivers: [
        const SliverPadding(padding: EdgeInsets.only(top: 8)),

        // Back button & Stats
        if (topicQuery != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12, left: 4, right: 4),
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
          ),

        // Results with publisher info
        if (results.isNotEmpty)
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final article = results[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ArticleWithPublisher(
                  article: article,
                  isDark: isDark,
                  onTap: () => _handleArticleTap(article),
                ),
              );
            }, childCount: results.length),
          ),

        if (showGoogleFallback && results.isEmpty && topicQuery != null)
          _sliverGlass(
            Column(
              mainAxisSize: MainAxisSize.min,
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

        const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
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
        child: isPublisher
            ? Center(
                child: iconPath != null
                    ? Image.asset(
                        iconPath,
                        height: 24,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.public, size: 24),
                      )
                    : Icon(
                        Icons.search,
                        size: 20,
                        color: isDark ? Colors.white54 : Colors.grey,
                      ),
              )
            : Row(
                children: [
                  if (iconPath != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Image.asset(
                        iconPath,
                        width: 20,
                        height: 20,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.public, size: 20),
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

  Widget _sliverGlass(Widget child) {
    return SliverToBoxAdapter(child: _glass(child));
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
    final perf = PerformanceConfig.of(context);
    final bool lowEffects =
        perf.reduceEffects ||
        perf.lowPowerMode ||
        perf.isLowEndDevice ||
        perf.performanceTier != DevicePerformanceTier.flagship;
    final scheme = Theme.of(context).colorScheme;
    final preferMaterialChrome = preferAndroidMaterialSurfaceChrome(context);
    final isBangladesh = themeMode == AppThemeMode.bangladesh;
    final bool isDark =
        isBangladesh || Theme.of(context).brightness == Brightness.dark;
    final bool isLight = !isDark;

    final Color faceColor = preferMaterialChrome
        ? materialSurfaceOverlayColor(
            scheme,
            surfaceAlpha: isDark || isBangladesh ? 0.94 : 0.98,
            tintAlpha: isDark || isBangladesh ? 0.08 : 0.05,
          )
        : isBangladesh
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
        child: lowEffects || preferMaterialChrome
            ? _buildGlassPanel(
                child: child,
                faceColor: faceColor,
                highlightColor: highlightColor,
                isDark: isDark,
                isBangladesh: isBangladesh,
                lowEffects: lowEffects,
              )
            : BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: _buildGlassPanel(
                  child: child,
                  faceColor: faceColor,
                  highlightColor: highlightColor,
                  isDark: isDark,
                  isBangladesh: isBangladesh,
                  lowEffects: lowEffects,
                ),
              ),
      ),
    );
  }

  Widget _buildGlassPanel({
    required Widget child,
    required Color faceColor,
    required Color highlightColor,
    required bool isDark,
    required bool isBangladesh,
    required bool lowEffects,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: faceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: highlightColor.withValues(alpha: lowEffects ? 0.24 : 0.15),
          width: lowEffects ? 1.1 : 1.5,
        ),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark || isBangladesh
              ? [
                  Colors.white.withValues(alpha: lowEffects ? 0.12 : 0.2),
                  Colors.white.withValues(alpha: lowEffects ? 0.02 : 0.05),
                  Colors.white.withValues(alpha: 0.01),
                ]
              : [
                  Colors.white.withValues(alpha: lowEffects ? 0.88 : 0.95),
                  Colors.white.withValues(alpha: lowEffects ? 0.72 : 0.7),
                  Colors.white.withValues(alpha: lowEffects ? 0.58 : 0.5),
                ],
        ),
        boxShadow: lowEffects
            ? const <BoxShadow>[]
            : [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: isDark || isBangladesh ? 0.4 : 0.12,
                  ),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.white.withValues(
                    alpha: isDark || isBangladesh ? 0.03 : 0.15,
                  ),
                  blurRadius: 8,
                  spreadRadius: -4,
                  offset: const Offset(0, -4),
                ),
              ],
      ),
      child: Stack(
        children: [
          if (!lowEffects)
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
                      Colors.white.withValues(
                        alpha: isDark || isBangladesh ? 0.5 : 0.9,
                      ),
                      Colors.white.withValues(
                        alpha: isDark || isBangladesh ? 0.5 : 0.9,
                      ),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                    stops: const [0.0, 0.2, 0.8, 1.0],
                  ),
                ),
              ),
            ),
          if (!lowEffects)
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
                      Colors.white.withValues(
                        alpha: isDark || isBangladesh ? 0.2 : 0.4,
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
    );
  }

  Widget _header(String title, Color color) {
    final themeMode = ref.watch(currentThemeModeProvider);
    final perf = PerformanceConfig.of(context);
    final bool lowEffects =
        perf.reduceEffects ||
        perf.lowPowerMode ||
        perf.isLowEndDevice ||
        perf.performanceTier != DevicePerformanceTier.flagship;
    final Color accentColor;
    final theme = Theme.of(context);
    final isTrending = title == loc.aiTrendingTopics;
    if (isTrending) {
      accentColor = color;
    } else if (themeMode == AppThemeMode.bangladesh) {
      accentColor = Colors.redAccent;
    } else if (Theme.of(context).brightness == Brightness.light) {
      accentColor = Colors.blueAccent;
    } else {
      accentColor = const Color(0xFFFFC107);
    }

    final _ = Theme.of(context);
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
                  shadows: lowEffects
                      ? null
                      : [
                          Shadow(
                            color: accentColor.withValues(alpha: 0.4),
                            blurRadius: 10,
                          ),
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
    final perf = PerformanceConfig.of(context);
    final bool lowEffects =
        perf.reduceEffects ||
        perf.lowPowerMode ||
        perf.isLowEndDevice ||
        perf.performanceTier != DevicePerformanceTier.flagship;
    final bool lowMotion =
        perf.reduceMotion ||
        perf.performanceTier != DevicePerformanceTier.flagship ||
        perf.lowPowerMode ||
        perf.isLowEndDevice ||
        (MediaQuery.maybeOf(context)?.disableAnimations ?? false);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: lowMotion ? Duration.zero : const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isDark
              ? accentColor.withValues(alpha: 0.15)
              : accentColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: accentColor.withValues(alpha: isDark ? 0.35 : 0.2),
          ),
          boxShadow: lowEffects
              ? const <BoxShadow>[]
              : [
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
                color: isDark
                    ? Colors.white.withValues(alpha: 0.9)
                    : Colors.black87,
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
