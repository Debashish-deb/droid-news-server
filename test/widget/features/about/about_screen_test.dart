import 'package:bdnewsreader/core/config/performance_config.dart';
import 'package:bdnewsreader/core/enums/theme_mode.dart';
import 'package:bdnewsreader/core/navigation/app_paths.dart';
import 'package:bdnewsreader/core/theme/theme.dart';
import 'package:bdnewsreader/l10n/generated/app_localizations.dart';
import 'package:bdnewsreader/presentation/features/about/about_screen.dart';
import 'package:bdnewsreader/presentation/features/settings/privacy_policy_screen.dart';
import 'package:bdnewsreader/presentation/providers/language_providers.dart';
import 'package:bdnewsreader/presentation/providers/theme_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  testWidgets('about screen renders without falling into the error widget', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          languageCodeProvider.overrideWith((ref) => 'en'),
          currentThemeModeProvider.overrideWith((ref) => AppThemeMode.system),
          navIconColorProvider.overrideWith((ref) => const Color(0xFF111111)),
        ],
        child: PerformanceConfig.defaults(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const AboutScreen(
              drawer: SizedBox.shrink(),
              packageInfoLoader: _fakePackageInfo,
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('About Us'), findsOneWidget);
    expect(find.text('Contact Us'), findsOneWidget);
    expect(find.text('Visit Website'), findsOneWidget);
    expect(find.textContaining('Something went wrong'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('about screen opens privacy policy without router failure', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: AppPaths.about,
      routes: [
        GoRoute(
          path: AppPaths.about,
          builder: (context, state) => const AboutScreen(
            drawer: SizedBox.shrink(),
            packageInfoLoader: _fakePackageInfo,
          ),
        ),
        GoRoute(
          path: AppPaths.legacyPrivacy,
          builder: (context, state) => const PrivacyPolicyScreen(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          languageCodeProvider.overrideWith((ref) => 'en'),
          currentThemeModeProvider.overrideWith((ref) => AppThemeMode.system),
          navIconColorProvider.overrideWith((ref) => const Color(0xFF111111)),
        ],
        child: PerformanceConfig.defaults(
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Privacy Policy'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Privacy Policy'));
    await tester.pumpAndSettle();

    expect(find.byType(PrivacyPolicyScreen), findsOneWidget);
    expect(find.textContaining('Something went wrong'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Future<PackageInfo> _fakePackageInfo() async => PackageInfo(
  appName: 'BD News Reader',
  packageName: 'com.bd.bdnewsreader',
  version: '1.0.1',
  buildNumber: '24',
  installerStore: 'play',
);
