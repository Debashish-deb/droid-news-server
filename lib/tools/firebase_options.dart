// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart'
    show Firebase, FirebaseApp, FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter_dotenv/flutter_dotenv.dart';

String? _dotenvValue(String key) {
  try {
    if (!dotenv.isInitialized) return null;
    return dotenv.env[key];
  } catch (_) {
    return null;
  }
}

String? _configuredValue(String key) {
  final value = _dotenvValue(key)?.trim();
  if (value == null || value.isEmpty) return null;

  final upper = value.toUpperCase();
  if (upper.startsWith('YOUR_') || upper.startsWith('MISSING_')) {
    return null;
  }

  return value;
}

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// / ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static FirebaseOptions? get currentPlatformOrNull {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return _hasConfiguredAndroid ? android : null;
      case TargetPlatform.iOS:
        return _hasConfiguredIos ? ios : null;
      case TargetPlatform.macOS:
        return _hasConfiguredMacos ? macos : null;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        return null;
      default:
        return null;
    }
  }

  static Future<FirebaseApp> initializeApp() {
    final options = currentPlatformOrNull;
    if (options == null) {
      return Firebase.initializeApp();
    }
    return Firebase.initializeApp(options: options);
  }

  static bool get _hasConfiguredAndroid =>
      _configuredValue('FIREBASE_API_KEY_ANDROID') != null &&
      _configuredValue('FIREBASE_APP_ID_ANDROID') != null &&
      _configuredValue('FIREBASE_MESSAGING_SENDER_ID') != null;

  static bool get _hasConfiguredIos =>
      _configuredValue('FIREBASE_API_KEY_IOS') != null &&
      _configuredValue('FIREBASE_APP_ID_IOS') != null &&
      _configuredValue('FIREBASE_MESSAGING_SENDER_ID') != null;

  static bool get _hasConfiguredMacos => _hasConfiguredIos;

  static FirebaseOptions get web => FirebaseOptions(
    apiKey: _configuredValue('FIREBASE_API_KEY_WEB') ?? 'MISSING_WEB_API_KEY',
    appId: _configuredValue('FIREBASE_APP_ID_WEB') ?? 'MISSING_WEB_APP_ID',
    messagingSenderId:
        _configuredValue('FIREBASE_MESSAGING_SENDER_ID') ??
        'MISSING_SENDER_ID',
    projectId: _configuredValue('FIREBASE_PROJECT_ID') ?? 'bd-news-reader',
    authDomain: _configuredValue('FIREBASE_AUTH_DOMAIN'),
    storageBucket: _configuredValue('FIREBASE_STORAGE_BUCKET'),
    measurementId: _configuredValue('FIREBASE_MEASUREMENT_ID'),
  );

  static FirebaseOptions get android => FirebaseOptions(
    apiKey:
        _configuredValue('FIREBASE_API_KEY_ANDROID') ??
        'MISSING_ANDROID_API_KEY',
    appId:
        _configuredValue('FIREBASE_APP_ID_ANDROID') ??
        'MISSING_ANDROID_APP_ID',
    messagingSenderId:
        _configuredValue('FIREBASE_MESSAGING_SENDER_ID') ??
        'MISSING_SENDER_ID',
    projectId: _configuredValue('FIREBASE_PROJECT_ID') ?? 'bd-news-reader',
    storageBucket: _configuredValue('FIREBASE_STORAGE_BUCKET'),
  );

  static FirebaseOptions get ios => FirebaseOptions(
    apiKey: _configuredValue('FIREBASE_API_KEY_IOS') ?? 'MISSING_IOS_API_KEY',
    appId: _configuredValue('FIREBASE_APP_ID_IOS') ?? 'MISSING_IOS_APP_ID',
    messagingSenderId:
        _configuredValue('FIREBASE_MESSAGING_SENDER_ID') ??
        'MISSING_SENDER_ID',
    projectId: _configuredValue('FIREBASE_PROJECT_ID') ?? 'bd-news-reader',
    storageBucket: _configuredValue('FIREBASE_STORAGE_BUCKET'),
    androidClientId: _configuredValue('FIREBASE_ANDROID_CLIENT_ID'),
    iosClientId: _configuredValue('FIREBASE_IOS_CLIENT_ID'),
    iosBundleId:
        _configuredValue('FIREBASE_IOS_BUNDLE_ID') ?? 'com.bd.bdnewsreader',
  );

  static FirebaseOptions get macos => FirebaseOptions(
    apiKey: _configuredValue('FIREBASE_API_KEY_IOS') ?? 'MISSING_MACOS_API_KEY',
    appId: _configuredValue('FIREBASE_APP_ID_IOS') ?? 'MISSING_MACOS_APP_ID',
    messagingSenderId:
        _configuredValue('FIREBASE_MESSAGING_SENDER_ID') ??
        'MISSING_SENDER_ID',
    projectId: _configuredValue('FIREBASE_PROJECT_ID') ?? 'bd-news-reader',
    storageBucket: _configuredValue('FIREBASE_STORAGE_BUCKET'),
    androidClientId: _configuredValue('FIREBASE_ANDROID_CLIENT_ID'),
    iosClientId: _configuredValue('FIREBASE_IOS_CLIENT_ID'),
    iosBundleId: _configuredValue('FIREBASE_IOS_BUNDLE_ID'),
  );

  static FirebaseOptions get windows => FirebaseOptions(
    apiKey:
        _configuredValue('FIREBASE_API_KEY_WEB') ?? 'MISSING_WINDOWS_API_KEY',
    appId:
        _configuredValue('FIREBASE_APP_ID_WEB') ?? 'MISSING_WINDOWS_APP_ID',
    messagingSenderId:
        _configuredValue('FIREBASE_MESSAGING_SENDER_ID') ??
        'MISSING_SENDER_ID',
    projectId: _configuredValue('FIREBASE_PROJECT_ID') ?? 'bd-news-reader',
    authDomain: _configuredValue('FIREBASE_AUTH_DOMAIN'),
    storageBucket: _configuredValue('FIREBASE_STORAGE_BUCKET'),
    measurementId: _configuredValue('FIREBASE_MEASUREMENT_ID'),
  );
}
