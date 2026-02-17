// lib/application/identity/device_trust_service.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../core/security/security_service.dart';
import '../../core/telemetry/structured_logger.dart';
import 'package:device_info_plus/device_info_plus.dart';

// Service to aggregate security signals and calculate a Device Trust Score.
// Score ranges from 0.0 (Untrusted) to 1.0 (Fully Trusted).
class DeviceTrustService {

  DeviceTrustService({SecurityService? security, StructuredLogger? logger})
      : _security = security ?? SecurityService(logger ?? StructuredLogger());
  final SecurityService _security;
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  Future<double> calculateTrustScore() async {
    double score = 1.0;

    final bool isRooted = await _security.getIsRooted();
    if (isRooted) {
      score -= 0.6;
    }

    if (!kDebugMode) {
      if (!await _security.getIsDeviceSecure()) {
        score -= 0.2;
      }
    }

    final bool isEmulator = await _checkIfEmulator();
    if (isEmulator) {
      score -= 0.3;
    }

    return score.clamp(0.0, 1.0);
  }

  Future<Map<String, dynamic>> getTrustReport() async {
    return {
      'score': await calculateTrustScore(),
      'is_rooted': await _security.getIsRooted(),
      'is_emulator': await _checkIfEmulator(),
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  Future<bool> _checkIfEmulator() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        return !androidInfo.isPhysicalDevice;
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        return !iosInfo.isPhysicalDevice;
      }
    } catch (e) {
      debugPrint('Error checking emulator status: $e');
    }
    return false;
  }
}
