import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/utils/favorites_manager.dart';
import '../../localization/l10n/app_localizations.dart';
import '../../data/models/news_article.dart';
import '../../widgets/app_drawer.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  String _filter = 'All';
  late FavoritesManager favoritesManager;

  @override
  void initState() {
    super.initState();
    favoritesManager = FavoritesManager.instance;
    favoritesManager.loadFavorites().then((_) => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categories = ['All', 'Articles', 'Magazines', 'Newspapers'];

    return WillPopScope(
      onWillPop: () async {
        context.go('/home');
        return false;
      },
      child: Scaffold(
        drawer: const AppDrawer(),
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/home'),
          ),
          title: Text(loc.favorites),
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/theme/image.png',
              fit: BoxFit.cover,
              color: isDark
                  ? Colors.black.withOpacity(0.6)
                  : Colors.white.withOpacity(0.4),
              colorBlendMode: BlendMode.darken,
            ),
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: DropdownButton<String>(
                    value: _filter,
                    isExpanded: true,
                    items: categories
                        .map((cat) => DropdownMenuItem(
                              value: cat,
                              child: Text(cat,
                                  style:
                                      Theme.of(context).textTheme.bodyLarge),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => _filter = value);
                    },
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      await favoritesManager.loadFavorites();
                      setState(() {});
                    },
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if ((_filter == 'All' ||
                                _filter == 'Articles') &&
                            favoritesManager.favoriteArticles.isNotEmpty)
                          _buildSection(
                            context,
                            title: loc.favoriteArticles,
                            items: favoritesManager.favoriteArticles
                                .map((article) =>
                                    _buildArticleCard(context, article))
                                .toList(),
                          ),

                        if ((_filter == 'All' ||
                                _filter == 'Magazines') &&
                            favoritesManager.favoriteMagazines.isNotEmpty)
                          _buildSection(
                            context,
                            title: loc.favoriteMagazines,
                            items: favoritesManager.favoriteMagazines
                                .map((magazine) =>
                                    _buildMagazineCard(context, magazine))
                                .toList(),
                          ),

                        if ((_filter == 'All' ||
                                _filter == 'Newspapers') &&
                            favoritesManager.favoriteNewspapers.isNotEmpty)
                          _buildSection(
                            context,
                            title: loc.favoriteNewspapers,
                            items: favoritesManager.favoriteNewspapers
                                .map((paper) =>
                                    _buildNewspaperCard(context, paper))
                                .toList(),
                          ),

                        if (favoritesManager.favoriteArticles.isEmpty &&
                            favoritesManager.favoriteMagazines.isEmpty &&
                            favoritesManager.favoriteNewspapers.isEmpty)
                          _buildEmptyState(context),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context,
      {required String title, required List<Widget> items}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...items,
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildArticleCard(BuildContext context, NewsArticle article) {
    final loc = AppLocalizations.of(context)!;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 5,
      child: ListTile(
        leading: article.imageUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(article.imageUrl!,
                    width: 50, height: 50, fit: BoxFit.cover),
              )
            : null,
        title: Text(article.title,
            maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle:
            Text(article.source, style: Theme.of(context).textTheme.labelSmall),
        onTap: () => GoRouter.of(context)
            .go('/news-detail', extra: article),
      ),
    );
  }

  Widget _buildMagazineCard(
      BuildContext context, Map<String, dynamic> magazine) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 5,
      child: ListTile(
        leading: magazine['cover'] != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(magazine['cover'],
                    width: 50, height: 50, fit: BoxFit.cover),
              )
            : null,
        title: Text(magazine['name'] ?? '',
            maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(magazine['description'] ?? '',
            maxLines: 2, overflow: TextOverflow.ellipsis),
        onTap: () {},
      ),
    );
  }

  Widget _buildNewspaperCard(
      BuildContext context, Map<String, dynamic> newspaper) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 5,
      child: ListTile(
        leading: newspaper['cover'] != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(newspaper['cover'],
                    width: 50, height: 50, fit: BoxFit.cover),
              )
            : null,
        title: Text(newspaper['name'] ?? '',
            maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(newspaper['description'] ?? '',
            maxLines: 2, overflow: TextOverflow.ellipsis),
        onTap: () {},
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 100),
        child: Text(
          AppLocalizations.of(context)!.noFavoritesYet,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}
