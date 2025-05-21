// File: lib/routes.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';

import '../data/models/news_article.dart';
import '../features/movies/movie.dart';
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
import '../../features/movies/movie_detail_screen.dart';

/// Fires when AuthService.login/logout happens
final _authRefresh = ValueNotifier<bool>(AuthService().isLoggedIn);

class AppRouter {
  AppRouter._();

  static GoRouter createRouter({ required String initialLocation }) {
    return GoRouter(
      debugLogDiagnostics: kDebugMode,
      initialLocation: initialLocation,
      refreshListenable: _authRefresh,
      redirect: (context, state) {
        final loggedIn = AuthService().isLoggedIn;
        final goingToLogin = state.uri.toString() == AppPaths.login;

        if (!loggedIn && !goingToLogin) return AppPaths.login;
        if ( loggedIn && goingToLogin)  return AppPaths.home;
        return null;
      },
      errorPageBuilder: (context, state) => MaterialPage(
        key: state.pageKey,
        child: const _ErrorScreen(),
      ),
      routes: [
        GoRoute(path: AppPaths.splash, pageBuilder: (ctx, state) => MaterialPage(
          key: state.pageKey,
          child: const SplashScreen(),
        )),

        GoRoute(path: AppPaths.onboarding, pageBuilder: (ctx, state) => MaterialPage(
          key: state.pageKey,
          child: const OnboardingScreen(),
        )),

        GoRoute(path: AppPaths.profile, pageBuilder: (ctx, state) => MaterialPage(
          key: state.pageKey,
          child: const ProfileScreen(),
        )),

        GoRoute(path: AppPaths.login, pageBuilder: (ctx, state) => MaterialPage(
          key: state.pageKey,
          child: const LoginScreen(),
        )),

        GoRoute(path: AppPaths.signup, pageBuilder: (ctx, state) => MaterialPage(
          key: state.pageKey,
          child: const SignupScreen(),
        )),

        GoRoute(path: AppPaths.forgotPassword, pageBuilder: (ctx, state) => MaterialPage(
          key: state.pageKey,
          child: const ForgotPasswordScreen(),
        )),

        GoRoute(path: AppPaths.home, pageBuilder: (ctx, state) => MaterialPage(
          key: state.pageKey,
          child: const MainNavigationScreen(selectedTab: 0),
        )),

        // Deep links for each tab (optional)
        GoRoute(path: AppPaths.newspaper, pageBuilder: (ctx, state) => MaterialPage(
          key: state.pageKey,
          child: const NewspaperScreen(),
        )),
        GoRoute(path: AppPaths.magazines, pageBuilder: (ctx, state) => MaterialPage(
          key: state.pageKey,
          child: const MagazineScreen(),
        )),
        GoRoute(path: AppPaths.settings, pageBuilder: (ctx, state) => MaterialPage(
          key: state.pageKey,
          child: const SettingsScreen(),
        )),
        GoRoute(path: AppPaths.extras, pageBuilder: (ctx, state) => MaterialPage(
          key: state.pageKey,
          child: const ExtrasScreen(),
        )),

        GoRoute(path: AppPaths.favorites, pageBuilder: (ctx, state) => MaterialPage(
          key: state.pageKey,
          child: const FavoritesScreen(),
        )),
        GoRoute(path: AppPaths.about, pageBuilder: (ctx, state) => MaterialPage(
          key: state.pageKey,
          child: const AboutScreen(),
        )),
        GoRoute(path: AppPaths.supports, pageBuilder: (ctx, state) => MaterialPage(
          key: state.pageKey,
          child: const HelpScreen(),
        )),
        GoRoute(path: AppPaths.search, pageBuilder: (ctx, state) => MaterialPage(
          key: state.pageKey,
          child: const SearchScreen(),
        )),

        GoRoute(
          path: AppPaths.newsDetail,
          pageBuilder: (ctx, state) {
            final news = state.extra! as NewsArticle;
            return MaterialPage(
              key: state.pageKey,
              child: NewsDetailScreen(news: news),
            );
          },
        ),

        GoRoute(
          path: AppPaths.webview,
          pageBuilder: (ctx, state) {
          final args = Map<String, dynamic>.from(state.extra as Map);
            return MaterialPage(
              key: state.pageKey,
              child: WebViewScreen(
  url: args['url']!,
  title: args['title'] ?? '',
),


            );
          },
        ),

        GoRoute(
          path: AppPaths.movieDetail,
          pageBuilder: (ctx, state) {
            final movie = state.extra! as Movie;
            return MaterialPage(
              key: state.pageKey,
              child: MovieDetailScreen(movie: movie),
            );
          },
        ),

        // ... add any other routes here ...
      ],
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.error_outline, size: 80, color: Theme.of(context).colorScheme.error),
        const SizedBox(height: 16),
        Text('Oops! Something went wrong.', style: Theme.of(context).textTheme.titleLarge),
      ]),
    ),
  );
}
