// lib/core/security/security_service.dart
// ========================================
// COMPREHENSIVE APP SECURITY SERVICE
// ========================================

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

/// Centralized security service for the app.
class SecurityService {
  factory SecurityService() => _instance;
  SecurityService._internal();
  static final SecurityService _instance = SecurityService._internal();

  // Secure storage instance with extra protection
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      keyCipherAlgorithm:
          KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
      storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  final LocalAuthentication _localAuth = LocalAuthentication();

  bool _isSecurityInitialized = false;
  bool _isDeviceSecure = true;

  // ========================================
  // INITIALIZATION
  // ========================================
  Future<void> initialize() async {
    if (_isSecurityInitialized) return;

    // Run security checks
    await _performSecurityChecks();

    _isSecurityInitialized = true;
    if (kDebugMode) debugPrint('🔐 Security Service Initialized');
  }

  // ========================================
  // SECURITY CHECKS
  // ========================================
  Future<void> _performSecurityChecks() async {
    // 1. Check for rooted/jailbroken device
    final bool isRooted = await _checkRootStatus();
    if (isRooted) {
      if (kDebugMode) {
        debugPrint('⚠️ WARNING: Device appears to be rooted/jailbroken');
      }
      _isDeviceSecure = false;
    }

    // 2. Check for debugger attached (release mode only)
    if (!kDebugMode && _isDebuggerAttached()) {
      if (kDebugMode) {
        debugPrint('⚠️ WARNING: Debugger detected in release mode');
      }
      _isDeviceSecure = false;
    }

    // 3. Check for hook frameworks
    if (await _checkForHooks()) {
      if (kDebugMode) debugPrint('⚠️ WARNING: Hooking framework detected');
      _isDeviceSecure = false;
    }
  }

  /// Check if device is rooted (Android) or jailbroken (iOS)
  Future<bool> _checkRootStatus() async {
    if (Platform.isAndroid) {
      return await _checkAndroidRoot();
    } else if (Platform.isIOS) {
      return await _checkiOSJailbreak();
    }
    return false;
  }

  Future<bool> _checkAndroidRoot() async {
    // Check for common root indicators
    final List<String> rootPaths = <String>[
      '/system/app/Superuser.apk',
      '/sbin/su',
      '/system/bin/su',
      '/system/xbin/su',
      '/data/local/xbin/su',
      '/data/local/bin/su',
      '/system/sd/xbin/su',
      '/system/bin/failsafe/su',
      '/data/local/su',
      '/su/bin/su',
      '/data/adb/magisk',
    ];

    for (final String path in rootPaths) {
      if (await File(path).exists()) {
        return true;
      }
    }

    // Check for root management apps
    try {
      final ProcessResult result = await Process.run('which', <String>['su']);
      if (result.exitCode == 0) return true;
    } catch (_) {}

    return false;
  }

  Future<bool> _checkiOSJailbreak() async {
    // Check for common jailbreak paths
    final List<String> jailbreakPaths = <String>[
      '/Applications/Cydia.app',
      '/Library/MobileSubstrate/MobileSubstrate.dylib',
      '/bin/bash',
      '/usr/sbin/sshd',
      '/etc/apt',
      '/private/var/lib/apt/',
      '/usr/bin/ssh',
    ];

    for (final String path in jailbreakPaths) {
      if (await File(path).exists()) {
        return true;
      }
    }

    // Try to write outside sandbox
    try {
      final File testFile = File('/private/jailbreak_test.txt');
      await testFile.writeAsString('test');
      await testFile.delete();
      return true; // If we can write here, device is jailbroken
    } catch (_) {
      return false; // Expected failure on non-jailbroken devices
    }
  }

  bool _isDebuggerAttached() {
    // Check if running with debugger in release mode
    bool inDebugMode = false;
    assert(() {
      inDebugMode = true;
      return true;
    }());
    return inDebugMode && !kDebugMode;
  }

