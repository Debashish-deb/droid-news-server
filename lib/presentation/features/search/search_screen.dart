// lib/features/search/search_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../domain/entities/news_article.dart';
import 'providers/search_provider.dart';
import 'providers/search_intelligence_provider.dart';
import '../home/widgets/news_card.dart';
import '../../widgets/category_chips_bar.dart';

import '../../../core/utils/source_logos.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/design_tokens.dart'; 
import '../../../core/enums/theme_mode.dart';
import '../../providers/theme_providers.dart';
import '../../widgets/app_drawer.dart';
import 'dart:ui'; 
import '../../widgets/glass_pill_button.dart';
import '../../widgets/glass_icon_button.dart';
import '../../widgets/animated_theme_container.dart';
import '../../../core/theme.dart';
import '../common/app_bar.dart';
import '../../../core/app_paths.dart';
import '../../../../infrastructure/services/interstitial_ad_service.dart';
import '../../widgets/unlock_article_dialog.dart';
import 'package:go_router/go_router.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
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

    // Trigger ad logic (respects premium status internally)
    InterstitialAdService().onArticleViewed();

    if (!mounted) return;
    context.push(
      AppPaths.newsDetail,
      extra: article,
    );
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
            .take(6) // Limit local matches
            .toList();
      });
    } else {
      setState(() {
        _publisherSuggestions = [];
      });
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

  Future<void> _launchGoogleSearch(String query) async {
    if (query.isEmpty) return;
    final Uri url = Uri.parse('https://www.google.com/search?q=${Uri.encodeComponent(query)}');
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

    return Scaffold(
      extendBodyBehindAppBar: true, // Allow body to flow behind
      appBar: AppBar(
        centerTitle: true,
        toolbarHeight: 64,
        title: AppBarTitle(AppLocalizations.of(context).search),
        leading: Builder(
          builder: (context) => Center(
            child: GlassIconButton(
              icon: Icons.menu_rounded, // Changed to Apps drawer button
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
      drawer: const AppDrawer(), // Added drawer to SearchScreen
      body: Stack(
        fit: StackFit.expand,
        children: [
           // Background Gradient
           Positioned.fill(
             child: AnimatedThemeContainer(
               decoration: BoxDecoration(
                 gradient: LinearGradient(
                   begin: Alignment.topLeft,
                   end: Alignment.bottomRight,
                   colors: [
                     AppGradients.getBackgroundGradient(themeMode)[0].withOpacity(0.85),
                     AppGradients.getBackgroundGradient(themeMode)[1].withOpacity(0.85),
                   ],
                 ),
               ),
             ),
           ),
           
           SafeArea(
             bottom: false,
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
                      Theme.of(context).brightness == Brightness.dark,
                   ),
                 ),
               ],
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
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      height: 64, // Slightly taller for more presence
      decoration: BoxDecoration(
        color: (isDark || isBangladesh) ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.06),
        borderRadius: BorderRadius.circular(32), // More pill-like
        border: Border.all(
          color: (isDark || isBangladesh) ? Colors.white.withOpacity(0.25) : Colors.black.withOpacity(0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          if (isDark || isBangladesh)
            BoxShadow(
              color: selectionColor.withOpacity(0.2),
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
                  color: (isDark || isBangladesh) ? Colors.white54 : Colors.black45,
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                ),
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Icon(
                    Icons.search_rounded, 
                    color: (isDark || isBangladesh) ? Colors.white70 : Colors.black54,
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
                        backgroundColor: Colors.black.withOpacity(0.2),
                      ),
                    )
                  : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
    final themeMode = ref.watch(currentThemeModeProvider);

    if (isSearching) {
       // Show Combined Suggestions Grid if we have typed something but maybe not yet hit enter or just filters
       // Actually, isSearching here means "Text is not empty".
       
       if (hasResults && _publisherSuggestions.isEmpty) {
          // Pure Article Results (e.g. after pressing enter)
          return _buildResultsView(searchState.searchResults);
       } 

       // Suggestions Mode (Publishers + Google + Articles Mix)
       return CustomScrollView(
         slivers: [
            // 1. Publisher Suggestions Grid (2 Columns)
            if (_publisherSuggestions.isNotEmpty) ...[
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      'Publishers', // Localize ideally
                      style: TextStyle(
                        fontSize: 14, 
                        fontWeight: FontWeight.bold, 
                        color: isDark ? Colors.white60 : Colors.grey,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                   padding: const EdgeInsets.symmetric(horizontal: 16),
                   sliver: SliverGrid(
                     gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                       crossAxisCount: 2,
                       childAspectRatio: 3.0, // Wide Pill
                       crossAxisSpacing: 10,
                       mainAxisSpacing: 10,
                     ),
                     delegate: SliverChildBuilderDelegate(
                       (context, index) {
                          final entry = _publisherSuggestions[index];
                          return _buildSuggestionTile(entry.key, entry.value, isDark, true);
                       },
                       childCount: _publisherSuggestions.length,
                     ),
                   ),
                ),
            ],

            // 2. Google Search Option (Always visible when typing)
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverToBoxAdapter(
                child: _buildGoogleSearchTile(_searchController.text, isDark),
              ),
            ),
            
            // 3. Fallback or actual results
            if (hasResults)
               SliverList(
                 delegate: SliverChildBuilderDelegate(
                   (context, index) => Padding(
                     padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                     child: NewsCard(
                       article: searchState.searchResults[index],
                       onTap: () => _handleArticleTap(searchState.searchResults[index]),
                     ),
                   ),
                   childCount: searchState.searchResults.length,
                 ),
               ),
         ],
       );
    }

    // Default View (Recent + Trending)
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (searchState.recentSearches.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                loc.recentSearches,
                style: TextStyle(
                  fontSize: 22, 
                  fontWeight: FontWeight.w900, 
                  color: (isDark || themeMode == AppThemeMode.bangladesh) ? Colors.white : Colors.black,
                  letterSpacing: -0.5
                ),
              ),
              GlassPillButton(
                onPressed: () {
                   ref.read(searchProvider.notifier).clearHistory();
                },
                label: loc.clearAll, 
                icon: Icons.delete_outline,
                isDestructive: true,
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: searchState.recentSearches.map((term) {
              return Bouncy3DChip(
                label: term,
                selected: false,
                baseColor: Colors.grey.shade100,
                onTap: () {
                  _searchController.text = term;
                  _onSearchSubmitted(term);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
        ],

        Text(
          loc.aiTrendingTopics,
          style: TextStyle(
            fontSize: 22, 
            fontWeight: FontWeight.w900, 
            color: (isDark || themeMode == AppThemeMode.bangladesh) ? Colors.white : Colors.black,
            letterSpacing: -0.5
          ),
        ),
        const SizedBox(height: 12),
        if (intelligenceState.isLoading)
           const Center(child: CircularProgressIndicator())
        else if (intelligenceState.trendingTopics.isEmpty)
           Text(loc.noMatchesFound, style: const TextStyle(color: Colors.grey))
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: intelligenceState.trendingTopics.map((topic) {
              return Bouncy3DChip(
                label: '#$topic',
                selected: false,
                baseColor: theme.colorScheme.primary.withOpacity(0.1),
                textColor: theme.colorScheme.primary, // Primary color text
                onTap: () {
                  _searchController.text = topic;
                  _onSearchSubmitted(topic);
                },
              );
            }).toList(),
          ),
          
        const SizedBox(height: 24),
        
        Text(
          loc.aiRecommendations,
          style: TextStyle(
            fontSize: 22, 
            fontWeight: FontWeight.w900, 
            color: (isDark || themeMode == AppThemeMode.bangladesh) ? Colors.white : Colors.black,
            letterSpacing: -0.5
          ),
        ),
        const SizedBox(height: 12),
        ...intelligenceState.personalizedRecommendations.map((article) {
           return Padding(
             padding: const EdgeInsets.only(bottom: 12),
             child: NewsCard(
               article: article,
               onTap: () => _handleArticleTap(article),
             ),
           );
        }),
      ],
    );
  }

  Widget _buildSuggestionTile(String title, String? iconPath, bool isDark, bool isPublisher) {
    return GestureDetector(
      onTap: () {
         _searchController.text = title;
         _onSearchSubmitted(title);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300,
          ),
          boxShadow: [
             if (!isDark)
              BoxShadow(color: Colors.grey.shade100, blurRadius: 4, offset:const Offset(0, 2))
          ]
        ),
        child: Row(
          children: [
             if (iconPath != null) 
               Padding(
                 padding: const EdgeInsets.only(right: 8),
                 child: Image.asset(iconPath, width: 20, height: 20, errorBuilder: (_,__,___) => const Icon(Icons.public, size: 20)),
               )
             else
               Icon(Icons.search, size: 18, color: isDark ? Colors.white54 : Colors.grey),
               
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
        label: 'Search "$query" on Google',
        icon: Icons.public, // Google icon approximation
        isPrimary: true,
        isDark: isDark,
      ),
    );
  }

  Widget _buildResultsView(List<NewsArticle> results) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: results.length,
      itemBuilder: (context, index) {
         return Padding(
           padding: const EdgeInsets.only(bottom: 16),
           child: NewsCard(
             article: results[index],
             onTap: () => _handleArticleTap(results[index]),
           ),
         );
      },
    );
  }
}
