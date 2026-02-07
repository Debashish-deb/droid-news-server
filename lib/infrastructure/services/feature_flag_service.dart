import 'remote_config_service.dart';
import 'package:injectable/injectable.dart';

/// Centralized service for feature flags and remote configuration.
@lazySingleton
class FeatureFlagService {

  FeatureFlagService(this._remoteConfig);
  final RemoteConfigService _remoteConfig;

  RemoteConfigService get remoteConfig => _remoteConfig;

  /// Returns true if a specific feature is enabled.
  bool isEnabled(String featureKey) {
    try {
      return _remoteConfig.getBool(featureKey);
    } catch (_) {
      return _getDefaultBool(featureKey);
    }
  }

  /// Gets a remote value with a local fallback.
  String getValue(String key, String fallback) {
    try {
      final value = _remoteConfig.getString(key);
      return value.isNotEmpty ? value : fallback;
    } catch (_) {
      return fallback;
    }
  }

  bool _getDefaultBool(String key) {
    const defaults = {
      'enable_smart_feed': true,
      'enable_tts': true,
      'enable_offline_mode': true,
      'kill_switch_enabled': false,
    };
    return defaults[key] ?? false;
  }
}
