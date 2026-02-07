// lib/core/security/security_service.dart
// ========================================
// COMPREHENSIVE APP SECURITY SERVICE
// ========================================

import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:encrypt/encrypt.dart' as enc;
import '../architecture/failure.dart';
import '../../bootstrap/di/injection_container.dart' show sl;
import '../telemetry/structured_logger.dart';

// Centralized security service for the app.
class SecurityService {
  factory SecurityService() => _instance;
  SecurityService._internal();
  static final SecurityService _instance = SecurityService._internal();

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
  bool _isRooted = false;

  Future<void> initialize() async {
    if (_isSecurityInitialized) return;

    await _performSecurityChecks();

    _isSecurityInitialized = true;
    if (kDebugMode) debugPrint('🔐 Security Service Initialized');
  }

  Future<void> _performSecurityChecks() async {
    _isRooted = await _checkRootStatus();
    if (_isRooted) {
      if (kDebugMode) {
        debugPrint('⚠️ WARNING: Device appears to be rooted/jailbroken');
      }
      _isDeviceSecure = false;
    }

    if (!kDebugMode && await _isDebuggerAttached()) {
      if (kDebugMode) {
        debugPrint('⚠️ WARNING: Debugger detected in release mode');
      }
      _isDeviceSecure = false;
    }

    if (await _checkForHooks()) {
      if (kDebugMode) debugPrint('⚠️ WARNING: Hooking framework detected');
      _isDeviceSecure = false;
    }
  }

  Future<bool> _checkRootStatus() async {
    if (Platform.isAndroid) {
      return await _checkAndroidRoot();
    } else if (Platform.isIOS) {
      return await _checkiOSJailbreak();
    }
    return false;
  }

  Future<bool> _checkAndroidRoot() async {
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

    try {
      final ProcessResult result = await Process.run('which', <String>['su']);
      if (result.exitCode == 0) return true;
    } catch (e, stack) {
      try {
        sl<StructuredLogger>().warning('Root check execution failed', e, stack); 
      } catch (_) {} 
    }

    return false;
  }

  Future<bool> _checkiOSJailbreak() async {
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

    try {
      final File testFile = File('/private/jailbreak_test.txt');
      await testFile.writeAsString('test');
      await testFile.delete();
      return true; 
    } catch (e, stack) {
      try {
        sl<StructuredLogger>().warning('Jailbreak check exception', e, stack);
      } catch (_) {}
      return false;
    }
  }

  Future<bool> _isDebuggerAttached() async {
    if (kDebugMode) {
      return false; // Allow debugger in debug builds.
    }

    try {
      final info = await developer.Service.getInfo();
      return info.serverUri != null;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _checkForHooks() async {
    if (Platform.isAndroid) {
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


  Future<void> secureWrite(String key, String value) async {
    try {
      await _secureStorage.write(key: key, value: value);
    } catch (e) {
      if (kDebugMode) debugPrint('🔐 Secure write failed: $e');
    }
  }

  Future<String?> secureRead(String key) async {
    try {
      return await _secureStorage.read(key: key);
    } catch (e) {
      if (kDebugMode) debugPrint('🔐 Secure read failed: $e');
      return null;
    }
  }

  Future<void> secureDelete(String key) async {
    try {
      await _secureStorage.delete(key: key);
    } catch (e) {
      if (kDebugMode) debugPrint('🔐 Secure delete failed: $e');
    }
  }

  Future<void> secureClearAll() async {
    try {
      await _secureStorage.deleteAll();
    } catch (e) {
      if (kDebugMode) debugPrint('🔐 Secure clear failed: $e');
    }
  }


  Future<bool> canUseBiometrics() async {
    try {
      return await _localAuth.canCheckBiometrics;
    } catch (e) {
      return false;
    }
  }

  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      return <BiometricType>[];
    }
  }

  Future<bool> authenticateWithBiometrics({
    String reason = 'Authenticate to access the app',
  }) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
        ),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('🔐 Biometric auth failed: $e');
      return false;
    }
  }


  // ===================================
  // AES-256 Encryption (The Vault)
  // ===================================


  
  enc.Key? _masterKey;
  final _ivParams = enc.IV.fromLength(16); // AES-GCM standard IV length

  Future<void> _initEncryption() async {
    // 1. Check for existing key
    String? keyBase64 = await secureRead('vault_master_key');
    
    // 2. Generate if missing
    if (keyBase64 == null) {
      final key = enc.Key.fromSecureRandom(32); // 256-bit
      keyBase64 = base64Encode(key.bytes);
      await secureWrite('vault_master_key', keyBase64);
      if (kDebugMode) debugPrint('🔐 Generated new Vault Master Key');
    }
    
    // 3. Load Key
    final keyBytes = base64Decode(keyBase64);
    _masterKey = enc.Key(keyBytes);
  }
  
  /// Encrypts raw string using AES-256-GCM
  /// Returns: base64(IV + CipherText)
  Future<String> encryptData(String plainText) async {
    if (_masterKey == null) await _initEncryption();
    
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(_masterKey!, mode: enc.AESMode.gcm));
    
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    
    // Pack IV and CipherText together
    final combined = iv.bytes + encrypted.bytes;
    return base64Encode(combined);
  }
  
  /// Decrypts base64(IV + CipherText)
  Future<String> decryptData(String encryptedBase64) async {
    if (_masterKey == null) await _initEncryption();
    
    try {
      final combined = base64Decode(encryptedBase64);
      
      // Extract IV (first 16 bytes)
      final ivBytes = combined.sublist(0, 16);
      final cipherBytes = combined.sublist(16);
      
      final iv = enc.IV(ivBytes);
      final cipherText = enc.Encrypted(cipherBytes);
      
      final encrypter = enc.Encrypter(enc.AES(_masterKey!, mode: enc.AESMode.gcm));
      return encrypter.decrypt(cipherText, iv: iv);
    } catch (e) {
      if (kDebugMode) debugPrint('🔐 Decryption failed: $e');
      throw const SecurityFailure('Decryption failed: Corrupted data or invalid key');
    }
  }

  String hashString(String input) {
    final List<int> bytes = utf8.encode(input);
    final Digest digest = sha256.convert(bytes);
    return digest.toString();
  }

  String generateHmac(String data, String secretKey) {
    final List<int> key = utf8.encode(secretKey);
    final List<int> bytes = utf8.encode(data);
    final Hmac hmac = Hmac(sha256, key);
    final Digest digest = hmac.convert(bytes);
    return digest.toString();
  }

  bool verifyHmac(String data, String expectedHmac, String secretKey) {
    final String computedHmac = generateHmac(data, secretKey);
    return computedHmac == expectedHmac;
  }

  static const MethodChannel _securityChannel = MethodChannel(
    'com.bdnews/security',
  );

  Future<void> enableScreenshotPrevention() async {
    try {
      if (Platform.isAndroid) {
        await _securityChannel.invokeMethod<void>('enableSecureFlag');
      }
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


  Future<bool> getIsDeviceSecure() async {
    if (!_isSecurityInitialized) await initialize();
    return _isDeviceSecure;
  }

  Future<bool> getIsRooted() async {
    if (!_isSecurityInitialized) await initialize();
    return _isRooted;
  }

  bool get isDeviceSecure => _isDeviceSecure;
  bool get isSecure => _isDeviceSecure;
  bool get isRooted => _isRooted;
  bool get isInitialized => _isSecurityInitialized;
}
