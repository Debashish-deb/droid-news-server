import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart' show AuthenticationOptions, LocalAuthentication;
import 'package:shared_preferences/shared_preferences.dart';

/// Result of biometric authentication attempt
sealed class BiometricAuthResult {
  const BiometricAuthResult();
}

class BiometricSuccess extends BiometricAuthResult {
  const BiometricSuccess();
}

class BiometricFailed extends BiometricAuthResult {
  final int attemptsRemaining;
  
  const BiometricFailed({required this.attemptsRemaining});
}

class BiometricLockedOut extends BiometricAuthResult {
  final Duration remainingTime;
  
  const BiometricLockedOut({required this.remainingTime});
}

class BiometricUnavailable extends BiometricAuthResult {
  final String reason;
  
  const BiometricUnavailable({this.reason = 'Biometric authentication not available'});
}

/// Enhanced Biometric Authentication Service
/// 
/// Features:
/// - Rate limiting (max 3 attempts before lockout)
/// - 5-minute lockout after failed attempts
/// - Strict biometric-only mode
/// - Secure attempt tracking
class BiometricService {
  static const int _maxAttempts = 3;
  static const Duration _lockoutDuration = Duration(minutes: 5);
  
  // Preferences keys
  static const String _keyFailedAttempts = 'bio_failed_attempts';
  static const String _keyLockoutUntil = 'bio_lockout_until';
  
  final LocalAuthentication _auth;
  final SharedPreferences _prefs;
  
  BiometricService({
    required LocalAuthentication auth,
    required SharedPreferences prefs,
  })  : _auth = auth,
        _prefs = prefs;
  
  /// Get number of failed attempts
  int get _failedAttempts => _prefs.getInt(_keyFailedAttempts) ?? 0;
  
  /// Get lockout expiration time
  DateTime? get _lockoutUntil {
    final timestamp = _prefs.getInt(_keyLockoutUntil);
    return timestamp != null 
        ? DateTime.fromMillisecondsSinceEpoch(timestamp) 
        : null;
  }
  
  /// Authenticate user with biometric
  /// 
  /// [reason] - Localized reason shown to user
  /// [strictBiometricOnly] - If true, disables PIN/pattern fallback
  Future<BiometricAuthResult> authenticate({
    required String reason,
    bool strictBiometricOnly = true,
  }) async {
    // Check if currently locked out
    final lockoutUntil = _lockoutUntil;
    if (lockoutUntil != null && DateTime.now().isBefore(lockoutUntil)) {
      final remainingTime = lockoutUntil.difference(DateTime.now());
      debugPrint('🔒 Biometric locked out for ${remainingTime.inSeconds}s');
      return BiometricLockedOut(remainingTime: remainingTime);
    }
    
    // Check biometric availability
    final canCheckBiometrics = await _auth.canCheckBiometrics;
    final isDeviceSupported = await _auth.isDeviceSupported();
    
    if (!canCheckBiometrics || !isDeviceSupported) {
      debugPrint('⚠️ Biometric unavailable on this device');
      return const BiometricUnavailable();
    }
    
    // Get available biometric types
    final availableBiometrics = await _auth.getAvailableBiometrics();
    if (availableBiometrics.isEmpty) {
      return const BiometricUnavailable(
        reason: 'No biometric sensors enrolled',
      );
    }
    
    try {
      final authenticated = await _auth.authenticate(
        localizedReason: reason,
        options: AuthenticationOptions(
          biometricOnly: strictBiometricOnly, // ✅ Enforce biometric
          stickyAuth: true, // Keep auth dialog during app backgrounding
          sensitiveTransaction: true, // Use strongest biometric settings
        ),
      );
      
      if (authenticated) {
        await _resetFailedAttempts();
        debugPrint('✅ Biometric authentication successful');
        return const BiometricSuccess();
      } else {
        debugPrint('❌ Biometric authentication failed (user cancelled)');
        return await _handleFailedAttempt();
      }
    } catch (e) {
      debugPrint('❌ Biometric authentication error: $e');
      return await _handleFailedAttempt();
    }
  }
  
  /// Handle failed authentication attempt
  Future<BiometricAuthResult> _handleFailedAttempt() async {
    final attempts = _failedAttempts + 1;
    await _prefs.setInt(_keyFailedAttempts, attempts);
    
    debugPrint('⚠️ Failed biometric attempt $attempts/$_maxAttempts');
    
    if (attempts >= _maxAttempts) {
      final lockoutUntil = DateTime.now().add(_lockoutDuration);
      await _prefs.setInt(
        _keyLockoutUntil,
        lockoutUntil.millisecondsSinceEpoch,
      );
      
      debugPrint('🔒 Biometric locked out until $lockoutUntil');
      return BiometricLockedOut(remainingTime: _lockoutDuration);
    }
    
    return BiometricFailed(attemptsRemaining: _maxAttempts - attempts);
  }
  
  /// Reset failed attempts counter
  Future<void> _resetFailedAttempts() async {
    await _prefs.remove(_keyFailedAttempts);
    await _prefs.remove(_keyLockoutUntil);
  }
  
  /// Manually reset lockout (for admin/support)
  Future<void> resetLockout() async {
    await _resetFailedAttempts();
    debugPrint('🔓 Biometric lockout manually reset');
  }
  
  /// Check if currently locked out
  bool get isLockedOut {
    final lockoutUntil = _lockoutUntil;
    return lockoutUntil != null && DateTime.now().isBefore(lockoutUntil);
  }
  
  /// Get remaining lockout time
  Duration? get remainingLockoutTime {
    final lockoutUntil = _lockoutUntil;
    if (lockoutUntil == null || DateTime.now().isAfter(lockoutUntil)) {
      return null;
    }
    return lockoutUntil.difference(DateTime.now());
  }
}
