import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import 'device_registry.dart';

import 'package:injectable/injectable.dart';

@LazySingleton(as: DeviceRegistry)
class DeviceRegistryImpl implements DeviceRegistry {

  DeviceRegistryImpl(
    this._deviceInfo,
    this._storage,
  );
  final DeviceInfoPlugin _deviceInfo;
  final FlutterSecureStorage _storage;
  
  static const String _deviceIdKey = 'platform_device_id';

  @override
  Future<String> getDeviceId() async {
    // 1. Try to read from Secure Storage
    final String? storedId = await _storage.read(key: _deviceIdKey);
    if (storedId != null) return storedId;

    // 2. If not found, generate a unified ID
    final String newId = await _generateFingerprint();
    
    // 3. Persist it
    await _storage.write(key: _deviceIdKey, value: newId);
    return newId;
  }

  @override
  Future<DeviceIntegrity> bindDevice(String userId) async {
    final deviceId = await getDeviceId();
    
    // Simulate backend registration call
    debugPrint('🌐 REGISTERING DEVICE: /v1/identity/devices/bind [Device: $deviceId, User: $userId]');
    await Future<void>.delayed(const Duration(milliseconds: 800)); // Simulated latency
    
    final bool isRealDevice = await _isRealDevice();
    final bool isRooted = await _checkRootStatus();
    
    return DeviceIntegrity(
      deviceId: deviceId,
      isRooted: isRooted,
      isEmulator: !isRealDevice,
      trustScore: (isRealDevice && !isRooted) ? 1.0 : 0.4,
      lastVerifiedAt: DateTime.now(),
    );
  }

  Future<bool> _checkRootStatus() async {
    // Industrial check: Search for common root/jailbreak binaries
    // In a production app, we would use 'safe_device' or 'flutter_jailbreak_detection'
    // For this implementation, we simulate detection based on platform-specific signals.
    if (Platform.isAndroid) {
      final paths = [
        '/system/app/Superuser.apk',
        '/sbin/su',
        '/system/bin/su',
        '/system/xbin/su',
        '/data/local/xbin/su',
        '/data/local/bin/su',
        '/system/sd/xbin/su',
        '/system/bin/failsafe/su',
        '/data/local/su'
      ];
      for (var path in paths) {
        if (File(path).existsSync()) return true;
      }
    }
    return false;
  }

  @override
  Future<bool> verifyDevice(String deviceId) async {
    final currentId = await getDeviceId();
    return currentId == deviceId;
  }

  Future<String> _generateFingerprint() async {
    if (Platform.isAndroid) {
      final androidInfo = await _deviceInfo.androidInfo;
      return const Uuid().v5(Uuid.NAMESPACE_URL, '${androidInfo.id}-${androidInfo.model}-${androidInfo.manufacturer}');
    } else if (Platform.isIOS) {
      final iosInfo = await _deviceInfo.iosInfo;
      return iosInfo.identifierForVendor ?? const Uuid().v4();
    }
    return const Uuid().v4();
  }
  
  Future<bool> _isRealDevice() async {
     if (Platform.isAndroid) {
      final androidInfo = await _deviceInfo.androidInfo;
      return androidInfo.isPhysicalDevice;
    } else if (Platform.isIOS) {
      final iosInfo = await _deviceInfo.iosInfo;
      return iosInfo.isPhysicalDevice;
    }
    return false;
  }
}
