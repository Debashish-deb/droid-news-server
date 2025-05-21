import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme.dart';
import '../../core/theme_provider.dart';
import '../../core/utils/favorites_manager.dart';
import '/l10n/app_localizations.dart';
import '../../widgets/app_drawer.dart';
import '../common/animated_background.dart';
import '../magazine/widgets/magazine_card.dart';
import '../news/widgets/news_card.dart';
import '../../data/models/news_article.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  String _filter = 'All';
  String _timeFilter = 'All';

  late FavoritesManager _favorites;

  @override
  void initState() {
    super.initState();
    _favorites = FavoritesManager.instance;
    _favorites.loadFavorites().then((_) => setState(() {}));
  }

  List<Map<String, dynamic>> _applyTimeFilter(List<Map<String, dynamic>> list) {
    if (_timeFilter == 'All') return list;
    final now = DateTime.now();
    return list.where((item) {
      final savedAt = DateTime.tryParse(item['savedAt'] ?? '') ?? DateTime(2000);
      final diff = now.difference(savedAt);
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
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.white;
    final categories = ['All', loc.articles, loc.magazines, loc.newspapers];
    final filters = ['All', 'Today', 'This Week', 'Older'];

    final mode = context.watch<ThemeProvider>().appThemeMode;
    final colors = AppGradients.getGradientColors(mode);
    final start = colors[0], end = colors[1];

    final allItems = [
      ..._favorites.favoriteArticles.map((a) => a.toMap()),
      ..._favorites.favoriteMagazines,
      ..._favorites.favoriteNewspapers
    ];

    List<Map<String, dynamic>> filtered = allItems;

    if (_filter != 'All') {
      if (_filter == loc.articles) {
        filtered = _favorites.favoriteArticles.map((a) => a.toMap()).toList();
      } else if (_filter == loc.magazines) {
        filtered = _favorites.favoriteMagazines;
      } else if (_filter == loc.newspapers) {
        filtered = _favorites.favoriteNewspapers;
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
          title: Text(loc.favorites, style: const TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/home'),
          ),
          flexibleSpace: _blurredAppBar(context, start, end),
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            _backgroundGradient(start, end),
            AnimatedBackground(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: _glassSection(
                      context,
                      child: Row(
                        children: [
                          Expanded(
                            child: DropdownButton<String>(
                              value: _filter,
                              isExpanded: true,
                              dropdownColor: theme.cardColor.withOpacity(0.9),
                              iconEnabledColor: textColor,
                              style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
                              underline: const SizedBox(),
                              items: categories.map((cat) => DropdownMenuItem(
                                value: cat,
                                child: Text(cat, style: TextStyle(color: textColor)),
                              )).toList(),
                              onChanged: (val) => setState(() => _filter = val!),
                            ),
                          ),
                          const SizedBox(width: 12),
                          DropdownButton<String>(
                            value: _timeFilter,
                            dropdownColor: theme.cardColor.withOpacity(0.9),
                            iconEnabledColor: textColor,
                            style: TextStyle(color: textColor),
                            underline: const SizedBox(),
                            items: filters.map((f) => DropdownMenuItem(
                              value: f,
                              child: Text(f, style: TextStyle(color: textColor)),
                            )).toList(),
                            onChanged: (val) => setState(() => _timeFilter = val!),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () async {
                        await _favorites.loadFavorites();
                        setState(() {});
                      },
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: filtered.isEmpty
                            ? [_buildEmpty(loc, textColor)]
                            : _buildCards(context, filtered),
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
        child: Text(loc.noFavoritesYet, style: TextStyle(color: color.withOpacity(0.7))),
      ),
    );
  }

  List<Widget> _buildCards(BuildContext context, List<Map<String, dynamic>> filtered) {
    return filtered.map((item) {
      final savedAt = DateTime.tryParse(item['savedAt'] ?? '') ?? DateTime.now();
      final subtitle = 'Saved on ${DateFormat.yMMMd().format(savedAt)}';

      if (item.containsKey('title')) {
        final article = NewsArticle.fromMap(item);
        return _glassSection(
          context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NewsCard(
                news: item,
                isFavorite: true,
                onFavoriteToggle: () async {
                  await _favorites.toggleArticleMap(item);
                  setState(() {});
                },
                searchQuery: '',
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.share),
                    onPressed: () => Share.share('${article.title}\n${article.url}'),
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
              await _favorites.toggleMagazine(item);
              setState(() {});
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
                await _favorites.toggleNewspaper(item);
                setState(() {});
              },
            ),
          ),
        );
      }
    }).toList();
  }

  Widget _glassSection(BuildContext context, {required Widget child}) {
    final glow = Theme.of(context).colorScheme.primary.withOpacity(0.4);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: glow, width: 1),
              boxShadow: [BoxShadow(color: glow, blurRadius: 8, offset: const Offset(0, 4))],
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
              colors: [start.withOpacity(0.85), end.withOpacity(0.85)],
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
          colors: [start.withOpacity(0.85), end.withOpacity(0.85)],
        ),
      ),
    );
  }
}
