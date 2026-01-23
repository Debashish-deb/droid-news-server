import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';

import '../data/models/news_article.dart';
import '../features/home/home_screen.dart' show HomeScreen;
import 'app_paths.dart';
import '../../features/profile/auth_service.dart';
import '../../features/profile/profile_screen.dart';

// Splash & Onboarding
import '../../features/splash/splash_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';

// Auth
import '../../features/profile/login_screen.dart';
import '../../features/profile/signup_screen.dart';
import '../../features/profile/forgot_password_screen.dart';

// Main & Tabs
import '../../main_navigation_screen.dart';
import '../../features/news/newspaper_screen.dart';
import '../../features/magazine/magazine_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/extras/extras_screen.dart';

// Misc
import '../../features/favorites/favorites_screen.dart';
import '../../features/about/about_screen.dart';
import '../../features/help/help_screen.dart';
import '../../features/search/search_screen.dart';

// Details & WebView
import '../../features/news_detail/news_detail_screen.dart';
import '../../features/common/webview_screen.dart';
import '../../features/security/security_lockout_screen.dart';
import '../../features/offline/saved_articles_screen.dart';
import '../../data/services/remove_ads.dart';
import '../../features/subscription/subscription_management_screen.dart';

final ValueNotifier<bool> _authRefresh = ValueNotifier<bool>(
  AuthService().isLoggedIn,
);

class AppRouter {
  AppRouter._();

  static GoRouter createRouter({required String initialLocation}) {
    return GoRouter(
      debugLogDiagnostics: kDebugMode,
      initialLocation: initialLocation,
      refreshListenable: _authRefresh,
      redirect: (BuildContext context, GoRouterState state) {
        final bool loggedIn = AuthService().isLoggedIn;
        final String location = state.matchedLocation;

        // Publicly accessible routes (don't require login)
        const Set<String> publicRoutes = <String>{
          AppPaths.login,
          AppPaths.signup,
          AppPaths.forgotPassword,
          AppPaths.splash,
          AppPaths.onboarding,
        };

        final bool isPublic = publicRoutes.contains(location);

        if (!loggedIn && !isPublic) return AppPaths.login;
        if (loggedIn && location == AppPaths.login) return AppPaths.home;

        return null;
      },
      errorPageBuilder:
          (BuildContext context, GoRouterState state) =>
              MaterialPage(key: state.pageKey, child: const _ErrorScreen()),
      routes: <RouteBase>[
        GoRoute(
          path: AppPaths.splash,
          pageBuilder:
              (BuildContext ctx, GoRouterState state) =>
                  MaterialPage(key: state.pageKey, child: const SplashScreen()),
        ),
        GoRoute(
          path: AppPaths.onboarding,
          pageBuilder:
              (BuildContext ctx, GoRouterState state) => MaterialPage(
                key: state.pageKey,
                child: const OnboardingScreen(),
              ),
        ),
        GoRoute(
          path: AppPaths.login,
          pageBuilder:
              (BuildContext ctx, GoRouterState state) =>
                  MaterialPage(key: state.pageKey, child: const LoginScreen()),
        ),
        GoRoute(
          path: AppPaths.signup,
          pageBuilder:
              (BuildContext ctx, GoRouterState state) =>
                  MaterialPage(key: state.pageKey, child: const SignupScreen()),
        ),
        GoRoute(
          path: AppPaths.forgotPassword,
          pageBuilder:
              (BuildContext ctx, GoRouterState state) => MaterialPage(
                key: state.pageKey,
                child: const ForgotPasswordScreen(),
              ),
        ),

        // ============================================================
        // SHELL ROUTE (BOTTOM NAVIGATION)
        // ============================================================
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return MainNavigationScreen(navigationShell: navigationShell);
          },
          branches: [
            // BRANCH 0: HOME
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppPaths.home,
                  pageBuilder:
                      (context, state) => const MaterialPage(
                        // No key = no scroll restoration
                        child: HomeScreen(),
                      ),
                ),
              ],
            ),

