import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../../../core/design_tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/enums/theme_mode.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../core/theme.dart' show AppGradients;
import '../../providers/favorites_providers.dart' show favoriteArticlesProvider, favoriteMagazinesProvider, favoriteNewspapersProvider, favoritesProvider;
import '../../providers/theme_providers.dart' show borderColorProvider, currentThemeModeProvider, glassColorProvider, navIconColorProvider;
import '../../widgets/app_drawer.dart';
import '../../widgets/glass_icon_button.dart';
import '../common/app_bar.dart';
import '../home/widgets/news_card.dart' show NewsCard;
import '../magazine/widgets/magazine_card.dart';
import '../../../domain/entities/news_article.dart';
import '../../../core/app_paths.dart';
import '../../../../infrastructure/services/interstitial_ad_service.dart';
import '../../widgets/unlock_article_dialog.dart';

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  String _filter = 'All';
  String _timeFilter = 'All';
  @override
  void initState() {
    super.initState();
  }

  List<Map<String, dynamic>> _applyTimeFilter(List<Map<String, dynamic>> list) {
    if (_timeFilter == 'All') return list;
    final DateTime now = DateTime.now();
    return list.where((Map<String, dynamic> item) {
      final DateTime savedAt =
          DateTime.tryParse(item['savedAt'] ?? '') ?? DateTime(2000);
      final Duration diff = now.difference(savedAt);
      switch (_timeFilter) {
        case 'Today':
          return diff.inDays == 0;
        case 'This Week':
          return diff.inDays <= 7;
        case 'Older':
          return diff.inDays > 7;
        default:
          return true;
      }
    }).toList();
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
    final bool isDark = mode == AppThemeMode.dark;
    final List<Color> colors = AppGradients.getBackgroundGradient(mode);
    final Color start = colors[0], end = colors[1];

    final favoriteArticles = ref.watch(favoriteArticlesProvider);
    final favoriteMagazines = ref.watch(favoriteMagazinesProvider);
    final favoriteNewspapers = ref.watch(favoriteNewspapersProvider);

    final List<Map<String, dynamic>> allItems = <Map<String, dynamic>>[
      ...favoriteArticles.map((NewsArticle a) => a.toMap()),
      ...favoriteMagazines,
      ...favoriteNewspapers,
    ];

    List<Map<String, dynamic>> filtered = allItems;

    if (_filter != 'All') {
      if (_filter == loc.articles) {
        filtered = favoriteArticles.map((NewsArticle a) => a.toMap()).toList();
      } else if (_filter == loc.magazines) {
        filtered = favoriteMagazines;
      } else if (_filter == loc.newspapers) {
        filtered = favoriteNewspapers;
      }
    }

    filtered = _applyTimeFilter(filtered);

    final glassColor = ref.watch(glassColorProvider);
    final borderColor = ref.watch(borderColorProvider);
    final navIconColor = ref.watch(navIconColorProvider);

    return WillPopScope(
      onWillPop: () async {
        context.go('/home');
        return false;
      },
      child: Scaffold(
        extendBodyBehindAppBar: true, 
        drawer: const AppDrawer(),
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          centerTitle: true,
          toolbarHeight: 64,
          title: AppBarTitle(loc.favorites),
          backgroundColor: Colors.transparent,
          elevation: 0,
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
        ),
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // 1. Gradient Background
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      start.withOpacity(0.85),
                      end.withOpacity(0.85),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
            // 2. Content
            SafeArea(
              child: Column(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
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
                                    value: _filter,
                                    isExpanded: true,
                                    dropdownColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                                    icon: Icon(Icons.expand_more, color: textColor.withOpacity(0.5)),
                                    style: TextStyle(
                                      color: textColor,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      fontFamily: AppTypography.fontFamily,
                                    ),
                                    items: categories
                                        .map(
                                          (String cat) => DropdownMenuItem(
                                            value: cat,
                                            child: Text(cat),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (String? val) => setState(() => _filter = val!),
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
                                  value: _timeFilter,
                                  dropdownColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                                  icon: Icon(Icons.calendar_month, color: textColor.withOpacity(0.5), size: 18),
                                  style: TextStyle(
                                    color: textColor,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    fontFamily: AppTypography.fontFamily,
                                  ),
                                  items: filters
                                      .map(
                                        (String f) => DropdownMenuItem(
                                          value: f,
                                          child: Text(f),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (String? val) => setState(() => _timeFilter = val!),
                                ),
                              ),
                            ],
                          ),
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
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                return _buildCard(context, filtered[index], mode == AppThemeMode.dark);
                              },
                            ),
                    ),
                  ),
                ],
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
            Icon(Icons.favorite_border, size: 64, color: color.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(
              loc.noFavoritesYet,
              style: TextStyle(
                color: color.withOpacity(0.7),
                fontSize: 16,
                fontFamily: AppTypography.fontFamily,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(
    BuildContext context,
    Map<String, dynamic> item,
     bool isDark,
  ) {
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
                  onPressed:
                      () => Share.share('${article.title}\n${article.url}'),
                ),
              ],
            ),
          ],
        );
    } else if (item.containsKey('tags')) {
      content = MagazineCard(
          magazine: item,
          isFavorite: true,
          onFavoriteToggle: () async {
            await ref.read(favoritesProvider.notifier).toggleMagazine(item);
          },
          highlight: false,
        );
    } else {
      content = ListTile(
          leading: const Icon(Icons.public),
          title: Text(item['name'] ?? 'Unknown', style: const TextStyle(fontFamily: AppTypography.fontFamily, fontWeight: FontWeight.w600)),
          subtitle: Text(subtitle, style: const TextStyle(fontFamily: AppTypography.fontFamily)),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              await ref
                  .read(favoritesProvider.notifier)
                  .toggleNewspaper(item);
            },
          ),
        );
    }

    final glassColor = ref.watch(glassColorProvider);
    final borderColor = ref.watch(borderColorProvider);

    // Wrap in Glass Container
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: glassColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: content, 
    );
  }

  Widget _glassContainer(BuildContext context, {required Widget child, required bool isDark}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}
