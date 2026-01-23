import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/theme_provider.dart' show AppThemeMode;
import '../../data/models/news_article.dart';
import '../../core/services/offline_service.dart';
import '../../presentation/providers/theme_providers.dart';
import '../news_detail/news_detail_screen.dart';

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
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Article?'),
            content: const Text(
              'This will remove the downloaded article and free up storage.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
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
        ).showSnackBar(const SnackBar(content: Text('Article deleted')));
      }
    }
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Clear All Downloads?'),
            content: const Text('This will delete all downloaded articles.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Clear All',
                  style: TextStyle(color: Colors.red),
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
        ).showSnackBar(const SnackBar(content: Text('All downloads cleared')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(currentThemeModeProvider);
    final isDark = themeMode != AppThemeMode.light;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Downloaded Articles'),
        actions: [
          if (_articles.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: _clearAll,
              tooltip: 'Clear all',
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
                  // Storage info
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: isDark ? Colors.grey[900] : Colors.grey[100],
                    child: Row(
                      children: [
                        const Icon(Icons.download, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '${_articles.length} articles • ${OfflineService.formatBytes(_storageUsed)}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),

                  // Articles list
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
          const SizedBox(height: 16),
          Text(
            'No Downloaded Articles',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Download articles to read offline',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
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
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NewsDetailScreen(news: article),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image
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

              // Content
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
                    const Row(
                      children: [
                        Icon(Icons.offline_pin, size: 16, color: Colors.green),
                        SizedBox(width: 4),
                        Text(
                          'Offline',
                          style: TextStyle(fontSize: 12, color: Colors.green),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Delete button
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
