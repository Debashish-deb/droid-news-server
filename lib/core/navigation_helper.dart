// lib/core/navigation_helper.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class NavigationHelper {
  static void goHome(BuildContext context) {
    context.go('/home');
  }

  static void goNewspaper(BuildContext context) {
    context.go('/newspaper');
  }

  static void goMagazines(BuildContext context) {
    context.go('/magazines');
  }

  static void goSettings(BuildContext context) {
    context.go('/settings');
  }

  static void goFavorites(BuildContext context) {
    context.go('/favorites');
  }

  static void goAbout(BuildContext context) {
    context.go('/about');
  }

  static void goHelp(BuildContext context) {
    context.go('/supports');
  }

  static void goSearch(BuildContext context) {
    context.go('/search');
  }

  static void goProfile(BuildContext context) {
    context.go('/profile');
  }

  static void goLogin(BuildContext context) {
    context.go('/login');
  }

  static void goSignup(BuildContext context) {
    context.go('/signup');
  }

  static void goForgotPassword(BuildContext context) {
    context.go('/forgot-password');
  }

  static void goWebView(
    BuildContext context, {
    required String url,
    String? title,
  }) {
    context.push(
      '/webview',
      extra: <String, String>{'url': url, 'title': title ?? 'Web View'},
    );
  }

  static void goNewsDetail(BuildContext context, dynamic article) {
    context.push('/news-detail', extra: article);
  }
}
