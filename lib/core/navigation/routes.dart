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

import '../../presentation/features/favorites/favorites_screen.dart';
import '../../presentation/features/about/about_screen.dart';
import '../../presentation/features/help/help_screen.dart';
import '../../presentation/features/search/search_screen.dart';
import '../../presentation/features/offline/saved_articles_screen.dart';

import '../../presentation/features/common/webview_screen.dart';
import '../../presentation/features/common/news_detail_args.dart';
import '../../presentation/features/common/webview_args.dart';
import '../../presentation/features/security/security_lockout_screen.dart';
import '../../presentation/features/magazine/magazine_screen.dart';

import '../../presentation/features/subscription/subscription_management_screen.dart';
import '../../domain/entities/news_article.dart';
import '../../presentation/features/settings/privacy_policy_screen.dart';
import '../../presentation/features/tts/ui/full_audio_player.dart';

import 'app_paths.dart';
import 'url_safety_policy.dart';
import '../../presentation/widgets/bottom_nav_bar.dart';
import '../../l10n/generated/app_localizations.dart';
import '../config/performance_config.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

GoRouter createRouter({String? initialLocation}) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: initialLocation ?? AppPaths.splash,
    // refreshListenable: di.sl<AuthFacade>(), // AuthFacade doesn't extend ChangeNotifier
    redirect: (context, state) async {
      if (state.matchedLocation == AppPaths.splash) return null;

      // Protect secure routes
      // if (!isLoggedIn && state.matchedLocation.startsWith('/home')) return AppPaths.login;

      return null;
    },
    routes: [
      GoRoute(
        path: AppPaths.splash,
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: BootstrapScreen()),
      ),
      GoRoute(
        path: AppPaths.onboarding,
        pageBuilder: (context, state) =>
            _buildTransition(context, state, const OnboardingScreen()),
      ),
      GoRoute(
        path: AppPaths.login,
        pageBuilder: (context, state) =>
            _buildTransition(context, state, const LoginScreen()),
      ),
      GoRoute(
        path: AppPaths.signup,
        pageBuilder: (context, state) =>
            _buildTransition(context, state, const SignupScreen()),
      ),
      GoRoute(
        path: AppPaths.forgotPassword,
        pageBuilder: (context, state) =>
            _buildTransition(context, state, const ForgotPasswordScreen()),
      ),

      // Industrial Grade: StatefulShellRoute to preserve tab state
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ScaffoldWithNavBar(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppPaths.home,
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: HomeScreen()),
                routes: [
                  // Drawer Routes pinned to Home Tab
                  GoRoute(
                    path:
                        'extras', // AppPaths.extras is /home/extras, so sub-path is 'extras'
                    pageBuilder: (context, state) =>
                        _buildTransition(context, state, const ExtrasScreen()),
                    routes: [
                      GoRoute(
                        path: 'offline',
                        pageBuilder: (context, state) => _buildTransition(
                          context,
                          state,
                          const SavedArticlesScreen(),
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'favorites',
                    pageBuilder: (context, state) => _buildTransition(
                      context,
                      state,
                      const FavoritesScreen(),
                    ),
                  ),
                  GoRoute(
                    path: 'about',
                    pageBuilder: (context, state) =>
                        _buildTransition(context, state, const AboutScreen()),
                  ),
                  GoRoute(
                    path: 'help',
                    pageBuilder: (context, state) =>
                        _buildTransition(context, state, const HelpScreen()),
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
                    const NoTransitionPage(child: NewspaperScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppPaths.search,
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: SearchScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppPaths.magazine,
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: MagazineScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppPaths.settings,
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: SettingsScreen()),
                routes: [
                  GoRoute(
                    path: 'manage-sources',
                    pageBuilder: (context, state) => _buildTransition(
                      context,
                      state,
                      const SourceManagementScreen(),
                    ),
                  ),
                  GoRoute(
                    path: 'privacy',
                    pageBuilder: (context, state) => _buildTransition(
                      context,
                      state,
                      const PrivacyPolicyScreen(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppPaths.savedArticles,
        pageBuilder: (context, state) =>
            _buildTransition(context, state, const SavedArticlesScreen()),
      ),

      GoRoute(
        path: '/deeplink/article',
        pageBuilder: (context, state) {
          final url = state.uri.queryParameters['url'];
          final title = state.uri.queryParameters['title'] ?? 'News';

          if (url == null) {
            return _buildTransition(context, state, const HomeScreen());
          }

          final decision = UrlSafetyPolicy.evaluate(url);
          if (decision.disposition != UrlSafetyDisposition.allowInApp ||
              decision.uri == null) {
            return _buildTransition(context, state, const HomeScreen());
          }

          return _buildTransition(
            context,
            state,
            WebViewScreen(
              args: WebViewArgs(
                url: decision.uri!,
                title: title,
                origin: WebViewOrigin.deeplink,
              ),
            ),
          );
        },
      ),

      // ... Other Routes ...
      GoRoute(
        path: AppPaths.profile,
        pageBuilder: (context, state) =>
            _buildTransition(context, state, const ProfileScreen()),
      ),
      GoRoute(
        path: AppPaths.newsDetail,
        pageBuilder: (context, state) {
          final l10n = AppLocalizations.of(context);
          final extra = state.extra;
          if (extra is! NewsArticle && extra is! NewsDetailArgs) {
            return _buildTransition(
              context,
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
            return _buildTransition(
              context,
              state,
              Scaffold(body: Center(child: Text(l10n.invalidArticleData))),
            );
          }

          return _buildTransition(
            context,
            state,
            _buildValidatedWebView(
              url: news.url,
              title: news.source.isNotEmpty ? news.source : news.title,
              origin: WebViewOrigin.article,
              articles: articles,
              initialIndex: initialIndex,
            ),
          );
        },
      ),
      GoRoute(
        path: AppPaths.webview,
        pageBuilder: (context, state) {
          final extra = state.extra;
          if (extra is! WebViewArgs) {
            return _buildTransition(
              context,
              state,
              _buildInvalidWebView(context),
            );
          }
          final decision = UrlSafetyPolicy.evaluateUri(extra.url);
          if (decision.disposition != UrlSafetyDisposition.allowInApp ||
              decision.uri == null) {
            return _buildTransition(
              context,
              state,
              _buildInvalidWebView(context),
            );
          }
          return _buildTransition(
            context,
            state,
            WebViewScreen(
              args: WebViewArgs(
                url: decision.uri!,
                title: extra.title,
                origin: extra.origin,
                articles: extra.articles,
                initialIndex: extra.initialIndex,
              ),
            ),
          );
        },
      ),
      GoRoute(
        path: AppPaths.securityLockout,
        pageBuilder: (context, state) =>
            _buildTransition(context, state, const SecurityLockoutScreen()),
      ),
      GoRoute(
        path: AppPaths.subscriptionManagement,
        pageBuilder: (context, state) => _buildTransition(
          context,
          state,
          const SubscriptionManagementScreen(),
        ),
      ),
      GoRoute(
        path: AppPaths.legacyPrivacy,
        pageBuilder: (context, state) =>
            _buildTransition(context, state, const PrivacyPolicyScreen()),
      ),
      GoRoute(
        path: AppPaths.fullAudioPlayer,
        pageBuilder: (context, state) =>
            _buildTransition(context, state, const FullAudioPlayer()),
      ),
    ],
  );
}

Widget _buildValidatedWebView({
  required String url,
  required String title,
  required WebViewOrigin origin,
  List<NewsArticle> articles = const <NewsArticle>[],
  int initialIndex = 0,
}) {
  final decision = UrlSafetyPolicy.evaluate(url);
  if (decision.disposition != UrlSafetyDisposition.allowInApp ||
      decision.uri == null) {
    return Builder(builder: (context) => _buildInvalidWebView(context));
  }
  return WebViewScreen(
    args: WebViewArgs(
      url: decision.uri!,
      title: title,
      origin: origin,
      articles: articles,
      initialIndex: initialIndex,
    ),
  );
}

Widget _buildInvalidWebView(BuildContext context) {
  return Scaffold(
    body: Center(child: Text(AppLocalizations.of(context).invalidArticleData)),
  );
}

CustomTransitionPage _buildTransition(
  BuildContext context,
  GoRouterState state,
  Widget child,
) {
  final perf = PerformanceConfig.of(context);
  final bool reduceMotion =
      perf.reduceMotion ||
      perf.reduceEffects ||
      perf.lowPowerMode ||
      perf.isLowEndDevice;
  return CustomTransitionPage(
    key: state.pageKey,
    maintainState: false,
    child: _ResetScrollOnMount(child: child),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (reduceMotion) return child;
      // iOS-like Slide Transition
      const begin = Offset(1.0, 0.0);
      const end = Offset.zero;
      const curve = Curves.easeInOut;
      final tween = Tween(
        begin: begin,
        end: end,
      ).chain(CurveTween(curve: curve));
      final offsetAnimation = animation.drive(tween);

      return SlideTransition(position: offsetAnimation, child: child);
    },
  );
}

class _ResetScrollOnMount extends StatefulWidget {
  const _ResetScrollOnMount({required this.child});

  final Widget child;

  @override
  State<_ResetScrollOnMount> createState() => _ResetScrollOnMountState();
}

class _ResetScrollOnMountState extends State<_ResetScrollOnMount> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resetPrimaryScroll());
  }

  @override
  void didUpdateWidget(covariant _ResetScrollOnMount oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _resetPrimaryScroll());
  }

  void _resetPrimaryScroll() {
    if (!mounted) return;
    final controller = PrimaryScrollController.maybeOf(context);
    if (controller != null && controller.hasClients) {
      controller.jumpTo(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class ScaffoldWithNavBar extends StatelessWidget {
  const ScaffoldWithNavBar({required this.navigationShell, super.key});
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: BottomNavBar(navigationShell: navigationShell),
    );
  }
}
