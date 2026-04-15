import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../presentation/features/home/home_screen.dart' show HomeScreen;
import '../../presentation/features/profile/profile_screen.dart';
import '../../presentation/features/profile/login_screen.dart';
import '../../presentation/features/profile/signup_screen.dart';
import '../../presentation/features/profile/forgot_password_screen.dart';
import '../../presentation/features/onboarding/onboarding_screen.dart';
import '../../presentation/features/splash/bootstrap_screen.dart';

import '../../presentation/features/news/newspaper_screen.dart';
import '../../presentation/features/settings/settings_screen.dart';
import '../../presentation/features/sources/source_management_screen.dart';
import '../../presentation/features/extras/extras_screen.dart';
import '../../presentation/features/history/history_widget.dart';

import '../../presentation/features/favorites/favorites_screen.dart';
import '../../presentation/features/about/about_screen.dart';
import '../../presentation/features/help/help_screen.dart';
import '../../presentation/features/search/search_screen.dart';
import '../../presentation/features/offline/saved_articles_screen.dart';
import '../../presentation/features/quiz/daily_quiz_widget.dart';

import '../../presentation/features/common/webview_screen.dart';
import '../../presentation/features/common/news_detail_args.dart';
import '../../presentation/features/common/webview_args.dart';
import '../../presentation/features/security/security_lockout_screen.dart';
import '../../presentation/features/magazine/magazine_screen.dart';

import '../../presentation/features/subscription/subscription_management_screen.dart';
import '../../domain/entities/news_article.dart';
import '../../presentation/features/settings/privacy_policy_screen.dart';
import '../../presentation/features/tts/ui/full_audio_player.dart';
import '../../tools/main_navigation_screen.dart';

import 'app_paths.dart';
import 'url_safety_policy.dart';
import '../../l10n/generated/app_localizations.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

