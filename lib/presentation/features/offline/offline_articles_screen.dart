import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:bdnewsreader/l10n/generated/app_localizations.dart';

import '../../../core/enums/theme_mode.dart';
import "../../../domain/entities/news_article.dart";
import '../../../infrastructure/persistence/offline_service.dart' show OfflineService;
import '../../providers/theme_providers.dart' show currentThemeModeProvider;
import 'package:go_router/go_router.dart';
import '../../../core/app_paths.dart';
import '../common/app_bar.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/glass_icon_button.dart';

class OfflineArticlesScreen extends ConsumerStatefulWidget {
  const OfflineArticlesScreen({super.key});

  @override
  ConsumerState<OfflineArticlesScreen> createState() =>
      _OfflineArticlesScreenState();
}

class _OfflineArticlesScreenState extends ConsumerState<OfflineArticlesScreen> {
  List<NewsArticle> _articles = [];
  bool _loading = true;
  int _storageUsed = 0;

  @override
  void initState() {
    super.initState();
    _loadArticles();
  }

  Future<void> _loadArticles() async {
    setState(() => _loading = true);
    final articles = await OfflineService.getDownloadedArticles();
    final storage = await OfflineService.getStorageUsed();
    setState(() {
      _articles = articles;
      _storageUsed = storage;
      _loading = false;
    });
  }

  Future<void> _deleteArticle(NewsArticle article) async {
    final loc = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(loc.deleteArticle),
            content: Text(loc.deleteOfflineArticleHint),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(loc.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  loc.delete,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      await OfflineService.deleteArticle(article.url);
      _loadArticles();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).articleDeleted)));
      }
    }
  }

  Future<void> _clearAll() async {
    final loc = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(loc.clearAllDownloads),
            content: Text(loc.confirmClearDownloads),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(loc.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  loc.clearAllLabel,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      await OfflineService.clearAll();
      _loadArticles();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).allDownloadsCleared)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final themeMode = ref.watch(currentThemeModeProvider);
    final isDark = themeMode != AppThemeMode.light;

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        centerTitle: true,
        toolbarHeight: 64,
        title: AppBarTitle(AppLocalizations.of(context).downloaded),
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
        actions: [
          if (_articles.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: _clearAll,
              tooltip: loc.clearAll,
            ),
        ],
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _articles.isEmpty
              ? _buildEmptyState()
              : Column(
                children: [
                
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: isDark ? Colors.grey[900] : Colors.grey[100],
                    child: Row(
                      children: [
                        const Icon(Icons.download, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '${loc.articlesCountLabel(_articles.length)} • ${OfflineService.formatBytes(_storageUsed)}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),

                 
                  Expanded(
                    child: ListView.builder(
                      itemCount: _articles.length,
                      padding: const EdgeInsets.all(8),
                      itemBuilder: (context, index) {
                        final article = _articles[index];
                        return _buildArticleCard(article);
                      },
                    ),
                  ),
                ],
              ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off, size: 80, color: Colors.grey[400]),
          Text(
            AppLocalizations.of(context).noSavedArticles,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context).downloadToReadOffline,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildArticleCard(NewsArticle article) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: InkWell(
        onTap: () {
          context.push(AppPaths.newsDetail, extra: article);
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
         
              if (article.imageUrl != null && article.imageUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: article.imageUrl!,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorWidget:
                        (context, url, error) => Container(
                          width: 80,
                          height: 80,
                          color: Colors.grey[300],
                          child: const Icon(Icons.image),
                        ),
                  ),
                ),

              const SizedBox(width: 12),

          
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (article.source.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        article.source,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.offline_pin, size: 16, color: Colors.green),
                        const SizedBox(width: 4),
                        Text(
                          AppLocalizations.of(context).offline,
                          style: const TextStyle(fontSize: 12, color: Colors.green),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

         
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _deleteArticle(article),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
