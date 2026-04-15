import 'package:flutter/material.dart';
import '../../../core/di/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui' show ImageFilter;
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/navigation/navigation_helper.dart';
import '../../../core/theme/theme.dart';
import '../../../core/navigation/url_safety_policy.dart';
import '../../../core/config/performance_config.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../providers/theme_providers.dart';
import '../../providers/premium_providers.dart';
import '../../widgets/platform_surface_treatment.dart';
import '../../providers/saved_articles_provider.dart';
import '../home/widgets/news_card.dart';
import '../common/webview_args.dart';

import '../../widgets/app_drawer.dart';
import '../../widgets/premium_screen_header.dart';

class SavedArticlesScreen extends ConsumerWidget {
  const SavedArticlesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedState = ref.watch(savedArticlesProvider);
    final savedNotifier = ref.watch(savedArticlesProvider.notifier);
    final isPremium = ref.watch(isPremiumStateProvider);
    final themeMode = ref.watch(currentThemeModeProvider);
    final theme = Theme.of(context);
    final appColors = theme.extension<AppColorsExtension>()!;
    final isDark = theme.brightness == Brightness.dark;
    final perf = PerformanceConfig.of(context);
    final preferMaterialChrome = preferAndroidMaterialSurfaceChrome(context);
    final bool lowEffects =
        perf.reduceEffects || perf.lowPowerMode || perf.isLowEndDevice;
    final double mbUsed = savedNotifier.storageUsageMB;
    final int staleCount = savedNotifier.staleArticlesCount;

    final List<Color> gradient = AppGradients.getBackgroundGradient(themeMode);
    final Color start = gradient[0];
    final Color end = gradient[1];

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

    return Scaffold(
      backgroundColor: Colors.transparent,
      drawer: const AppDrawer(),
      appBar: PremiumScreenHeader(
        title: AppLocalizations.of(context).offlineArticles,
        leading: PremiumHeaderLeading.menu,
        actions: [
          if (isPremium && savedState.articles.isNotEmpty)
            PremiumHeaderIconButton(
              icon: Icons.delete_sweep_rounded,
              tooltip: 'Clear All',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(
                      AppLocalizations.of(context).clearAllDownloads,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
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
                        child: const Text('Clear'),
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
                    start.withValues(alpha: 0.95),
                    end.withValues(alpha: 0.95),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.35, -0.95),
                  radius: 1.35,
                  colors: [
                    appColors.proBlue.withValues(alpha: isDark ? 0.08 : 0.05),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // 2. Content
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: cheapComposite
                        ? _buildStatsPanel(
                            isDark: isDark,
                            navIconColor: navIconColor,
                            savedCount: savedState.articles.length,
                            mbUsed: mbUsed,
                            glassColor: glassColor,
                            borderColor: borderColor,
                          )
                        : BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                            child: _buildStatsPanel(
                              isDark: isDark,
                              navIconColor: navIconColor,
                              savedCount: savedState.articles.length,
                              mbUsed: mbUsed,
                              glassColor: glassColor,
                              borderColor: borderColor,
                            ),
                          ),
                  ),
                ),

                if (staleCount > 0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(
                          alpha: isDark ? 0.18 : 0.12,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.schedule_rounded,
                            color: Colors.orange,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '$staleCount saved article${staleCount == 1 ? '' : 's'} older than 3 months. Review and delete outdated copies.',
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                fontFamily: AppTypography.fontFamily,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                Expanded(
                  child: !isPremium
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.workspace_premium_rounded,
                                  size: 64,
                                  color: isDark
                                      ? Colors.white54
                                      : Colors.black54,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Offline saving is for Pro only.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: AppTypography.fontFamily,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Free accounts can read every article, but offline downloads require Pro.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black54,
                                    fontSize: 14,
                                    fontFamily: AppTypography.fontFamily,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                FilledButton.icon(
                                  onPressed: () {
                                    NavigationHelper.openSubscriptionManagement<
                                      void
                                    >(context);
                                  },
                                  icon: const Icon(Icons.bolt_rounded),
                                  label: Text(
                                    AppLocalizations.of(context).goPremium,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : savedState.isLoading
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
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black54,
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
                                  color: isDark
                                      ? Colors.white54
                                      : Colors.black45,
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
                                boxShadow: lowEffects
                                    ? const <BoxShadow>[]
                                    : [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.1,
                                          ),
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
                                    color: theme.colorScheme.primary.withValues(
                                      alpha: 0.8,
                                    ),
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
                                      ref
                                          .read(interstitialAdServiceProvider)
                                          .onArticleViewed();

                                      final decision = UrlSafetyPolicy.evaluate(
                                        article.url,
                                      );
                                      if (decision.disposition ==
                                          UrlSafetyDisposition.reject) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              AppLocalizations.of(
                                                context,
                                              ).invalidArticleData,
                                            ),
                                          ),
                                        );
                                        return;
                                      }
                                      if (decision.disposition ==
                                          UrlSafetyDisposition.openExternal) {
                                        final uri = decision.uri;
                                        if (uri != null) {
                                          launchUrl(
                                            uri,
                                            mode:
                                                LaunchMode.externalApplication,
                                          );
                                        }
                                        return;
                                      }
                                      final safeUri = decision.uri;
                                      if (safeUri == null) {
                                        return;
                                      }

                                      NavigationHelper.openWebViewArgs<void>(
                                        context,
                                        WebViewArgs(
                                          url: safeUri,
                                          title: article.title,
                                          origin: WebViewOrigin.savedArticle,
                                          articles: savedState.articles,
                                          initialIndex: index,
                                        ),
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

  Widget _buildStatsPanel({
    required bool isDark,
    required Color navIconColor,
    required int savedCount,
    required double mbUsed,
    required Color glassColor,
    required Color borderColor,
  }) {
    return Container(
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
                '$savedCount saved',
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
    );
  }
}
