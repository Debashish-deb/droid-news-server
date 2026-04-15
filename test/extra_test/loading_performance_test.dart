import 'package:bdnewsreader/presentation/features/splash/bootstrap_screen.dart'
    show BootstrapScreen;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bdnewsreader/main.dart';
import 'package:bdnewsreader/core/navigation/app_paths.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bdnewsreader/core/di/providers.dart';
import 'package:bdnewsreader/core/bootstrap/startup_controller.dart';
import 'package:bdnewsreader/presentation/features/security/security_lockout_screen.dart';
import 'package:bdnewsreader/l10n/generated/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:bdnewsreader/core/config/performance_config.dart';

Future<Widget> _buildApp(
  SharedPreferences prefs, {
  StartupController? startupController,
}) async {
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWith((ref) => prefs),
      if (startupController != null)
        startupControllerProvider.overrideWith((ref) => startupController),
    ],
    child: PerformanceConfig.defaults(
      child: const MyApp(
        initialRoute: AppPaths.splash,
        // Provide localizations for screens that need it (like SecurityLockoutScreen)
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('Performance Benchmarks', () {
    testWidgets('First frame should render successfully', (
      WidgetTester tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final startupController = StartupController();

      await tester.pumpWidget(
        await _buildApp(prefs, startupController: startupController),
      );

      await tester.pump();
      expect(find.byType(MyApp), findsOneWidget);
    });

    testWidgets(
      'Firebase unavailable renders retry screen instead of crashing',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final startupController = StartupController(
          initial: const StartupSnapshot.firebaseUnavailable(
            message: 'firebase unavailable',
          ),
        );

        await tester.pumpWidget(
          await _buildApp(prefs, startupController: startupController),
        );
        await tester.pump(); // Start build
        await tester.pump(const Duration(milliseconds: 100)); // Process state
        await tester.pumpAndSettle();

        expect(find.text('Startup unavailable'), findsOneWidget);
        expect(find.byType(BootstrapScreen), findsOneWidget);
      },
    );

    testWidgets('Splash waits for bootstrap completion before routing', (
      WidgetTester tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final startupController = StartupController();

      await tester.pumpWidget(
        await _buildApp(prefs, startupController: startupController),
      );
      await tester.pump();

      expect(find.byType(BootstrapScreen), findsOneWidget);
      expect(find.byType(SecurityLockoutScreen), findsNothing);

      startupController.setSnapshot(
        const StartupSnapshot.ready(initialRoute: AppPaths.securityLockout),
      );
      await tester.pump();
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.byType(SecurityLockoutScreen), findsOneWidget);
    });

    testWidgets('Blocked trust state routes to lockout', (
      WidgetTester tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final startupController = StartupController(
        initial: const StartupSnapshot.blocked(message: 'security blocked'),
      );

      await tester.pumpWidget(
        await _buildApp(prefs, startupController: startupController),
      );

      // Manual pump to avoid animation hang and allow GoRouter to settle
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      expect(find.byType(SecurityLockoutScreen), findsOneWidget);
    });
  });
}
