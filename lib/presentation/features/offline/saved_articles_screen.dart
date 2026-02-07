import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui' show ImageFilter;
import '../../../core/design_tokens.dart';
import '../../../core/theme.dart';
import '../../../core/app_paths.dart';
import '../../../core/enums/theme_mode.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../providers/theme_providers.dart';
import '../../providers/saved_articles_provider.dart';
import '../home/widgets/news_card.dart';

import '../common/app_bar.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/glass_icon_button.dart';
import '../../../../infrastructure/services/interstitial_ad_service.dart';

class SavedArticlesScreen extends ConsumerWidget {
  const SavedArticlesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedState = ref.watch(savedArticlesProvider);
    final themeMode = ref.watch(currentThemeModeProvider);
    final isDark = themeMode == AppThemeMode.dark;
    final double mbUsed = ref.watch(savedArticlesProvider.notifier).storageUsageMB;

    final List<Color> gradient = AppGradients.getBackgroundGradient(themeMode); 
    final Color start = gradient[0];
    final Color end = gradient[1];

    final glassColor = ref.watch(glassColorProvider);
    final borderColor = ref.watch(borderColorProvider);
    final navIconColor = ref.watch(navIconColorProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      drawer: const AppDrawer(),
      appBar: AppBar(
        centerTitle: true,
        toolbarHeight: 64,
        title: AppBarTitle(AppLocalizations.of(context).offlineArticles),
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
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
        actions: [
          if (savedState.articles.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'Clear All',
              color: Colors.redAccent,
              onPressed: () {
                showDialog(
                  context: context,
                  builder:
                      (ctx) => AlertDialog(
                        title: Text(AppLocalizations.of(context).clearAllDownloads, style: const TextStyle(fontWeight: FontWeight.bold)),
                        content: const Text(
                          'Are you sure you want to remove all saved articles?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text(AppLocalizations.of(context).cancel),
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
      body: Stack(
        fit: StackFit.expand,
        children: [
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
                children: [
              
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          decoration: BoxDecoration(
                            color: glassColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: borderColor),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.library_books, size: 20, color: navIconColor),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${savedState.articles.length} saved',
                                    style: TextStyle(
                                      color: isDark ? Colors.white : Colors.black87,
                                      fontFamily: AppTypography.fontFamily,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Icon(Icons.storage_rounded, size: 18, color: navIconColor),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${mbUsed.toStringAsFixed(1)} MB',
                                    style: TextStyle(
                                      color: isDark ? Colors.white : Colors.black87,
                                      fontFamily: AppTypography.fontFamily,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
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
                                    color: isDark ? Colors.white24 : Colors.black26,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    AppLocalizations.of(context).noSavedArticles,
                                    style: TextStyle(
                                      color: isDark ? Colors.white70 : Colors.black54,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: AppTypography.fontFamily,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Tap the download icon on any news\narticle to read it offline.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: isDark ? Colors.white54 : Colors.black45,
                                      fontSize: 14,
                                      fontFamily: AppTypography.fontFamily,
                                    ),
                                  ),
                                ],
                              ),
                            )
                            : ListView.builder(
                              itemCount: savedState.articles.length,
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                              itemBuilder: (context, index) {
                                final article = savedState.articles[index];
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
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: Dismissible(
                                      key: Key(article.url),
                                      direction: DismissDirection.endToStart,
                                      background: Container(
                                        color: Colors.red.withOpacity(0.8),
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
                                      child: NewsCard(
                                        article: article, 
                                        highlight: false,
                                        onTap: () {
                                          // Trigger ad logic (respects premium status internally)
                                          InterstitialAdService().onArticleViewed();

                                          GoRouter.of(context).push(
                                            AppPaths.webview,
                                            extra: <String, dynamic>{
                                              'url': article.url,
                                              'title': article.title,
                                              'articles': savedState.articles,
                                              'index': index,
                                              'description': article.description,
                                              'imageUrl': article.imageUrl,
                                              'source': article.source,
                                              'publishedAt': article.publishedAt.toIso8601String(),
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
