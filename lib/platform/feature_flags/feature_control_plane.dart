
import '../../infrastructure/services/remote_config_service.dart';

enum FeatureStatus {
  enabled,
  disabled,
  rollout, // Partial rollout based on user ID hashing
  killSwitch // Emergency disable
}

class FeatureDefinition { // Team owning this feature

  const FeatureDefinition({
    required this.key,
    required this.description, this.defaultStatus = FeatureStatus.disabled,
    this.owner,
  });
  final String key;
  final FeatureStatus defaultStatus;
  final String description;
  final String? owner;
}

class FeatureControlPlane {

  FeatureControlPlane(this._remoteConfig);
  final RemoteConfigService _remoteConfig;

  bool isEnabled(String featureKey, {String? userId}) {
    // 1. Check for emergency Kill Switch first
    if (_isKillSwitched(featureKey)) {
      return false;
    }

    // 2. Check Remote Config value
    // We assume RemoteConfig returns simple bools or strings indicating status
    // For this implementation, we map a string value from remote config to status
    final String configValue = _remoteConfig.getString(featureKey);
    
    if (configValue == 'true' || configValue == 'enabled') return true;
    if (configValue == 'false' || configValue == 'disabled') return false;
    
    // 3. Handle Percentage Rollouts
    if (configValue.startsWith('rollout:')) {
      final percentage = int.tryParse(configValue.split(':')[1]) ?? 0;
      return _evaluateRollout(userId, percentage);
    }

    return false; // Default safe
  }

  bool _isKillSwitched(String featureKey) {
    return _remoteConfig.getBool('killswitch_$featureKey');
  }

  bool _evaluateRollout(String? userId, int percentage) {
    if (userId == null) return false;
    // Simple stable hash bucket logic: 0-99
    final hash = userId.hashCode.abs() % 100;
    return hash < percentage;
  }
}
