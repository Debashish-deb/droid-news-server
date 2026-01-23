import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme.dart';
import '../../core/theme_provider.dart';
import '../../core/services/favorites_providers.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/app_drawer.dart';
import '../common/animated_background.dart';
import '../home/widgets/news_card.dart' show NewsCard;
import '../magazine/widgets/magazine_card.dart';
// import '../news/widgets/news_card.dart';
import '../../data/models/news_article.dart';
import '../../presentation/providers/theme_providers.dart';

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

  @override
  Widget build(BuildContext context) {
    final AppLocalizations loc = AppLocalizations.of(context)!;

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
    // Use getBackgroundGradient for correct Dark Mode colors
    final List<Color> colors = AppGradients.getBackgroundGradient(mode);
    final Color start = colors[0], end = colors[1];

    // Use Riverpod for favorites
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

    return WillPopScope(
      onWillPop: () async {
        context.go('/home');
        return false;
      },
      child: Scaffold(
        drawer: const AppDrawer(),
        appBar: AppBar(
          title: Text(loc.favorites, style: theme.appBarTheme.titleTextStyle),
          centerTitle: true,
          backgroundColor: theme.appBarTheme.backgroundColor,
          elevation: theme.appBarTheme.elevation,
          iconTheme: theme.appBarTheme.iconTheme,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/home'),
          ),
        ),
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            _backgroundGradient(start, end),
            AnimatedBackground(
              child: Column(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: _glassSection(
                      context,
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: DropdownButton<String>(
                              value: _filter,
                              isExpanded: true,
                              dropdownColor: theme.cardColor.withOpacity(0.9),
                              iconEnabledColor: textColor,
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.w600,
                              ),
                              underline: const SizedBox(),
                              items:
                                  categories
                                      .map(
                                        (String cat) => DropdownMenuItem(
                                          value: cat,
                                          child: Text(
                                            cat,
                                            style: TextStyle(color: textColor),
                                          ),
                                        ),
                                      )
                                      .toList(),
                              onChanged:
                                  (String? val) =>
                                      setState(() => _filter = val!),
                            ),
                          ),
                          const SizedBox(width: 12),
                          DropdownButton<String>(
                            value: _timeFilter,
                            dropdownColor: theme.cardColor.withOpacity(0.9),
                            iconEnabledColor: textColor,
                            style: TextStyle(color: textColor),
                            underline: const SizedBox(),
                            items:
                                filters
                                    .map(
                                      (String f) => DropdownMenuItem(
                                        value: f,
                                        child: Text(
                                          f,
                                          style: TextStyle(color: textColor),
                                        ),
                                      ),
                                    )
                                    .toList(),
                            onChanged:
                                (String? val) =>
                                    setState(() => _timeFilter = val!),
                          ),
                        ],
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
                              padding: const EdgeInsets.all(16),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                return _buildCard(context, filtered[index]);
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
        child: Text(
          loc.noFavoritesYet,
          style: TextStyle(color: color.withOpacity(0.7)),
        ),
      ),
    );
  }

  Widget _buildCard(
    BuildContext context,
    Map<String, dynamic> item,
  ) {
    final DateTime savedAt =
        DateTime.tryParse(item['savedAt'] ?? '') ?? DateTime.now();
    final String subtitle = 'Saved on ${DateFormat.yMMMd().format(savedAt)}';

    if (item.containsKey('title')) {
      final NewsArticle article = NewsArticle.fromMap(item);
      return _glassSection(
        context,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            NewsCard(article: article, highlight: false),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                IconButton(
                  icon: const Icon(Icons.share),
                  onPressed:
                      () => Share.share('${article.title}\n${article.url}'),
                ),
              ],
            ),
          ],
        ),
      );
    } else if (item.containsKey('tags')) {
      return _glassSection(
        context,
        child: MagazineCard(
          magazine: item,
          isFavorite: true,
          onFavoriteToggle: () async {
            await ref.read(favoritesProvider.notifier).toggleMagazine(item);
          },
          highlight: false,
        ),
      );
    } else {
      return _glassSection(
        context,
        child: ListTile(
          leading: const Icon(Icons.public),
          title: Text(item['name'] ?? 'Unknown'),
          subtitle: Text(subtitle),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              await ref
                  .read(favoritesProvider.notifier)
                  .toggleNewspaper(item);
            },
          ),
        ),
      );
    }
  }

  Widget _glassSection(BuildContext context, {required Widget child}) {
    final Color glow = Theme.of(context).colorScheme.primary.withOpacity(0.4);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:
                  Theme.of(context).cardTheme.color ??
                  Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: glow),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: glow,
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _blurredAppBar(BuildContext context, Color start, Color end) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[start.withOpacity(0.85), end.withOpacity(0.85)],
            ),
          ),
        ),
      ),
    );
  }

  Widget _backgroundGradient(Color start, Color end) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[start.withOpacity(0.85), end.withOpacity(0.85)],
        ),
      ),
    );
  }
}
