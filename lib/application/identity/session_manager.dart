// lib/application/identity/session_manager.dart

import 'package:flutter/foundation.dart';
import '../../domain/facades/auth_facade.dart';
import '../../infrastructure/services/remote_config_service.dart';
import 'device_trust_service.dart';

// Managed state for user sessions, security thresholds, and kill switches.
class SessionManager {

  SessionManager({
    required AuthFacade auth,
    DeviceTrustService? trust,
    RemoteConfigService? remoteConfig,
  })  : _auth = auth,
        _trust = trust ?? DeviceTrustService(),
        _remoteConfig = remoteConfig ?? RemoteConfigService();
  final AuthFacade _auth;
  final DeviceTrustService _trust;
  final RemoteConfigService _remoteConfig;

  Future<bool> validateSession() async {
    final bool isAppDisabled = _remoteConfig.getBool('kill_switch_enabled');
    if (isAppDisabled) {
      debugPrint('🚨 GLOBAL KILL SWITCH TRIGGERED');
      return false;
    }

    final double trustScore = await _trust.calculateTrustScore();
    final double minTrust = _remoteConfig.getDouble('min_device_trust_score');
    
    final EffectiveMinTrust = minTrust > 0 ? minTrust : 0.4;

    if (trustScore < EffectiveMinTrust) {
      debugPrint('🚨 DEVICE TRUST SCORE TOO LOW: $trustScore < $EffectiveMinTrust');
      return false;
    }

    if (!_auth.isLoggedIn) {
      return false;
    }

    return true;
  }

  Future<void> terminateSession() async {
    await _auth.logout();
  }

  Future<Map<String, dynamic>> getSecurityStatus() async {
    return {
      'trust_score': await _trust.calculateTrustScore(),
      'is_logged_in': _auth.isLoggedIn,
      'is_kill_switch_active': _remoteConfig.getBool('kill_switch_enabled'),
    };
  }
}
