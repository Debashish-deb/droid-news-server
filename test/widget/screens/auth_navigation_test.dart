import 'package:bdnewsreader/core/config/performance_config.dart';
import 'package:bdnewsreader/core/enums/theme_mode.dart';
import 'package:bdnewsreader/core/navigation/app_paths.dart';
import 'package:bdnewsreader/core/theme/theme.dart';
import 'package:bdnewsreader/domain/facades/auth_facade.dart';
import 'package:bdnewsreader/l10n/generated/app_localizations.dart';
import 'package:bdnewsreader/presentation/features/login/login_screen.dart'
    as simple_login;
import 'package:bdnewsreader/presentation/features/profile/login_screen.dart';
import 'package:bdnewsreader/presentation/features/profile/signup_screen.dart';
import 'package:bdnewsreader/presentation/providers/feature_providers.dart';
import 'package:bdnewsreader/presentation/providers/theme_providers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  Widget buildTestApp(GoRouter router, {AuthFacade? auth}) {
    return ProviderScope(
      overrides: [
        currentThemeModeProvider.overrideWith((ref) => AppThemeMode.system),
        navIconColorProvider.overrideWith((ref) => const Color(0xFF1565D8)),
        if (auth != null) authServiceProvider.overrideWithValue(auth),
      ],
      child: PerformanceConfig.autoDetectSync(
        reduceMotion: true,
        reduceEffects: true,
        dataSaver: false,
        isLowRamDevice: false,
        isBatterySaverEnabled: false,
        totalRam: 4096,
        androidSdkVersion: 34,
        isEmulator: false,
        performanceTier: DevicePerformanceTier.midRange,
        child: MaterialApp.router(
          theme: AppTheme.lightTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
  }

  testWidgets(
    'login create account link opens signup screen without router errors',
    (tester) async {
      final router = GoRouter(
        initialLocation: AppPaths.login,
        routes: [
          GoRoute(
            path: AppPaths.login,
            builder: (context, state) => const LoginScreen(),
          ),
          GoRoute(
            path: AppPaths.signup,
            builder: (context, state) => const SignupScreen(),
          ),
        ],
      );

      await tester.pumpWidget(buildTestApp(router));
      await tester.pumpAndSettle();

      final createAccountFinder = find.text('Create account');
      expect(createAccountFinder, findsOneWidget);

      await tester.ensureVisible(createAccountFinder);
      await tester.tap(createAccountFinder);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(SignupScreen), findsOneWidget);
      expect(router.routeInformationProvider.value.uri.path, AppPaths.signup);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('signup sign in link returns to login screen', (tester) async {
    final router = GoRouter(
      initialLocation: AppPaths.signup,
      routes: [
        GoRoute(
          path: AppPaths.login,
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: AppPaths.signup,
          builder: (context, state) => const SignupScreen(),
        ),
      ],
    );

    await tester.pumpWidget(buildTestApp(router));
    await tester.pumpAndSettle();

    final signInFinder = find.text('Sign in');
    expect(signInFinder, findsOneWidget);

    await tester.ensureVisible(signInFinder.first);
    await tester.tap(signInFinder.first);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, AppPaths.login);
    expect(tester.takeException(), isNull);
  });

  testWidgets('login waits for slow email auth instead of stale timeout', (
    tester,
  ) async {
    final auth = _SlowAuthFacade(
      loginDelay: const Duration(seconds: 16),
      googleDelay: Duration.zero,
    );
    final router = GoRouter(
      initialLocation: AppPaths.login,
      routes: [
        GoRoute(
          path: AppPaths.login,
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: AppPaths.home,
          builder: (context, state) => const Scaffold(body: Text('Home route')),
        ),
      ],
    );

    await tester.pumpWidget(buildTestApp(router, auth: auth));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'reader@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'password123');
    await tester.tap(find.text('Continue'));
    await tester.pump();

    await tester.pump(const Duration(seconds: 15));
    expect(find.textContaining('timed out'), findsNothing);
    expect(router.routeInformationProvider.value.uri.path, AppPaths.login);

    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(router.routeInformationProvider.value.uri.path, AppPaths.home);
    expect(find.text('Home route'), findsOneWidget);
  });

  testWidgets('login waits for slow Google auth instead of stale timeout', (
    tester,
  ) async {
    final auth = _SlowAuthFacade(
      loginDelay: Duration.zero,
      googleDelay: const Duration(seconds: 16),
    );
    final router = GoRouter(
      initialLocation: AppPaths.login,
      routes: [
        GoRoute(
          path: AppPaths.login,
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: AppPaths.home,
          builder: (context, state) => const Scaffold(body: Text('Home route')),
        ),
      ],
    );

    await tester.pumpWidget(buildTestApp(router, auth: auth));
    await tester.pumpAndSettle();

    final googleButtonText = find.text('Continue with Google');
    await tester.ensureVisible(googleButtonText);
    await tester.tap(googleButtonText);
    await tester.pump();

    await tester.pump(const Duration(seconds: 15));
    expect(find.textContaining('timed out'), findsNothing);
    expect(router.routeInformationProvider.value.uri.path, AppPaths.login);

    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(router.routeInformationProvider.value.uri.path, AppPaths.home);
    expect(find.text('Home route'), findsOneWidget);
  });

  testWidgets(
    'profile login shows verification recovery and resends verification email',
    (tester) async {
      final auth = _SlowAuthFacade(
        loginDelay: Duration.zero,
        googleDelay: Duration.zero,
        loginResults: const [
          'Please verify your email address before logging in. '
              'Check your inbox and spam folder, then try again.',
        ],
      );
      final router = GoRouter(
        initialLocation: AppPaths.login,
        routes: [
          GoRoute(
            path: AppPaths.login,
            builder: (context, state) => const LoginScreen(),
          ),
          GoRoute(
            path: AppPaths.home,
            builder: (context, state) =>
                const Scaffold(body: Text('Home route')),
          ),
        ],
      );

      await tester.pumpWidget(buildTestApp(router, auth: auth));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField).at(0),
        'reader@example.com',
      );
      await tester.enterText(find.byType(TextField).at(1), 'password123');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Verify your email'), findsOneWidget);
      expect(find.text('Resend verification email'), findsOneWidget);
      expect(find.text('I verified, try again'), findsOneWidget);
      expect(router.routeInformationProvider.value.uri.path, AppPaths.login);

      final resendFinder = find.text('Resend verification email');
      await tester.ensureVisible(resendFinder);
      await tester.pumpAndSettle();
      await tester.tap(resendFinder);
      await tester.pumpAndSettle();

      expect(auth.resendCalls, 1);
      expect(
        find.text('Verification email sent. Please check your inbox.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('profile login retries after email verification', (tester) async {
    final auth = _SlowAuthFacade(
      loginDelay: Duration.zero,
      googleDelay: Duration.zero,
      loginResults: const [
        'Please verify your email address before logging in. '
            'Check your inbox and spam folder, then try again.',
        null,
      ],
    );
    final router = GoRouter(
      initialLocation: AppPaths.login,
      routes: [
        GoRoute(
          path: AppPaths.login,
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: AppPaths.home,
          builder: (context, state) => const Scaffold(body: Text('Home route')),
        ),
      ],
    );

    await tester.pumpWidget(buildTestApp(router, auth: auth));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'reader@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'password123');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    final retryFinder = find.text('I verified, try again');
    await tester.ensureVisible(retryFinder);
    await tester.pumpAndSettle();
    await tester.tap(retryFinder);
    await tester.pumpAndSettle();

    expect(auth.loginCalls, 2);
    expect(router.routeInformationProvider.value.uri.path, AppPaths.home);
    expect(find.text('Home route'), findsOneWidget);
  });

  testWidgets(
    'simple login surface shows verification recovery and resends email',
    (tester) async {
      final auth = _SlowAuthFacade(
        loginDelay: Duration.zero,
        googleDelay: Duration.zero,
        loginResults: const [
          'Please verify your email address before logging in. '
              'Check your inbox and spam folder, then try again.',
        ],
      );
      final router = GoRouter(
        initialLocation: AppPaths.login,
        routes: [
          GoRoute(
            path: AppPaths.login,
            builder: (context, state) => const simple_login.LoginScreen(),
          ),
          GoRoute(
            path: AppPaths.home,
            builder: (context, state) =>
                const Scaffold(body: Text('Home route')),
          ),
        ],
      );

      await tester.pumpWidget(buildTestApp(router, auth: auth));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField).at(0),
        'reader@example.com',
      );
      await tester.enterText(find.byType(TextField).at(1), 'password123');
      await tester.tap(find.byType(ElevatedButton).first);
      await tester.pumpAndSettle();

      expect(find.text('Verify your email'), findsOneWidget);
      expect(find.text('Resend verification email'), findsOneWidget);

      await tester.tap(find.text('Resend verification email'));
      await tester.pumpAndSettle();

      expect(auth.resendCalls, 1);
      expect(
        find.text('Verification email sent. Please check your inbox.'),
        findsOneWidget,
      );
    },
  );
}

