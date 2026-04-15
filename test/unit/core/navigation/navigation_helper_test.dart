import 'package:bdnewsreader/core/navigation/app_paths.dart';
import 'package:bdnewsreader/core/navigation/navigation_helper.dart';
import 'package:bdnewsreader/presentation/features/common/webview_args.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  setUp(() {
    NavigationHelper.debugResetDedupeState();
  });

  testWidgets('openFullAudioPlayer dedupes repeated pushes from one tap', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () {
                  NavigationHelper.openFullAudioPlayer<void>(context);
                  NavigationHelper.openFullAudioPlayer<void>(context);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: AppPaths.fullAudioPlayer,
          builder: (context, state) => const Scaffold(body: Text('audio')),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.matches.length, 2);
    expect(find.text('audio'), findsOneWidget);
  });

  testWidgets('pushRouterDeduped allows distinct heavy routes by url', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (context, state) => const SizedBox.shrink()),
        GoRoute(
          path: AppPaths.webview,
          builder: (context, state) {
            final args = state.extra as WebViewArgs?;
            return Scaffold(body: Text(args?.title ?? 'webview'));
          },
        ),
      ],
    );

    final firstArgs = WebViewArgs(
      url: Uri.parse('https://example.com/a'),
      title: 'Article A',
      origin: WebViewOrigin.publisher,
    );
    final secondArgs = WebViewArgs(
      url: Uri.parse('https://example.com/b'),
      title: 'Article B',
      origin: WebViewOrigin.publisher,
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    NavigationHelper.pushRouterDeduped<void>(
      router,
      AppPaths.webview,
      extra: firstArgs,
    );
    NavigationHelper.pushRouterDeduped<void>(
      router,
      AppPaths.webview,
      extra: secondArgs,
    );
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.matches.length, 3);
    expect(find.text('Article B'), findsOneWidget);
  });
}
