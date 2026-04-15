import 'dart:async' show unawaited;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../../../core/di/providers.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/theme/theme_skeleton.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../widgets/premium_scaffold.dart';
import '../../../core/enums/theme_mode.dart';
import '../../../core/config/performance_config.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../widgets/platform_surface_treatment.dart';
import '../../providers/favorites_providers.dart'
    show
        favoriteCategoryFilterProvider,
        favoriteTimeFilterProvider,
        favoritesProvider,
        filteredFavoritesProvider;
import '../../providers/theme_providers.dart'
    show
        borderColorProvider,
        currentThemeModeProvider,
        glassColorProvider,
        navIconColorProvider,
        themeSkeletonProvider;
import '../../widgets/app_drawer.dart';
import '../../widgets/premium_screen_header.dart';
import '../../../core/navigation/app_paths.dart';
import '../../../core/navigation/navigation_helper.dart';
import '../home/widgets/news_card.dart' show NewsCard;
import '../magazine/widgets/magazine_card.dart';
import '../../../domain/entities/news_article.dart';

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  Future<void> _handleArticleTap(NewsArticle article) async {
    // Trigger ad logic (respects premium status internally)
    unawaited(ref.read(interstitialAdServiceProvider).onArticleViewed());

    if (!mounted) return;
    await NavigationHelper.openNewsDetail<void>(context, article);
  }

  String _categoryToLabel(String cat, AppLocalizations loc) {
    if (cat == 'Articles') return loc.articles;
    if (cat == 'Magazines') return loc.magazines;
    if (cat == 'Newspapers') return loc.newspapers;
    return 'All';
  }

  String _labelToCategory(String label, AppLocalizations loc) {
    if (label == loc.articles) return 'Articles';
    if (label == loc.magazines) return 'Magazines';
    if (label == loc.newspapers) return 'Newspapers';
    return 'All';
  }

  // ... (existing imports updated via replace_file_content block)

  @override
  Widget build(BuildContext context) {
    final AppLocalizations loc = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final Color textColor = theme.textTheme.bodyLarge?.color ?? Colors.white;
    final List<String> categories = <String>[
      'All',
      loc.articles,
      loc.magazines,
      loc.newspapers,
    ];
    final List<String> filters = <String>['All', 'Today', 'This Week', 'Older'];

    final AppThemeMode mode = ref.watch(currentThemeModeProvider);
    final skeleton = ref.watch(themeSkeletonProvider);
    final bool isDark = theme.brightness == Brightness.dark;
    final perf = PerformanceConfig.of(context);
    final preferMaterialChrome = preferAndroidMaterialSurfaceChrome(context);
    final bool lowEffects =
        perf.reduceEffects ||
        perf.lowPowerMode ||
        perf.isLowEndDevice ||
        perf.performanceTier != DevicePerformanceTier.flagship;

    final filtered = ref.watch(filteredFavoritesProvider);
    final catFilter = ref.watch(favoriteCategoryFilterProvider);
    final timeFilter = ref.watch(favoriteTimeFilterProvider);

    final glassColor = preferMaterialChrome
        ? materialSurfaceOverlayColor(
            theme.colorScheme,
            tone: MaterialSurfaceTone.highest,
            surfaceAlpha: isDark ? 0.94 : 0.98,
            tintAlpha: isDark ? 0.06 : 0.04,
          )
        : ref.watch(glassColorProvider);
    final borderColor = preferMaterialChrome
        ? theme.colorScheme.outlineVariant.withValues(alpha: 0.70)
        : ref.watch(borderColorProvider);
    final navIconColor = ref.watch(navIconColorProvider);
    final cheapComposite = lowEffects || preferMaterialChrome;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        context.go(AppPaths.home);
      },
      child: PremiumScaffold(
        useBackground: false, // Hosted in MainNavigationScreen
        showBackgroundParticles: false,
        drawer: const AppDrawer(),
        title: loc.favorites,
        headerLeading: PremiumHeaderLeading.menu,
        body: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: cheapComposite
                    ? _buildFilterPanel(
                        isDark: isDark,
                        glassColor: glassColor,
                        borderColor: borderColor,
                        navIconColor: navIconColor,
                        textColor: textColor,
                        categories: categories,
                        filters: filters,
                        currentCategory: _categoryToLabel(catFilter, loc),
                        currentTime: timeFilter,
                      )
                    : BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: _buildFilterPanel(
                          isDark: isDark,
                          glassColor: glassColor,
                          borderColor: borderColor,
                          navIconColor: navIconColor,
                          textColor: textColor,
                          categories: categories,
                          filters: filters,
                          currentCategory: _categoryToLabel(catFilter, loc),
                          currentTime: timeFilter,
                        ),
                      ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  setState(() {});
                },
                child: filtered.isEmpty
                    ? _buildEmpty(loc, textColor)
                    : ListView.builder(
                        cacheExtent: lowEffects ? 240 : 520,
                        physics: lowEffects
                            ? const ClampingScrollPhysics()
                            : const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          return _buildCard(
                            context,
                            filtered[index],
                            isDark,
                            mode,
                            skeleton,
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(AppLocalizations loc, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 100),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.favorite_border,
              size: 64,
              color: color.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              loc.noFavoritesYet,
              style: TextStyle(
                color: color.withValues(alpha: 0.7),
                fontSize: 16,
                fontFamily: AppTypography.fontFamily,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPanel({
    required bool isDark,
    required Color glassColor,
    required Color borderColor,
    required Color navIconColor,
    required Color textColor,
    required List<String> categories,
    required List<String> filters,
    required String currentCategory,
    required String currentTime,
  }) {
    final loc = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: glassColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.tune, color: navIconColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: currentCategory,
                isExpanded: true,
                dropdownColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                icon: Icon(
                  Icons.expand_more,
                  color: textColor.withValues(alpha: 0.5),
                ),
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  fontFamily: AppTypography.fontFamily,
                ),
                items: categories
                    .map(
                      (String cat) =>
                          DropdownMenuItem(value: cat, child: Text(cat)),
                    )
                    .toList(),
                onChanged: (String? val) =>
                    ref.read(favoriteCategoryFilterProvider.notifier).state =
                        _labelToCategory(val!, loc),
              ),
            ),
          ),
          Container(
            width: 1,
            height: 20,
            color: borderColor,
            margin: const EdgeInsets.symmetric(horizontal: 12),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: currentTime,
              dropdownColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
              icon: Icon(
                Icons.calendar_month,
                color: textColor.withValues(alpha: 0.5),
                size: 18,
              ),
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w700,
                fontSize: 14,
                fontFamily: AppTypography.fontFamily,
              ),
              items: filters
                  .map((String f) => DropdownMenuItem(value: f, child: Text(f)))
                  .toList(),
              onChanged: (String? val) =>
                  ref.read(favoriteTimeFilterProvider.notifier).state = val!,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(
    BuildContext context,
    Map<String, dynamic> item,
    bool isDark,
    AppThemeMode mode,
    ThemeSkeleton skeleton,
  ) {
    final perf = PerformanceConfig.of(context);
    final bool lowEffects =
        perf.reduceEffects ||
        perf.lowPowerMode ||
        perf.isLowEndDevice ||
        perf.performanceTier != DevicePerformanceTier.flagship;
    final DateTime savedAt =
        DateTime.tryParse(item['savedAt'] ?? '') ?? DateTime.now();
    final String subtitle = 'Saved on ${DateFormat.yMMMd().format(savedAt)}';

    Widget content;

    if (item.containsKey('title')) {
      final NewsArticle article = NewsArticle.fromMap(item);
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          NewsCard(
            article: article,
            highlight: false,
            onTap: () => _handleArticleTap(article),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              IconButton(
                icon: const Icon(Icons.share, size: 20),
                color: isDark ? Colors.white70 : Colors.black54,
                onPressed: () =>
                    Share.share('${article.title}\n${article.url}'),
              ),
            ],
          ),
        ],
      );
    } else if (item.containsKey('tags')) {
      content = MagazineCard(
        magazine: item,
        mode: mode,
        skeleton: skeleton,
        isFavorite: true,
        onFavoriteToggle: () async {
          await ref.read(favoritesProvider.notifier).toggleMagazine(item);
        },
        highlight: false,
      );
    } else {
      content = ListTile(
        leading: const Icon(Icons.public),
        title: Text(
          item['name'] ?? 'Unknown',
          style: const TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontFamily: AppTypography.fontFamily),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () async {
            await ref.read(favoritesProvider.notifier).toggleNewspaper(item);
          },
        ),
      );
    }

    final glassColor = ref.watch(glassColorProvider);
    final borderColor = ref.watch(borderColorProvider);

    // Wrap in Glass Container
    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: glassColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
          boxShadow: lowEffects
              ? const <BoxShadow>[]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: content,
      ),
    );
  }
}
