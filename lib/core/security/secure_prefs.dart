// lib/core/security/secure_prefs.dart
// ====================================
// SECURE PREFERENCES WRAPPER
// Uses flutter_secure_storage for sensitive data
// ====================================

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';


/// Wrapper for secure storage of sensitive preferences
/// Use this instead of SharedPreferences for tokens, API keys, etc.

class SecurePrefs {
  SecurePrefs();

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  
  static const String _keyAuthToken = 'auth_token';
  static const String _keyRefreshToken = 'refresh_token';
  static const String _keyDeviceId = 'device_id';
  
  // Reserved for upcoming enterprise security features
  static const String _keyApiKey = 'internal_api_key'; // ignore: unused_field
  static const String _keyUserPin = 'user_app_pin';   // ignore: unused_field


  Future<void> setAuthToken(String token) async {
    await _write(_keyAuthToken, token);
  }

  Future<String?> getAuthToken() async {
    return _read(_keyAuthToken);
  }

  Future<void> setRefreshToken(String token) async {
    await _write(_keyRefreshToken, token);
  }

  Future<String?> getRefreshToken() async {
    return _read(_keyRefreshToken);
  }


  Future<void> setDeviceId(String id) async {
    await _write(_keyDeviceId, id);
  }

  Future<String?> getDeviceId() async {
    return _read(_keyDeviceId);
  }


  Future<void> _write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SecurePrefs] Write error for $key: $e');
      }
    }
  }

  Future<String?> _read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SecurePrefs] Read error for $key: $e');
      }
      return null;
    }
  }

  /// Public generic string methods
  Future<void> setString(String key, String value) => _write(key, value);
  Future<String?> getString(String key) => _read(key);

  /// Delete a specific key
  Future<void> delete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SecurePrefs] Delete error for $key: $e');
      }
    }
  }

  /// Clear all secure storage (use with caution!)
  Future<void> clearAll() async {
    try {
      await _storage.deleteAll();
      if (kDebugMode) {
        debugPrint('[SecurePrefs] All secure data cleared');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SecurePrefs] Clear all error: $e');
      }
    }
  }
}