            // BRANCH 1: NEWSPAPERS
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppPaths.newspaper,
                  pageBuilder:
                      (context, state) =>
                          const MaterialPage(child: NewspaperScreen()),
                ),
              ],
            ),

            // BRANCH 2: MAGAZINES
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppPaths.magazines,
                  pageBuilder:
                      (context, state) =>
                          const MaterialPage(child: MagazineScreen()),
                ),
              ],
            ),

            // BRANCH 3: SETTINGS
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppPaths.settings,
                  pageBuilder:
                      (context, state) =>
                          const MaterialPage(child: SettingsScreen()),
                ),
              ],
            ),

            // BRANCH 4: EXTRAS
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppPaths.extras,
                  pageBuilder:
                      (context, state) =>
                          const MaterialPage(child: ExtrasScreen()),
                ),
              ],
            ),
          ],
        ),

        // ============================================================
        // OTHER ROUTES (PUSHED ON TOP)
        // ============================================================
        GoRoute(
          path: AppPaths.profile,
          pageBuilder:
              (BuildContext ctx, GoRouterState state) => MaterialPage(
                key: state.pageKey,
                child: const ProfileScreen(),
              ),
        ),
        GoRoute(
          path: AppPaths.favorites,
          pageBuilder:
              (BuildContext ctx, GoRouterState state) => MaterialPage(
                key: state.pageKey,
                child: const FavoritesScreen(),
              ),
        ),
        GoRoute(
          path: AppPaths.about,
          pageBuilder:
              (BuildContext ctx, GoRouterState state) =>
                  MaterialPage(key: state.pageKey, child: const AboutScreen()),
        ),
        GoRoute(
          path: AppPaths.supports,
          pageBuilder:
              (BuildContext ctx, GoRouterState state) =>
                  MaterialPage(key: state.pageKey, child: const HelpScreen()),
        ),
        GoRoute(
          path: AppPaths.search,
          pageBuilder:
              (BuildContext ctx, GoRouterState state) =>
                  MaterialPage(key: state.pageKey, child: const SearchScreen()),
        ),
        GoRoute(
          path: AppPaths.newsDetail,
          pageBuilder: (BuildContext ctx, GoRouterState state) {
            final NewsArticle news = state.extra! as NewsArticle;
            return MaterialPage(
              key: state.pageKey,
              child: NewsDetailScreen(news: news),
            );
          },
        ),
        GoRoute(
          path: AppPaths.webview,
          pageBuilder: (BuildContext ctx, GoRouterState state) {
            // ✅ Defensive null checking to prevent blank screens
            if (state.extra == null) {
              // Navigation without data - show error instead of blank screen
              return MaterialPage(
                key: state.pageKey,
                child: const _ErrorScreen(),
              );
            }

            // ✅ Safe casting with null check
            final Map<String, dynamic>? args =
                state.extra is Map
                    ? Map<String, dynamic>.from(state.extra as Map)
                    : null;

            if (args == null || args['url'] == null) {
              // Missing required URL field - show error
              return MaterialPage(
                key: state.pageKey,
                child: const _ErrorScreen(),
              );
            }

            return MaterialPage(
              key: state.pageKey,
              child: WebViewScreen(
                url: args['url'] as String,
                title: args['title'] as String? ?? 'Article',
              ),
            );
          },
        ),
        GoRoute(
          path: AppPaths.securityLockout,
          pageBuilder:
              (BuildContext ctx, GoRouterState state) => MaterialPage(
                key: state.pageKey,
                child: const SecurityLockoutScreen(),
              ),
        ),
        GoRoute(
          path: AppPaths.offline,
          pageBuilder:
              (BuildContext ctx, GoRouterState state) => MaterialPage(
                key: state.pageKey,
                child: const SavedArticlesScreen(),
              ),
        ),
        GoRoute(
          path: AppPaths.removeAds,
          pageBuilder:
              (BuildContext ctx, GoRouterState state) => MaterialPage(
                key: state.pageKey,
                child: const RemoveAdsScreen(),
              ),
        ),
        GoRoute(
          path: AppPaths.subscriptionManagement,
          pageBuilder:
              (BuildContext ctx, GoRouterState state) => MaterialPage(
                key: state.pageKey,
                child: const SubscriptionManagementScreen(),
              ),
        ),
      ],
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.error_outline,
            size: 80,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Oops! Something went wrong.',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ],
      ),
    ),
  );
}
