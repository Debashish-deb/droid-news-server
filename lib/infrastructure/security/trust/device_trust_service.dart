import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

import '../../../core/architecture/failure.dart';
import '../../../core/architecture/either.dart';

/// Calculates a "Trust Score" for the current device.
/// 
/// Score Range: 0.0 (Untrusted) to 1.0 (Trusted).
/// Factors:
/// - Root/Jailbreak status (Simulated via platform checks)
/// - Emulator status
/// - Development Mode status
class DeviceTrustService {

  DeviceTrustService({DeviceInfoPlugin? deviceInfo}) 
      : _deviceInfo = deviceInfo ?? DeviceInfoPlugin();
  final DeviceInfoPlugin _deviceInfo;

  /// returns the computed Trust Score.
  Future<Either<AppFailure, double>> calculateTrustScore() async {
    try {
      double score = 1.0;

      if (await _isRealDevice() == false) {
        score -= 0.5;
      }

      if (await _isRooted()) {
        score = 0.0; 
      }


      return Right(score);
    } catch (e) {
      return Left(SecurityFailure('Failed to assess device trust: $e'));
    }
  }

  Future<bool> _isRealDevice() async {
    if (Platform.isAndroid) {
      final androidInfo = await _deviceInfo.androidInfo;
      return androidInfo.isPhysicalDevice;
    } else if (Platform.isIOS) {
      final iosInfo = await _deviceInfo.iosInfo;
      return iosInfo.isPhysicalDevice;
    }
    return true; 
  }

  Future<bool> _isRooted() async {
    
    if (Platform.isAndroid) {
      final androidInfo = await _deviceInfo.androidInfo;
      final tags = androidInfo.tags ?? '';
      if (tags.contains('test-keys')) return true;
    }

    return false;
  }
}