GoRouter createRouter({String? initialLocation}) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: initialLocation ?? AppPaths.splash,
    routes: [
      GoRoute(
        path: AppPaths.splash,
        pageBuilder: (context, state) =>
            _buildPage(state, const BootstrapScreen()),
      ),
      GoRoute(
        path: AppPaths.onboarding,
        pageBuilder: (context, state) =>
            _buildPage(state, const OnboardingScreen()),
      ),
      GoRoute(
        path: AppPaths.login,
        pageBuilder: (context, state) => _buildPage(state, const LoginScreen()),
      ),
      GoRoute(
        path: AppPaths.signup,
        pageBuilder: (context, state) =>
            _buildPage(state, const SignupScreen()),
      ),
      GoRoute(
        path: AppPaths.forgotPassword,
        pageBuilder: (context, state) =>
            _buildPage(state, const ForgotPasswordScreen()),
      ),

      StatefulShellRoute(
        builder: (context, state, navigationShell) {
          return MainNavigationScreen(
            key: const ValueKey('main_navigation_shell'),
            navigationShell: navigationShell,
          );
        },
        navigatorContainerBuilder:
            (context, navigationShell, children) =>
                LazyStatefulBranchContainer(
                  currentIndex: navigationShell.currentIndex,
                  children: children,
                ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppPaths.home,
                pageBuilder: (context, state) =>
                    _buildPage(state, const HomeScreen()),
                routes: [
                  GoRoute(
                    path: 'extras',
                    pageBuilder: (context, state) =>
                        _buildPage(state, const ExtrasScreen()),
                    routes: [
                      GoRoute(
                        path: 'offline',
                        pageBuilder: (context, state) =>
                            _buildPage(state, const SavedArticlesScreen()),
                      ),
                      GoRoute(
                        path: 'history',
                        pageBuilder: (context, state) =>
                            _buildPage(state, const HistoryWidget()),
                      ),
                      GoRoute(
                        path: 'quiz',
                        pageBuilder: (context, state) =>
                            _buildPage(state, const DailyQuizWidget()),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'favorites',
                    pageBuilder: (context, state) =>
                        _buildPage(state, const FavoritesScreen()),
                  ),
                  GoRoute(
                    path: 'about',
                    pageBuilder: (context, state) =>
                        _buildPage(state, const AboutScreen()),
                  ),
                  GoRoute(
                    path: 'help',
                    pageBuilder: (context, state) =>
                        _buildPage(state, const HelpScreen()),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppPaths.newspaper,
                pageBuilder: (context, state) =>
                    _buildPage(state, const NewspaperScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppPaths.search,
                pageBuilder: (context, state) =>
                    _buildPage(state, const SearchScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppPaths.magazine,
                pageBuilder: (context, state) =>
                    _buildPage(state, const MagazineScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppPaths.settings,
                pageBuilder: (context, state) =>
                    _buildPage(state, const SettingsScreen()),
                routes: [
                  GoRoute(
                    path: 'manage-sources',
                    pageBuilder: (context, state) =>
                        _buildPage(state, const SourceManagementScreen()),
                  ),
                  GoRoute(
                    path: 'privacy',
                    pageBuilder: (context, state) =>
                        _buildPage(state, const PrivacyPolicyScreen()),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppPaths.savedArticles,
        redirect: (_, _) => AppPaths.offline,
      ),

      GoRoute(
        path: '/deeplink/article',
        pageBuilder: (context, state) {
          final url = state.uri.queryParameters['url'];
          final title = state.uri.queryParameters['title'] ?? 'News';

          if (url == null) {
            return _buildPage(state, const HomeScreen());
          }

          return _buildWebViewPage(
            state,
            rawUrl: url,
            title: title,
            origin: WebViewOrigin.deeplink,
            fallback: const HomeScreen(),
          );
        },
      ),

      GoRoute(
        path: AppPaths.profile,
        pageBuilder: (context, state) =>
            _buildPage(state, const ProfileScreen()),
      ),
      GoRoute(
        path: AppPaths.newsDetail,
        pageBuilder: (context, state) {
          final l10n = AppLocalizations.of(context);
          final extra = state.extra;
          if (extra is! NewsArticle && extra is! NewsDetailArgs) {
            return _buildPage(
              state,
              Scaffold(body: Center(child: Text(l10n.invalidArticleData))),
            );
          }

          late final NewsArticle news;
          late final List<NewsArticle> articles;
          late final int initialIndex;

          if (extra is NewsDetailArgs) {
            news = extra.article;
            articles = extra.articles;
            initialIndex = extra.initialIndex;
          } else if (extra is NewsArticle) {
            news = extra;
            articles = [news];
            initialIndex = 0;
          } else {
            return _buildPage(
              state,
              Scaffold(body: Center(child: Text(l10n.invalidArticleData))),
            );
          }

          return _buildWebViewPage(
            state,
            rawUrl: news.url,
            title: news.source.isNotEmpty ? news.source : news.title,
            origin: WebViewOrigin.article,
            articles: articles,
            initialIndex: initialIndex,
            fallback: _buildInvalidWebView(context),
          );
        },
      ),
      GoRoute(
        path: AppPaths.webview,
        pageBuilder: (context, state) {
          final extra = state.extra;
          if (extra is! WebViewArgs) {
            return _buildPage(state, _buildInvalidWebView(context));
          }
          return _buildWebViewPage(
            state,
            url: extra.url,
            title: extra.title,
            origin: extra.origin,
            articles: extra.articles,
            initialIndex: extra.initialIndex,
            fallback: _buildInvalidWebView(context),
          );
        },
      ),
      GoRoute(
        path: AppPaths.securityLockout,
        pageBuilder: (context, state) =>
            _buildPage(state, const SecurityLockoutScreen()),
      ),
      GoRoute(
        path: AppPaths.subscriptionManagement,
        pageBuilder: (context, state) =>
            _buildPage(state, const SubscriptionManagementScreen()),
      ),
      GoRoute(
        path: AppPaths.legacyPrivacy,
        pageBuilder: (context, state) =>
            _buildPage(state, const PrivacyPolicyScreen()),
      ),
      GoRoute(
        path: AppPaths.fullAudioPlayer,
        pageBuilder: (context, state) =>
            _buildPage(state, const FullAudioPlayer()),
      ),
    ],
  );
}

class LazyStatefulBranchContainer extends StatefulWidget {
  const LazyStatefulBranchContainer({
    required this.currentIndex,
    required this.children,
    super.key,
  });

  final int currentIndex;
  final List<Widget> children;

  @override
  State<LazyStatefulBranchContainer> createState() =>
      _LazyStatefulBranchContainerState();
}

class _LazyStatefulBranchContainerState
    extends State<LazyStatefulBranchContainer> {
  late List<bool> _visited;

  @override
  void initState() {
    super.initState();
    _visited = List<bool>.filled(widget.children.length, false);
    if (widget.children.isNotEmpty) {
      _visited[widget.currentIndex] = true;
    }
  }

  @override
  void didUpdateWidget(covariant LazyStatefulBranchContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.children.length != _visited.length) {
      final nextVisited = List<bool>.filled(widget.children.length, false);
      for (int i = 0; i < _visited.length && i < nextVisited.length; i++) {
        nextVisited[i] = _visited[i];
      }
      _visited = nextVisited;
    }
    if (!_visited[widget.currentIndex]) {
      _visited[widget.currentIndex] = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: List<Widget>.generate(widget.children.length, (index) {
        if (!_visited[index]) {
          return const SizedBox.shrink();
        }

        final isActive = index == widget.currentIndex;
        return Offstage(
          offstage: !isActive,
          child: TickerMode(
            enabled: isActive,
            child: IgnorePointer(
              ignoring: !isActive,
              child: widget.children[index],
            ),
          ),
        );
      }),
    );
  }
}

NoTransitionPage<void> _buildPage(GoRouterState state, Widget child) {
  return NoTransitionPage<void>(key: state.pageKey, child: child);
}

NoTransitionPage<void> _buildWebViewPage(
  GoRouterState state, {
  required String title,
  required WebViewOrigin origin,
  required Widget fallback,
  String? rawUrl,
  Uri? url,
  List<NewsArticle> articles = const <NewsArticle>[],
  int initialIndex = 0,
}) {
  assert(rawUrl != null || url != null);
  final decision = rawUrl != null
      ? UrlSafetyPolicy.evaluate(rawUrl)
      : UrlSafetyPolicy.evaluateUri(url!);
  if (decision.disposition != UrlSafetyDisposition.allowInApp ||
      decision.uri == null) {
    return _buildPage(state, fallback);
  }
  return _buildPage(
    state,
    WebViewScreen(
      args: WebViewArgs(
        url: decision.uri!,
        title: title,
        origin: origin,
        articles: articles,
        initialIndex: initialIndex,
      ),
    ),
  );
}

Widget _buildInvalidWebView(BuildContext context) {
  return Scaffold(
    body: Center(child: Text(AppLocalizations.of(context).invalidArticleData)),
  );
}
