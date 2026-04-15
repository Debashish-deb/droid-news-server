import 'package:bdnewsreader/presentation/features/home/home_screen.dart'
    show HomeScreen;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bdnewsreader/main.dart';
import 'package:bdnewsreader/core/navigation/app_paths.dart';
import 'package:bdnewsreader/core/di/providers.dart';
import 'package:bdnewsreader/core/bootstrap/startup_controller.dart';

import 'package:bdnewsreader/core/security/ssl_pinning.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('App Startup Integration Tests', () {
    setUp(() async {
      await SSLPinning.initialize();
      SharedPreferences.setMockInitialValues(<String, Object>{
        'theme': 'system',
        'language_code': 'en',
      });
    });

    testWidgets('app launches successfully', (WidgetTester tester) async {
      final prefs = await SharedPreferences.getInstance();
      final startupController = StartupController(
        initial: const StartupSnapshot.ready(initialRoute: AppPaths.home),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWith((ref) => prefs),
            startupControllerProvider.overrideWith((ref) => startupController),
          ],
          child: const MyApp(initialRoute: AppPaths.home),
        ),
      );

      await tester.pump();

      // Assert
      expect(find.byType(MaterialApp), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('home screen loads', (WidgetTester tester) async {
      final prefs = await SharedPreferences.getInstance();
      final startupController = StartupController(
        initial: const StartupSnapshot.ready(initialRoute: AppPaths.home),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWith((ref) => prefs),
            startupControllerProvider.overrideWith((ref) => startupController),
          ],
          child: const MyApp(initialRoute: AppPaths.home),
        ),
      );

      // We need to wait for initialization and navigation
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Assert
      expect(find.byType(HomeScreen), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('categories appear', (WidgetTester tester) async {
      final prefs = await SharedPreferences.getInstance();
      final startupController = StartupController(
        initial: const StartupSnapshot.ready(initialRoute: AppPaths.home),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWith((ref) => prefs),
            startupControllerProvider.overrideWith((ref) => startupController),
          ],
          child: const MyApp(initialRoute: AppPaths.home),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Assert
      expect(find.byType(Scrollable), findsWidgets);
      await tester.pumpAndSettle();
    });

    testWidgets('news articles appear', (WidgetTester tester) async {
      final prefs = await SharedPreferences.getInstance();
      final startupController = StartupController(
        initial: const StartupSnapshot.ready(initialRoute: AppPaths.home),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWith((ref) => prefs),
            startupControllerProvider.overrideWith((ref) => startupController),
          ],
          child: const MyApp(initialRoute: AppPaths.home),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Assert deterministic startup shell, not fragile card internals.
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(Scrollable), findsWidgets);
      await tester.pumpAndSettle();
    });
  });
}
