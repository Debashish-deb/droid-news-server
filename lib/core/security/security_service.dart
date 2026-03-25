import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'root_detector.dart';

/// Comprehensive security service providing hashing,
/// HMAC, secure storage, and device security checks.
class SecurityService {
  SecurityService();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  static const _channel = MethodChannel('com.bdnews/security');

  bool _isInitialized = false;
  bool _isSecure = true;
  bool _isRooted = false;

  // ─── Getters ───────────────────────────────────────────────────────────────

  bool get isInitialized => _isInitialized;
  bool get isSecure => _isSecure;
  bool get isDeviceSecure => _isSecure;
  bool get isRooted => _isRooted;

  // ─── Initialization ────────────────────────────────────────────────────────

  Future<void> initialize() async {
    try {
      _isRooted = await getIsRooted();
      _isSecure = await getIsDeviceSecure();

      if (kDebugMode || kProfileMode) {
        debugPrint(
          '🔐 SecurityService: isRooted=$_isRooted, isSecure=$_isSecure (isPhysicalDevice=${!_isSecure})',
        );
      }

      // Keep debug builds inspectable in Android Studio.
      if (kDebugMode) {
        await disableSecureFlag();
      } else {
        await enableSecureFlag();
      }

      _isInitialized = true;
    } catch (e) {
      if (kDebugMode) debugPrint('🔐 SecurityService init error: $e');
      // ✅ FIXED: Don't just fail open. If init fails, we assume unsecure/rooted.
      _isRooted = true;
      _isSecure = false;
      _isInitialized = true;
    }
  }

  // ─── Device Security Checks ────────────────────────────────────────────────

  Future<bool> getIsDeviceSecure() async {
    try {
      // Basic check: is the device physically capable of basic security?
      return !await _isEmulator();
    } catch (e) {
      if (kDebugMode) debugPrint('🔐 Device secure check failed: $e');
      return false; // ✅ FIXED: Fail closed on error
    }
  }

  Future<bool> getIsRooted() async {
    try {
      // ✅ FIXED: Consistently use the robust RootDetector
      final status = await RootDetector.detect();
      return status.isRooted;
    } catch (e) {
      if (kDebugMode) debugPrint('🔐 Root detection error: $e');
      return true; // ✅ FIXED: Fail closed on error
    }
  }

  Future<bool> _isEmulator() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        return androidInfo.isPhysicalDevice == false ||
            androidInfo.fingerprint.contains("generic") ||
            androidInfo.fingerprint.contains("unknown") ||
            androidInfo.model.contains("google_sdk") ||
            androidInfo.model.contains("Emulator") ||
            androidInfo.model.contains("Android SDK built for x86") ||
            androidInfo.manufacturer.contains("Genymotion") ||
            androidInfo.product.contains("sdk_google") ||
            androidInfo.product.contains("google_sdk") ||
            androidInfo.product.contains("sdk") ||
            androidInfo.product.contains("sdk_x86") ||
            androidInfo.product.contains("vbox86p") ||
            androidInfo.product.contains("emulator") ||
            androidInfo.product.contains("simulator");
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        return iosInfo.isPhysicalDevice == false;
      }
      return false;
    } catch (e) {
      return true; // Assume emulator on error for safety
    }
  }

  // ─── Native Security Features ──────────────────────────────────────────────

  /// Enables the platform's secure flag (prevents screenshots/screen recording)
  Future<void> enableSecureFlag() async {
    try {
      await _channel.invokeMethod('enableSecureFlag');
    } catch (e) {
      if (kDebugMode) debugPrint('🔐 Failed to enable secure flag: $e');
    }
  }

  /// Disables the platform's secure flag
  Future<void> disableSecureFlag() async {
    try {
      await _channel.invokeMethod('disableSecureFlag');
    } catch (e) {
      if (kDebugMode) debugPrint('🔐 Failed to disable secure flag: $e');
    }
  }

  /// Gets monotonic time in milliseconds from the platform
  Future<int?> getMonotonicTime() async {
    try {
      final int? time = await _channel.invokeMethod<int>('getMonotonicTime');
      return time;
    } catch (e) {
      if (kDebugMode) debugPrint('🔐 Failed to get monotonic time: $e');
      return null;
    }
  }

  // ─── Hashing ───────────────────────────────────────────────────────────────

  String hashString(String input) {
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }

  // ─── HMAC ──────────────────────────────────────────────────────────────────

  String generateHmac(String data, String key) {
    final keyBytes = utf8.encode(key);
    final dataBytes = utf8.encode(data);
    final hmac = Hmac(sha256, keyBytes);
    return hmac.convert(dataBytes).toString();
  }

  /// Verifies HMAC using **constant-time comparison** to prevent timing attacks.
  bool verifyHmac(String data, String expectedHmac, String key) {
    final computed = generateHmac(data, key);
    return _constantTimeEquals(computed, expectedHmac);
  }

  /// Constant-time string comparison that always evaluates all bytes,
  /// preventing timing side-channel attacks on HMAC verification.
  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }

  // ─── Secure Storage ────────────────────────────────────────────────────────

  Future<void> secureWrite(String key, String value) async {
    await _secureStorage.write(key: key, value: value);
  }

  Future<String?> secureRead(String key) async {
    return await _secureStorage.read(key: key);
  }

  Future<void> secureDelete(String key) async {
    await _secureStorage.delete(key: key);
  }
}
