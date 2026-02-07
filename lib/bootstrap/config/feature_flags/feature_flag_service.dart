import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'app_features.dart';

/// Interface for feature flag service to allow mocking in tests.
abstract class IFeatureFlagService {
  Future<void> initialize();
  bool isEnabled(AppFeatures feature);
  String getString(AppFeatures feature);
  int getInt(AppFeatures feature);
  double getDouble(AppFeatures feature);
}

/// Concrete implementation of [IFeatureFlagService] using Firebase Remote Config.
class FeatureFlagService implements IFeatureFlagService {

  FeatureFlagService({FirebaseRemoteConfig? remoteConfig})
      : _remoteConfig = remoteConfig ?? FirebaseRemoteConfig.instance;
  final FirebaseRemoteConfig _remoteConfig;

  @override
  Future<void> initialize() async {
    try {
      await _remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(minutes: 1),
        minimumFetchInterval: kDebugMode 
            ? const Duration(minutes: 5) 
            : const Duration(hours: 12),
      ));

      await _remoteConfig.setDefaults({
        AppFeatures.enable_news_threading.key: false,
        AppFeatures.enable_smart_ranking.key: false,
        AppFeatures.enable_perf_monitoring.key: false,
        AppFeatures.enable_ads.key: true,
        AppFeatures.enable_new_magazine_ui.key: true,
      });

      await _remoteConfig.fetchAndActivate();
      debugPrint('✅ FeatureFlagService: Initialized successfully.');
    } catch (e) {
      debugPrint('⚠️ FeatureFlagService: Initialization failed ($e). Using defaults.');
    }
  }

  @override
  bool isEnabled(AppFeatures feature) {
    return _remoteConfig.getBool(feature.key);
  }

  @override
  String getString(AppFeatures feature) {
    return _remoteConfig.getString(feature.key);
  }

  @override
  int getInt(AppFeatures feature) {
    return _remoteConfig.getInt(feature.key);
  }

  @override
  double getDouble(AppFeatures feature) {
    return _remoteConfig.getDouble(feature.key);
  }
}
