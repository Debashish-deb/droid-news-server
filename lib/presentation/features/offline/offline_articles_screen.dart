import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../l10n/generated/app_localizations.dart';

import '../../../core/enums/theme_mode.dart';
import '../../../core/theme/theme.dart';
import "../../../domain/entities/news_article.dart";
import '../../../infrastructure/persistence/services/offline_service.dart'
    show OfflineService;
import '../../../core/navigation/navigation_helper.dart';
import '../../providers/theme_providers.dart' show currentThemeModeProvider;
import '../../widgets/app_drawer.dart';
import '../../widgets/premium_screen_header.dart';

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
      builder: (context) => AlertDialog(
        title: Text(loc.deleteArticle),
        content: Text(loc.deleteOfflineArticleHint),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(loc.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(loc.delete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await OfflineService.deleteArticle(article.url);
      _loadArticles();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).articleDeleted)),
        );
      }
    }
  }

  Future<void> _clearAll() async {
    final loc = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await OfflineService.clearAll();
      _loadArticles();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).allDownloadsCleared),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final themeMode = ref.watch(currentThemeModeProvider);
    final theme = Theme.of(context);
    final appColors = theme.extension<AppColorsExtension>()!;
    final isDark =
        themeMode == AppThemeMode.bangladesh ||
        theme.brightness == Brightness.dark;
    final backgroundGradient = AppGradients.getBackgroundGradient(themeMode);

    return Scaffold(
      backgroundColor: Colors.transparent,
      drawer: const AppDrawer(),
      appBar: PremiumScreenHeader(
        title: AppLocalizations.of(context).downloaded,
        leading: PremiumHeaderLeading.menu,
        actions: [
          if (_articles.isNotEmpty)
            PremiumHeaderIconButton(
              icon: Icons.delete_sweep_rounded,
              onPressed: _clearAll,
              tooltip: loc.clearAll,
            ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  backgroundGradient[0].withValues(alpha: 0.95),
                  backgroundGradient[1].withValues(alpha: 0.95),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.4, -1.0),
                radius: 1.35,
                colors: [
                  theme.colorScheme.primary.withValues(
                    alpha: theme.brightness == Brightness.dark ? 0.08 : 0.05,
                  ),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _articles.isEmpty
              ? _buildEmptyState(appColors)
              : Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: appColors.card.withValues(
                          alpha: isDark ? 0.90 : 0.96,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: appColors.cardBorder.withValues(alpha: 0.7),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.download_rounded,
                            size: 20,
                            color: appColors.proBlue,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${loc.articlesCountLabel(_articles.length)} • ${OfflineService.formatBytes(_storageUsed)}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: appColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _articles.length,
                        padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                        itemBuilder: (context, index) {
                          final article = _articles[index];
                          return _buildArticleCard(article, appColors);
                        },
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(AppColorsExtension appColors) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off, size: 80, color: appColors.textHint),
          Text(
            AppLocalizations.of(context).noSavedArticles,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: appColors.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context).downloadToReadOffline,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: appColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildArticleCard(NewsArticle article, AppColorsExtension appColors) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      color: appColors.card.withValues(
        alpha: Theme.of(context).brightness == Brightness.dark ? 0.92 : 0.98,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => NavigationHelper.openNewsDetail<void>(context, article),
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
                    errorWidget: (context, url, error) => Container(
                      width: 80,
                      height: 80,
                      color: appColors.cardBorder.withValues(alpha: 0.35),
                      child: Icon(Icons.image, color: appColors.textHint),
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
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: appColors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.offline_pin,
                          size: 16,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          AppLocalizations.of(context).offline,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _deleteArticle(article),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
