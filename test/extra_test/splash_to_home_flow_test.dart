import 'package:bdnewsreader/application/lifecycle/app_state_machine.dart';
import 'package:bdnewsreader/infrastructure/services/notifications/push_notification_service.dart';
import 'package:bdnewsreader/application/sync/sync_orchestrator.dart';
import 'package:bdnewsreader/infrastructure/network/app_network_service.dart';
import 'package:bdnewsreader/core/utils/network_utils.dart';
import 'package:bdnewsreader/core/security/device_trust_notifier.dart';
import 'package:bdnewsreader/core/enums/device_trust_state.dart';
import 'package:bdnewsreader/core/telemetry/observability_service.dart';
import 'package:bdnewsreader/core/telemetry/debug_diagnostics_service.dart';
import 'package:bdnewsreader/core/security/security_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bdnewsreader/main.dart' as app;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bdnewsreader/core/di/providers.dart' as di;
import 'package:bdnewsreader/core/bootstrap/startup_controller.dart';
import 'package:bdnewsreader/core/config/performance_config.dart';
import 'package:bdnewsreader/presentation/providers/performance_providers.dart';
import 'package:bdnewsreader/infrastructure/services/storage/hive_service.dart';
import 'package:bdnewsreader/domain/facades/auth_facade.dart';
import 'package:bdnewsreader/core/navigation/app_paths.dart';
import 'package:bdnewsreader/presentation/features/home/home_screen.dart';
import 'package:bdnewsreader/l10n/generated/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import 'package:http/http.dart' as http;

import 'package:bdnewsreader/presentation/providers/news_providers.dart';

class MockAuthFacade extends Mock implements AuthFacade {}

class MockHiveService extends Mock implements HiveService {}

class MockFirebaseAnalytics extends Mock implements FirebaseAnalytics {}

class MockFirebaseCrashlytics extends Mock implements FirebaseCrashlytics {}

class MockPushNotificationService extends Mock
    implements PushNotificationService {}

class MockSyncOrchestrator extends Mock implements SyncOrchestrator {}

class MockAppLifecycleNotifier extends Mock implements AppLifecycleNotifier {}

class MockAppNetworkService extends Mock implements AppNetworkService {}

class MockNetworkUtils extends Mock implements NetworkUtils {}

class MockDeviceTrustNotifier extends Mock implements DeviceTrustNotifier {}

class MockObservabilityService extends Mock implements ObservabilityService {}

class MockDebugDiagnosticsService extends Mock
    implements DebugDiagnosticsService {}

class MockSecurityService extends Mock implements SecurityService {}

class MockHttpClient extends Mock implements http.Client {}

