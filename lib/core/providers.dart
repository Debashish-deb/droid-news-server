import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../bootstrap/di/injection_container.dart' show sl;
import 'security/secure_prefs.dart';
import 'security/security_service.dart';
import 'network_quality_manager.dart';
import '../infrastructure/network/app_network_service.dart';
import '../infrastructure/services/remote_config_service.dart';
import 'resilience/resilience_service.dart';
import 'enums/device_trust_state.dart';
import 'telemetry/observability_service.dart';
import 'errors/security_exception.dart';
import 'security/device_trust_notifier.dart';
import '../application/identity/device_trust_service.dart';

// —————————————————————————————————————————————————————————————————————————————
// 1. External/Third-Party Services
// —————————————————————————————————————————————————————————————————————————————

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden in main.dart');
});

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  guardTrusted(ref);
  return FirebaseAuth.instance;
});

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  guardTrusted(ref);
  return FirebaseFirestore.instance;
});

// —————————————————————————————————————————————————————————————————————————————
// 2. Core Infrastructure (Singletons)
// —————————————————————————————————————————————————————————————————————————————

final securePrefsProvider = Provider<SecurePrefs>((ref) {
  return sl<SecurePrefs>();
});

final securityServiceProvider = Provider<SecurityService>((ref) {
  return SecurityService();
});

final deviceTrustServiceProvider = Provider<DeviceTrustService>((ref) {
  return DeviceTrustService(security: ref.watch(securityServiceProvider));
});

final deviceTrustControllerProvider = StateNotifierProvider<DeviceTrustNotifier, DeviceTrustState>((ref) {
  return DeviceTrustNotifier(ref.watch(deviceTrustServiceProvider));
});



final deviceTrustStateProvider = Provider<DeviceTrustState>((ref) {
  return ref.watch(deviceTrustControllerProvider);
});

void guardTrusted(Ref ref) {
  final state = ref.read(deviceTrustStateProvider);
  
  // In debug mode, allow restricted state for development
  if (kDebugMode) {
    if (state != DeviceTrustState.trusted && state != DeviceTrustState.restricted) {
      throw const SecurityException('Device is not in a trusted or restricted state. Access denied.');
    }
  } else {
    // Production: strict trusted-only requirement
    if (state != DeviceTrustState.trusted) {
      throw const SecurityException('Device is not trusted. Access denied.');
    }
  }
}

final networkQualityProvider = Provider<NetworkQualityManager>((ref) {
  return NetworkQualityManager();
});

final appNetworkServiceProvider = Provider<AppNetworkService>((ref) {
  return sl<AppNetworkService>();
});

// Remote Config (needs initialization)
final remoteConfigProvider = FutureProvider<RemoteConfigService>((ref) async {
  final service = RemoteConfigService();
  await service.initialize();
  return service;
});

final observabilityProvider = Provider<ObservabilityService>((ref) {
  return sl<ObservabilityService>();
});

final resilienceProvider = Provider<ResilienceService>((ref) {
  guardTrusted(ref);
  return sl<ResilienceService>();
});