  Future<bool> _checkForHooks() async {
    if (Platform.isAndroid) {
      // Check for Frida, Xposed, etc.
      final List<String> hookIndicators = <String>[
        '/data/local/tmp/frida-server',
        '/data/data/de.robv.android.xposed.installer',
        '/data/data/com.saurik.substrate',
      ];

      for (final String path in hookIndicators) {
        if (await File(path).exists()) {
          return true;
        }
      }
    }
    return false;
  }

  // ========================================
  // SECURE STORAGE
  // ========================================

  /// Store sensitive data securely
  Future<void> secureWrite(String key, String value) async {
    try {
      await _secureStorage.write(key: key, value: value);
    } catch (e) {
      if (kDebugMode) debugPrint('🔐 Secure write failed: $e');
    }
  }

  /// Read sensitive data securely
  Future<String?> secureRead(String key) async {
    try {
      return await _secureStorage.read(key: key);
    } catch (e) {
      if (kDebugMode) debugPrint('🔐 Secure read failed: $e');
      return null;
    }
  }

  /// Delete sensitive data
  Future<void> secureDelete(String key) async {
    try {
      await _secureStorage.delete(key: key);
    } catch (e) {
      if (kDebugMode) debugPrint('🔐 Secure delete failed: $e');
    }
  }

  /// Clear all secure storage
  Future<void> secureClearAll() async {
    try {
      await _secureStorage.deleteAll();
    } catch (e) {
      if (kDebugMode) debugPrint('🔐 Secure clear failed: $e');
    }
  }

  // ========================================
  // BIOMETRIC AUTHENTICATION
  // ========================================

  /// Check if device supports biometrics
  Future<bool> canUseBiometrics() async {
    try {
      return await _localAuth.canCheckBiometrics;
    } catch (e) {
      return false;
    }
  }

  /// Get available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      return <BiometricType>[];
    }
  }

  /// Authenticate with biometrics
  Future<bool> authenticateWithBiometrics({
    String reason = 'Authenticate to access the app',
  }) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // Allow fallback to PIN/Pattern
          useErrorDialogs: true,
        ),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('🔐 Biometric auth failed: $e');
      return false;
    }
  }

  // ========================================
  // DATA ENCRYPTION
  // ========================================

  /// Hash a string using SHA-256
  String hashString(String input) {
    final List<int> bytes = utf8.encode(input);
    final Digest digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Generate HMAC for data integrity
  String generateHmac(String data, String secretKey) {
    final List<int> key = utf8.encode(secretKey);
    final List<int> bytes = utf8.encode(data);
    final Hmac hmac = Hmac(sha256, key);
    final Digest digest = hmac.convert(bytes);
    return digest.toString();
  }

  /// Verify HMAC
  bool verifyHmac(String data, String expectedHmac, String secretKey) {
    final String computedHmac = generateHmac(data, secretKey);
    return computedHmac == expectedHmac;
  }

  // ========================================
  // SCREENSHOT PREVENTION (Platform Channels)
  // ========================================
  static const MethodChannel _securityChannel = MethodChannel(
    'com.bdnews/security',
  );

  /// Prevent screenshots (best effort - requires native implementation)
  Future<void> enableScreenshotPrevention() async {
    try {
      if (Platform.isAndroid) {
        await _securityChannel.invokeMethod<void>('enableSecureFlag');
      }
      // iOS uses UITextField trick or ScreenCaptureKit detection
    } catch (e) {
      if (kDebugMode) debugPrint('🔐 Screenshot prevention not available: $e');
    }
  }

  Future<void> disableScreenshotPrevention() async {
    try {
      if (Platform.isAndroid) {
        await _securityChannel.invokeMethod<void>('disableSecureFlag');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('🔐 Screenshot prevention toggle failed: $e');
    }
  }

  // ========================================
  // GETTERS
  // ========================================

  bool get isDeviceSecure => _isDeviceSecure;
  bool get isSecure => _isDeviceSecure;
  bool get isRooted => !_isDeviceSecure;
  bool get isInitialized => _isSecurityInitialized;
}
