import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/offline_handler.dart';
import '../../core/theme.dart';
import '../../presentation/providers/theme_providers.dart';
import '../../presentation/providers/news_providers.dart';
import '../../presentation/providers/subscription_providers.dart';
import '../../data/models/news_article.dart';
import '../../data/services/hive_service.dart';
import '../../data/services/interstitial_ad_service.dart';
import '../../data/services/rewarded_ad_service.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/unlock_article_dialog.dart';
import '../home/widgets/news_card.dart';
import '../home/widgets/shimmer_loading.dart';
import '../home/widgets/professional_header.dart';
import '../home/widgets/breaking_news_ticker.dart';
import '/l10n/app_localizations.dart';
import '../../widgets/animated_theme_container.dart';
import '../../presentation/providers/tab_providers.dart';
import '../../presentation/providers/app_settings_providers.dart';
import '../../presentation/providers/language_providers.dart';
// BUILD_FIXES: Design tokens and error display
import '../../core/theme/tokens.dart';
import '../../core/widgets/error_display.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static const String _latestKey = 'latest';

  // Track article clicks for unlock prompts
  int _articleClickCount = 0;

  bool _isOffline = false;

  // Scroll controller to reset position
  final ScrollController _scrollController = ScrollController();
  final bool _firstBuild = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _initConnectivity();

    // Listen to language changes using Riverpod
    ref.listenManual(currentLocaleProvider, (previous, next) {
      if (previous != null && previous != next) {
        debugPrint(
          '🌐 Language changed from ${previous.languageCode} to ${next.languageCode} - reloading news',
        );
        _loadNews(force: true);
      }
    });

    // Initial load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        HiveService.init(<String>[_latestKey]).then((_) {
          _loadNews();
          _setupAutoRefresh();
        });
      }
    });
  }

  void _onTabChanged() {
    if (!mounted) return;
    final int currentTab = ref.watch(currentTabIndexProvider);
    // This is tab 0 (Home)
    if (currentTab == 0 && _scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  void _initConnectivity() async {
    _isOffline = await OfflineHandler.isOffline();
    OfflineHandler().onConnectivityChanged.listen((bool offline) {
      if (mounted) setState(() => _isOffline = offline);
      if (!offline) {
        _loadNews(force: true);
      }
    });
  }

  Future<void> _loadNews({bool force = false}) async {
    if (!mounted) return;
    final Locale locale = ref.read(currentLocaleProvider);
    debugPrint('📰 Loading news for locale: ${locale.languageCode}');
    // Use Riverpod news provider
    await ref
        .read(newsProvider.notifier)
        .loadNews(_latestKey, locale, force: force);
  }

  void _setupAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(minutes: 30), (timer) {
      if (mounted) {
        _loadNews();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    // Tab listener managed by Riverpod
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations loc = AppLocalizations.of(context)!;
    // Use Riverpod theme provider
    final themeMode = ref.watch(currentThemeModeProvider);
    // Use Riverpod news provider
    final newsState = ref.watch(newsProvider);
    final ThemeData theme = Theme.of(context);

    // Use getBackgroundGradient for correct Dark Mode colors (Black)
    final List<Color> colors = AppGradients.getBackgroundGradient(themeMode);
    final Color start = colors[0];
    final Color end = colors[1];

    final List<NewsArticle> list = newsState.getArticles(_latestKey);
    final bool isLoading = newsState.isLoading(_latestKey);
    final String? error = newsState.getError(_latestKey);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      drawer: const AppDrawer(),

      // APP BAR
      // APP BAR extends behind for translucency, but we use Theme colors
      appBar: AppBar(
        elevation: theme.appBarTheme.elevation,
        centerTitle: true,
        title: Text(loc.bdNewsreader, style: theme.appBarTheme.titleTextStyle),
        backgroundColor: theme.appBarTheme.backgroundColor,
        iconTheme: theme.appBarTheme.iconTheme,
        actionsIconTheme: theme.appBarTheme.actionsIconTheme,
      ),

      // BODY
      body: Stack(
        children: <Widget>[
          // BACKGROUND
          AnimatedThemeContainer(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[start.withOpacity(0.65), end.withOpacity(0.78)],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: <Widget>[
                // 🚨 BREAKING NEWS TICKER
                if (list.isNotEmpty)
                  BreakingNewsTicker(articles: list.take(5).toList()),

                // MAIN CONTENT
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () => _loadNews(force: true),
                    color: Theme.of(context).colorScheme.primary,
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    strokeWidth: 3.0,
                    // Main scrollable content
                    child: CustomScrollView(
                      controller:
                          _scrollController, // Attach controller for manual reset
                      key: const PageStorageKey('home_scroll'),
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: <Widget>[
                        // OFFLINE BANNER
                        if (_isOffline)
                          SliverToBoxAdapter(
                            child: AnimatedThemeContainer(
                              color: Colors.red,
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              child: Text(
                                loc.offlineShowingCached,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ),

                        // ERROR BANNER
                        if (error != null && !_isOffline)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                              child: ErrorDisplay(
                                message: error!,
                                icon: Icons.warning_amber,
                                iconColor: Colors.orange.shade700,
                              ),
                            ),
                          ),

                        const SliverToBoxAdapter(child: SizedBox(height: 10)),

                        // PROFESSIONAL HEADER
                        SliverToBoxAdapter(
                          child: ProfessionalHeader(articleCount: list.length),
                        ),

                        // FEED
                        isLoading && list.isEmpty
                            ? const SliverFillRemaining(child: ShimmerLoading())
                            : list.isEmpty
                            ? SliverFillRemaining(
                               child: error != null
                                  ? ErrorDisplay.loadFailed(
                                      what: 'articles',
                                      onRetry: () => _loadNews(force: true),
                                    )
                                  : ErrorDisplay.empty(what: 'articles'),
                            )
                            : SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (
                                  BuildContext context,
                                  int i,
                                ) => RepaintBoundary(
                                  child: NewsCard(
                                    key: ValueKey(list[i].url), // Cache by URL
                                    article: list[i],
                                    onTap: () async {
                                      final NewsArticle article = list[i];
                                      final GoRouter router = GoRouter.of(
                                        context,
                                      );
                                      // ignore: use_build_context_synchronously
                                      final bool isPremium = ref.watch(
                                        isPremiumProvider,
                                      );

                                      if (!isPremium) {
                                        _articleClickCount++;
                                      }

                                      await InterstitialAdService()
                                          .onArticleViewed();

                                      if (!isPremium &&
                                          _articleClickCount % 2 == 0) {
                                        if (!RewardedAdService()
                                            .isArticleUnlocked(article.url)) {
                                          if (!mounted) {
                                            return; // ✅ Check before async dialog
                                          }
                                          final bool unlocked =
                                              await showUnlockDialog(
                                                context,
                                                article.url,
                                                article.title,
                                              );

                                          if (!mounted) {
                                            return; // ✅ Check after async dialog
                                          }
                                          if (!unlocked) return;
                                        }
                                      }

                                      if (!mounted) {
                                        return; // ✅ Final check before navigation
                                      }
                                      router.push(
                                        '/webview',
                                        extra: <String, dynamic>{
                                          'url': article.url,
                                          'title': article.title,
                                          'description': article.description,
                                          'imageUrl': article.imageUrl,
                                          'source': article.source,
                                          'publishedAt':
                                              article.publishedAt
                                                  .toIso8601String(),
                                          'dataSaver': ref.read(
                                            dataSaverProvider,
                                          ),
                                        },
                                      );
                                    },
                                  ),
                                ),
                                childCount: list.length,
                              ),
                            ),

                        const SliverToBoxAdapter(child: SizedBox(height: 80)),
                      ],
                    ),
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
