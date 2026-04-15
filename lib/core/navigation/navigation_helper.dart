// ignore_for_file: avoid_classes_with_only_static_members

// lib/core/navigation_helper.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/entities/news_article.dart';
import '../../presentation/features/common/news_detail_args.dart';
import '../../presentation/features/common/webview_args.dart';
import 'app_paths.dart';
import 'url_safety_policy.dart';

class NavigationHelper {
  static const Duration _heavyRoutePushCooldown = Duration(milliseconds: 300);
  static final Map<String, DateTime> _recentHeavyPushes =
      <String, DateTime>{};

  static void goHome(BuildContext context) {
    context.go(AppPaths.home);
  }

  static void goNewspaper(BuildContext context) {
    context.go(AppPaths.newspaper);
  }

  static void goMagazines(BuildContext context) {
    context.go(AppPaths.magazine);
  }

  static void goSettings(BuildContext context) {
    context.go(AppPaths.settings);
  }

  static void goFavorites(BuildContext context) {
    context.go(AppPaths.favorites);
  }

  static void goAbout(BuildContext context) {
    context.go(AppPaths.about);
  }

  static void goHelp(BuildContext context) {
    context.go(AppPaths.help);
  }

  static void goSearch(BuildContext context) {
    context.go(AppPaths.search);
  }

  static void goProfile(BuildContext context) {
    context.go(AppPaths.profile);
  }

  static void goLogin(BuildContext context) {
    context.go(AppPaths.login);
  }

  static void goSignup(BuildContext context) {
    context.go(AppPaths.signup);
  }

  static void goForgotPassword(BuildContext context) {
    context.go(AppPaths.forgotPassword);
  }

  static Future<T?> pushRouterDeduped<T>(
    GoRouter router,
    String location, {
    Object? extra,
    String? dedupeKey,
  }) {
    final resolvedKey = dedupeKey ?? _dedupeKeyForRoute(location, extra);
    if (!_shouldPushHeavyRoute(resolvedKey)) {
      return Future<T?>.value();
    }
    return router.push<T>(location, extra: extra);
  }

  static Future<T?> openSubscriptionManagement<T>(BuildContext context) {
    return _pushDeduped<T>(context, AppPaths.subscriptionManagement);
  }

  static Future<T?> openFullAudioPlayer<T>(BuildContext context) {
    return _pushDeduped<T>(context, AppPaths.fullAudioPlayer);
  }

  static Future<T?> openWebViewArgs<T>(
    BuildContext context,
    WebViewArgs args,
  ) {
    return _pushDeduped<T>(context, AppPaths.webview, extra: args);
  }

  static Future<void> goWebView(
    BuildContext context, {
    required String url,
    String? title,
  }) async {
    final decision = UrlSafetyPolicy.evaluate(url);
    switch (decision.disposition) {
      case UrlSafetyDisposition.allowInApp:
        final uri = decision.uri;
        if (uri == null) {
          return;
        }
        await openWebViewArgs<void>(
          context,
          WebViewArgs(
            url: uri,
            title: title ?? 'Web View',
            origin: WebViewOrigin.publisher,
          ),
        );
        return;
      case UrlSafetyDisposition.openExternal:
        final uri = decision.uri;
        if (uri != null) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
        return;
      case UrlSafetyDisposition.reject:
        return;
    }
  }

  static Future<T?> openNewsDetail<T>(BuildContext context, Object article) {
    return _pushDeduped<T>(context, AppPaths.newsDetail, extra: article);
  }

  static Future<T?> goNewsDetail<T>(BuildContext context, Object article) {
    return openNewsDetail<T>(context, article);
  }

  @visibleForTesting
  static void debugResetDedupeState() {
    _recentHeavyPushes.clear();
  }

  static Future<T?> _pushDeduped<T>(
    BuildContext context,
    String location, {
    Object? extra,
    String? dedupeKey,
  }) {
    if (!context.mounted) {
      return Future<T?>.value();
    }
    final resolvedKey = dedupeKey ?? _dedupeKeyForRoute(location, extra);
    if (!_shouldPushHeavyRoute(resolvedKey)) {
      return Future<T?>.value();
    }
    return context.push<T>(location, extra: extra);
  }

  static bool _shouldPushHeavyRoute(String key) {
    final now = DateTime.now();
    _recentHeavyPushes.removeWhere(
      (_, timestamp) => now.difference(timestamp) > const Duration(seconds: 5),
    );

    final previous = _recentHeavyPushes[key];
    if (previous != null &&
        now.difference(previous) < _heavyRoutePushCooldown) {
      return false;
    }

    _recentHeavyPushes[key] = now;
    return true;
  }

  static String _dedupeKeyForRoute(String location, Object? extra) {
    final resourceKey = switch (extra) {
      WebViewArgs(:final url) => url.toString(),
      NewsDetailArgs(:final article) => article.url,
      NewsArticle(:final url) => url,
      _ => null,
    };

    return resourceKey == null || resourceKey.isEmpty
        ? location
        : '$location::$resourceKey';
  }
}
