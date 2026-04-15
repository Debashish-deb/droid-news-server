import 'package:bdnewsreader/core/services/splash_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('returns splash as initial hint on Android', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      SplashService.onboardingCompletedKey: true,
      SplashService.isLoggedInKey: true,
    });
    final prefs = await SharedPreferences.getInstance();
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    final service = SplashService(prefs: prefs);

    expect(service.resolveInitialRouteHint(), '/splash');
  });

  test('returns cached home hint off Android when logged in', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      SplashService.onboardingCompletedKey: true,
      SplashService.isLoggedInKey: true,
    });
    final prefs = await SharedPreferences.getInstance();
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    final service = SplashService(prefs: prefs);

    expect(service.resolveInitialRouteHint(), '/home');
  });
}
