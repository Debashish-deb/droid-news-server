// path: lib/core/router/routes.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../features/splash/splash_screen.dart';
import '../../../features/onboarding/onboarding_screen.dart';
import '../../../features/profile/profile_screen.dart';
import '../../../features/profile/edit_profile_screen.dart';
import '../../../features/profile/signup_screen.dart';
import '../../../features/profile/login_screen.dart';
import '../../../features/profile/forgot_password_screen.dart';
import '../../../features/news/newspaper_screen.dart';
import '../../../features/magazine/magazine_screen.dart';
import '../../../features/favorites/favorites_screen.dart';
import '../../../features/about/about_screen.dart';
import '../../../features/help/help_screen.dart';
import '../../../features/search/search_screen.dart';
import '../../../features/settings/settings_screen.dart';
import '../../../features/news_detail/news_detail_screen.dart';
import '../../../features/common/webview_screen.dart';
import '../../../main_navigation_screen.dart';
import '../../../data/models/news_article.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/splash',
    errorBuilder: (context, state) => const ErrorScreen(),
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, __) => const SignupScreen()),
      GoRoute(path: '/forgot-password', builder: (_, __) => const ForgotPasswordScreen()),

      GoRoute(path: '/home', builder: (_, __) => const MainNavigationScreen(selectedTab: 0)),
      GoRoute(path: '/newspaper', builder: (_, __) => const MainNavigationScreen(selectedTab: 1)),
      GoRoute(path: '/magazines', builder: (_, __) => const MainNavigationScreen(selectedTab: 2)),
      GoRoute(path: '/settings', builder: (_, __) => const MainNavigationScreen(selectedTab: 3)),

      GoRoute(path: '/favorites', builder: (_, __) => const FavoritesScreen()),
      GoRoute(path: '/about', builder: (_, __) => const AboutScreen()),
      GoRoute(path: '/supports', builder: (_, __) => const HelpScreen()),
      GoRoute(path: '/search', builder: (_, __) => const SearchScreen()),
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      GoRoute(path: '/edit_profile', builder: (_, __) => const EditProfileScreen()),

      GoRoute(
        path: '/news-detail',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is NewsArticle) {
            return NewsDetailScreen(news: extra);
          } else {
            return const ErrorScreen();
          }
        },
      ),

      GoRoute(
        path: '/webview',
        name: 'webview',
        builder: (context, state) {
          final args = state.extra;
          if (args is Map<String, dynamic> && args.containsKey('url')) {
            return WebViewScreen(
              url: args['url'] as String,
              title: args['title'] as String? ?? 'Web View',
            );
          } else {
            return const ErrorScreen();
          }
        },
      ),
    ],
  );
}

class ErrorScreen extends StatelessWidget {
  const ErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 80, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'Oops! Something went wrong.',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}