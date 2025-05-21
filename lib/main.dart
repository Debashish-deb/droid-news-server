import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/app_paths.dart';
import 'core/routes.dart';
import 'core/splash_service.dart';
import 'core/theme.dart';
import 'core/theme_provider.dart';
import 'core/language_provider.dart';
import 'core/premium_service.dart';
import 'l10n/app_localizations.dart';
import 'firebase_options.dart';

late final PremiumService premiumService;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await MobileAds.instance.initialize();

  final prefs = await SharedPreferences.getInstance();

  // Initialize services before runApp
  premiumService = PremiumService(prefs: prefs);
  await premiumService.loadStatus();

  final initialRoute = await SplashService(prefs: prefs).resolveInitialRoute();

  runApp(MyApp(initialRoute: initialRoute));
}

class MyApp extends StatelessWidget {
  final String initialRoute;
  const MyApp({Key? key, required this.initialRoute}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final router = AppRouter.createRouter(initialLocation: initialRoute);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => premiumService),
      ],
      child: Consumer3<ThemeProvider, LanguageProvider, PremiumService>(
        builder: (ctx, themeProv, langProv, premium, _) {
          return MaterialApp.router(
            title: dotenv.env['APP_NAME'] ?? 'BD News Reader',
            theme: AppTheme.buildLightTheme(),
            darkTheme: AppTheme.buildDarkTheme(),
            themeMode: themeProv.themeMode,
            locale: langProv.locale,
            supportedLocales: const [Locale('en'), Locale('bn')],
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            routerConfig: router,
          );
        },
      ),
    );
  }
}
