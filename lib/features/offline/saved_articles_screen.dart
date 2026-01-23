import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../presentation/providers/saved_articles_provider.dart';
import '../home/widgets/news_card.dart';
import '../../core/theme_provider.dart'; // Keep for AppThemeMode enum
import '../../presentation/providers/theme_providers.dart'; // Add for provider

class SavedArticlesScreen extends ConsumerWidget {
  const SavedArticlesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedState = ref.watch(savedArticlesProvider);
    final themeMode = ref.watch(currentThemeModeProvider);
    final isDark = themeMode == AppThemeMode.dark;

    // Calculate storage usage
    final double mbUsed =
        ref.read(savedArticlesProvider.notifier).storageUsageMB;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Articles'),
        centerTitle: true,
        actions: [
          if (savedState.articles.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'Clear All',
              onPressed: () {
                showDialog(
                  context: context,
                  builder:
                      (ctx) => AlertDialog(
                        title: const Text('Clear All Downloads'),
                        content: const Text(
                          'Are you sure you want to remove all saved articles?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () async {
                              Navigator.pop(ctx);
                              await ref
                                  .read(savedArticlesProvider.notifier)
                                  .clearAll();
                            },
                            child: const Text(
                              'Clear',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                );
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Storage Info Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withOpacity(0.5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${savedState.articles.length} saved articles',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  '${mbUsed.toStringAsFixed(1)} MB used',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          Expanded(
            child:
                savedState.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : savedState.articles.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.cloud_off,
                            size: 64,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.4),
                          ),
                          const SizedBox(height: 16),
                          const Text('No saved articles'),
                          const SizedBox(height: 8),
                          Text(
                            'Tap the download icon on any news\narticle to read it offline.',
                            textAlign: TextAlign.center,
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      itemCount: savedState.articles.length,
                      padding: const EdgeInsets.only(top: 8, bottom: 20),
                      itemBuilder: (context, index) {
                        final article = savedState.articles[index];
                        return Dismissible(
                          key: Key(article.url),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            color: Colors.red,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            child: const Icon(
                              Icons.delete,
                              color: Colors.white,
                            ),
                          ),
                          onDismissed: (_) {
                            ref
                                .read(savedArticlesProvider.notifier)
                                .removeArticle(article.url);
                          },
                          child: NewsCard(article: article, highlight: false),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
