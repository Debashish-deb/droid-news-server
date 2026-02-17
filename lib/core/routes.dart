import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../presentation/features/home/home_screen.dart' show HomeScreen;
import '../presentation/features/profile/profile_screen.dart';
import '../presentation/features/profile/login_screen.dart';
import '../presentation/features/profile/signup_screen.dart';
import '../presentation/features/profile/forgot_password_screen.dart';
import '../presentation/features/splash/splash_screen.dart';
import '../presentation/features/onboarding/onboarding_screen.dart';

import '../presentation/features/news/newspaper_screen.dart';
import '../presentation/features/magazine/magazine_screen.dart';
import '../presentation/features/settings/settings_screen.dart';
import '../presentation/features/extras/extras_screen.dart';

import '../presentation/features/favorites/favorites_screen.dart';
import '../presentation/features/about/about_screen.dart';
import '../presentation/features/help/help_screen.dart';
import '../presentation/features/search/search_screen.dart';

import '../presentation/features/common/webview_screen.dart';
import '../presentation/features/security/security_lockout_screen.dart';
import '../presentation/features/offline/saved_articles_screen.dart';

import '../presentation/features/subscription/subscription_management_screen.dart';
import '../domain/entities/news_article.dart';

import 'app_paths.dart';
import '../presentation/widgets/bottom_nav_bar.dart';
import '../l10n/generated/app_localizations.dart';
import 'performance_config.dart';

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
      // ... Auth Routes (Login, Signup, etc) ...
      GoRoute(
        path: AppPaths.splash,
        pageBuilder: (context, state) =>
            _buildTransition(context, state, const SplashScreen()),
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
                    path: 'extras', // AppPaths.extras is /home/extras, so sub-path is 'extras'
                    pageBuilder: (context, state) =>
                         _buildTransition(context, state, const ExtrasScreen()),
                  ),
                  GoRoute(
                    path: 'favorites',
                    pageBuilder: (context, state) =>
                       _buildTransition(context, state, const FavoritesScreen()),
                  ),
                  GoRoute(
                    path: 'saved-articles',
                    pageBuilder: (context, state) =>
                         _buildTransition(context, state, const SavedArticlesScreen()),
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
                path: AppPaths.magazine,
                pageBuilder: (context, state) =>
                   const NoTransitionPage(child: MagazineScreen()),
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
                path: AppPaths.settings,
                 pageBuilder: (context, state) =>
                   const NoTransitionPage(child: SettingsScreen()),
              ),
            ],
          ),
        ],
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
          if (state.extra is! NewsArticle) {
            return _buildTransition(context, state, Scaffold(body: Center(child: Text(l10n.invalidArticleData))));
          }
          final news = state.extra as NewsArticle;
          return _buildTransition(context, state, WebViewScreen(
            url: news.url,
            title: news.source.isNotEmpty ? news.source : news.title,
            articles: [news],
            initialIndex: 0,
          ));
        },
      ),
      GoRoute(
        path: AppPaths.webview,
        pageBuilder: (context, state) {
          final args = state.extra as Map<String, dynamic>;
          final l10n = AppLocalizations.of(context);
          return _buildTransition(context, state, WebViewScreen(
            url: args['url'] as String,
            title: args['title'] as String? ?? l10n.articles,
          ));
        },
      ),
      GoRoute(
        path: AppPaths.securityLockout,
        pageBuilder: (context, state) =>
           _buildTransition(context, state, const SecurityLockoutScreen()),
      ),
      GoRoute(
        path: AppPaths.subscriptionManagement,
        pageBuilder: (context, state) =>
           _buildTransition(context, state, const SubscriptionManagementScreen()),
      ),
    ],
  );
}

CustomTransitionPage _buildTransition(BuildContext context, GoRouterState state, Widget child) {
  final bool reduceMotion = PerformanceConfig.of(context).reduceMotion;
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (reduceMotion) return child;
      // iOS-like Slide Transition
      const begin = Offset(1.0, 0.0);
      const end = Offset.zero;
      const curve = Curves.easeInOut;
      final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
      final offsetAnimation = animation.drive(tween);
      
      return SlideTransition(position: offsetAnimation, child: child);
    },
  );
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
