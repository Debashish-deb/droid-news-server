// ignore_for_file: avoid_classes_with_only_static_members

// lib/core/navigation_helper.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../presentation/features/common/webview_args.dart';
import 'app_paths.dart';
import 'url_safety_policy.dart';

class NavigationHelper {
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
        context.push(
          AppPaths.webview,
          extra: WebViewArgs(
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

  static void goNewsDetail(BuildContext context, dynamic article) {
    context.push(AppPaths.newsDetail, extra: article);
  }
}