class SimpleNewsNotifier extends StateNotifier<NewsState>
    implements NewsNotifier {
  SimpleNewsNotifier()
    : super(
        const NewsState(
          articles: {
            'latest': [],
            'trending': [],
            'national': [],
            'international': [],
            'sports': [],
            'entertainment': [],
          },
          loading: {
            'latest': false,
            'trending': false,
            'national': false,
            'international': false,
            'sports': false,
            'entertainment': false,
          },
        ),
      );

  @override
  Future<void> loadNews(
    String category,
    Locale locale, {
    bool force = false,
    bool syncWithNetwork = true,
  }) async {}

  @override
  Future<void> loadMoreNews(String category, Locale locale) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  registerFallbackValue(<String>[]);
  registerFallbackValue(MockAppLifecycleNotifier());
  registerFallbackValue(DevicePerformanceTier.lowEnd);

  group('Splash to Home Flow', () {
    testWidgets('Should transition from Splash to Home', (
      WidgetTester tester,
    ) async {
      await tester.runAsync(() async {
        SharedPreferences.setMockInitialValues({'isLoggedIn': true});
        final prefs = await SharedPreferences.getInstance();

        final startupController = StartupController(
          initial: const StartupSnapshot.loading(),
        );

        final mockAuth = MockAuthFacade();
        final mockHive = MockHiveService();
        final mockAnalytics = MockFirebaseAnalytics();
        final mockCrashlytics = MockFirebaseCrashlytics();
        final mockPush = MockPushNotificationService();
        final mockSync = MockSyncOrchestrator();
        final mockNetwork = MockAppNetworkService();
        final mockNetworkUtils = MockNetworkUtils();
        final mockDeviceTrust = MockDeviceTrustNotifier();
        final mockObservability = MockObservabilityService();
        final mockDebug = MockDebugDiagnosticsService();
        final mockSecurity = MockSecurityService();
        final mockHttpClient = MockHttpClient();
        final simpleNews = SimpleNewsNotifier();

        when(() => mockAuth.init()).thenAnswer((_) async {});
        when(() => mockHive.init(any())).thenAnswer((_) async {});
        when(() => mockPush.initialize()).thenAnswer((_) async {});
        when(
          () => mockSync.registerAppLifecycleNotifier(any()),
        ).thenReturn(null);
        when(() => mockNetwork.initialize()).thenAnswer((_) async {});
        when(() => mockNetwork.updatePerformanceTier(any())).thenReturn(null);
        when(() => mockNetwork.addListener(any())).thenReturn(null);
        when(() => mockNetwork.removeListener(any())).thenReturn(null);
        when(
          () => mockNetwork.currentQuality,
        ).thenReturn(NetworkQuality.excellent);
        when(() => mockNetwork.isConnected).thenReturn(true);
        when(() => mockNetworkUtils.initialize()).thenAnswer((_) async {});
        when(() => mockDeviceTrust.initialize()).thenAnswer((_) async {});
        when(() => mockDeviceTrust.state).thenReturn(DeviceTrustState.trusted);
        when(
          () => mockDeviceTrust.stream,
        ).thenAnswer((_) => const Stream.empty());
        when(
          () => mockObservability.logEvent(
            any(),
            parameters: any(named: 'parameters'),
          ),
        ).thenAnswer((_) async {});
        when(() => mockDebug.start()).thenReturn(null);
        when(() => mockSecurity.initialize()).thenAnswer((_) async {});

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              di.sharedPreferencesProvider.overrideWith((ref) => prefs),
              di.startupControllerProvider.overrideWith(
                (ref) => startupController,
              ),
              di.authFacadeProvider.overrideWithValue(mockAuth),
              di.hiveServiceProvider.overrideWithValue(mockHive),
              di.analyticsProvider.overrideWithValue(mockAnalytics),
              di.crashlyticsProvider.overrideWithValue(mockCrashlytics),
              di.pushNotificationServiceProvider.overrideWithValue(mockPush),
              di.syncOrchestratorProvider.overrideWithValue(mockSync),
              di.appNetworkServiceProvider.overrideWith((ref) => mockNetwork),
              di.networkUtilsProvider.overrideWithValue(mockNetworkUtils),
              di.deviceTrustControllerProvider.overrideWith(
                (ref) => mockDeviceTrust,
              ),
              di.observabilityServiceProvider.overrideWithValue(
                mockObservability,
              ),
              di.debugDiagnosticsServiceProvider.overrideWithValue(mockDebug),
              di.securityServiceProvider.overrideWithValue(mockSecurity),
              di.httpClientProvider.overrideWithValue(mockHttpClient),
              newsProvider.overrideWith((ref) => simpleNews),
              performanceConfigProvider.overrideWith(
                (ref) async =>
                    PerformanceConfig.defaults(child: const SizedBox.shrink()),
              ),
            ],
            child: PerformanceConfig.defaults(
              child: app.MyApp(
                initialRoute: '/home',
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                ],
              ),
            ),
          ),
        );

        // Initial state: Splash
        await tester.pump();
        expect(find.byType(app.MyApp), findsOneWidget);

        // Trigger transition to ready
        startupController.setSnapshot(
          const StartupSnapshot.ready(initialRoute: AppPaths.home),
        );

        // Let the router and animations process
        for (int i = 0; i < 30; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        // Should be on Home Screen
        expect(find.byType(HomeScreen), findsOneWidget);
      });
    });

    testWidgets('Rapid navigation should not crash', (
      WidgetTester tester,
    ) async {
      SharedPreferences.setMockInitialValues({'isLoggedIn': true});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            di.sharedPreferencesProvider.overrideWith((ref) => prefs),
            performanceConfigProvider.overrideWith(
              (ref) => Future.delayed(
                const Duration(seconds: 1),
                () =>
                    PerformanceConfig.defaults(child: const SizedBox.shrink()),
              ),
            ),
          ],
          child: PerformanceConfig.defaults(
            child: const app.MyApp(initialRoute: '/splash'),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));

      // Avoid timer leak
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(app.MyApp), findsOneWidget);
    });
  });
}