class _SlowAuthFacade implements AuthFacade {
  _SlowAuthFacade({
    required this.loginDelay,
    required this.googleDelay,
    List<String?>? loginResults,
  }) : _loginResults = List<String?>.of(loginResults ?? const [null]);

  final Duration loginDelay;
  final Duration googleDelay;
  final List<String?> _loginResults;
  int loginCalls = 0;
  int resendCalls = 0;

  @override
  User? get currentUser => null;

  @override
  bool get isLoggedIn => false;

  @override
  Future<void> init() async {}

  @override
  Future<String?> signUp(String name, String email, String password) async =>
      null;

  @override
  Future<String?> login(String email, String password) async {
    loginCalls++;
    await Future<void>.delayed(loginDelay);
    if (_loginResults.isEmpty) {
      return null;
    }
    return _loginResults.removeAt(0);
  }

  @override
  Future<String?> resendEmailVerification(String email, String password) async {
    resendCalls++;
    return null;
  }

  @override
  Future<String?> signInWithGoogle() async {
    await Future<void>.delayed(googleDelay);
    return null;
  }

  @override
  Future<void> logout() async {}

  @override
  Future<String?> resetPassword(String email) async => null;

  @override
  Future<bool> hasUsedTrial() async => false;

  @override
  Future<void> markTrialUsed({
    required DateTime startedAt,
    required DateTime endsAt,
  }) async {}

  @override
  Future<Map<String, String>> getProfile() async => const <String, String>{};

  @override
  Future<void> updateProfile({
    required String name,
    required String email,
    String phone = '',
    String role = '',
    String department = '',
    String imagePath = '',
  }) async {}
}
