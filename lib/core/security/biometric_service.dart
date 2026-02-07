// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' show Random;

import 'package:crypto/crypto.dart' as crypto;
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:device_info_plus/device_info_plus.dart';

// =========================================================
// ENUMS & MODELS
// =========================================================

enum BiometricStrength { weak, strong }

enum BiometricErrorCode {
  canceled,
  notRecognized,
  lockedOut,
  notAvailable,
  notEnrolled,
  passcodeNotSet,
  permanentlyLocked,
  deviceIntegrityFailed,
  clockTampered,
}

class BiometricOptions {

  const BiometricOptions({
    this.title = 'Authenticate',
    this.subtitle = '',
    this.description = 'Use biometrics to continue',
    this.cancelText = 'Cancel',
    this.requireStrong = true,
    this.allowDeviceCredential = false,
    this.confirmationRequired = true,
    this.timeout = const Duration(seconds: 30),
  });
  final String title;
  final String subtitle;
  final String description;
  final String cancelText;
  final bool requireStrong;
  final bool allowDeviceCredential;
  final bool confirmationRequired;
  final Duration timeout;
}

class SecureSession {

  const SecureSession({
    required this.token,
    required this.expiresAt,
    this.type,
    this.strength = BiometricStrength.strong,
  });
  final String token;
  final DateTime expiresAt;
  final BiometricType? type;
  final BiometricStrength strength;

  bool get isValid => DateTime.now().isBefore(expiresAt);
}

// =========================================================
// BIOMETRIC RESULT SEALED CLASSES
// =========================================================

sealed class BiometricAuthResult {
  const BiometricAuthResult();
}

class BiometricSuccess extends BiometricAuthResult {
  const BiometricSuccess(this.session, this.type);
  final SecureSession session;
  final BiometricType? type;
}

class BiometricFailed extends BiometricAuthResult {
  const BiometricFailed({
    required this.code,
    required this.attemptsRemaining,
    this.canRetryImmediately = true,
  });
  final BiometricErrorCode code;
  final int attemptsRemaining;
  final bool canRetryImmediately;
}

class BiometricLockedOut extends BiometricAuthResult {
  const BiometricLockedOut(this.remaining, this.until);
  final Duration remaining;
  final DateTime until;
}

class BiometricUnavailable extends BiometricAuthResult {
  const BiometricUnavailable(this.reason, {this.retry = false});
  final String reason;
  final bool retry;
}

class BiometricIntegrityFailed extends BiometricAuthResult {
  const BiometricIntegrityFailed(this.checks);
  final List<String> checks;
}

// =========================================================
// SECURE KEYSTORE
// =========================================================

class BiometricKeystore {

  BiometricKeystore()
      : storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
          iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
        );
  static const String kLockout = 'bio_lockout_v2';
  static const String kDeviceId = 'bio_device_id_v1';
  static const String kNotifications = 'bio_pending_notify_v1';

  final FlutterSecureStorage storage;
  final encrypt.IV _iv = encrypt.IV.fromLength(12);

  Future<String> _deviceId() async {
    final cached = await storage.read(key: kDeviceId);
    if (cached != null) return cached;

    final info = DeviceInfoPlugin();
    String id;

    if (Platform.isAndroid) {
      final a = await info.androidInfo;
      id = a.id;
    } else if (Platform.isIOS) {
      final i = await info.iosInfo;
      id = i.identifierForVendor ?? "ios_unknown";
    } else {
      id = "unk_${DateTime.now().millisecondsSinceEpoch}";
    }

    final finalId = "$id.biometric.secure";
    await storage.write(key: kDeviceId, value: finalId);
    return finalId;
  }

  Future<encrypt.Key> _key() async {
    final id = await _deviceId();
    final hash = crypto.sha256.convert(utf8.encode("$id.salt.2024"));
    return encrypt.Key.fromBase64(base64.encode(hash.bytes));
  }

  Future<void> saveLockout(Map<String, dynamic> data) async {
    try {
      final encrypter = encrypt.Encrypter(encrypt.AES(await _key(), mode: encrypt.AESMode.gcm));
      final encrypted = encrypter.encrypt(json.encode(data), iv: _iv);
      await storage.write(key: kLockout, value: encrypted.base64);
    } catch (e) {
      debugPrint("❌ lockout save failed: $e");
    }
  }

  Future<Map<String, dynamic>?> loadLockout() async {
    try {
      final raw = await storage.read(key: kLockout);
      if (raw == null) return null;

      final encrypter = encrypt.Encrypter(encrypt.AES(await _key(), mode: encrypt.AESMode.gcm));
      final decrypted = encrypter.decrypt64(raw, iv: _iv);
      return json.decode(decrypted);
    } catch (_) {
      await storage.delete(key: kLockout);
      return null;
    }
  }

  Future<void> clearLockout() => storage.delete(key: kLockout);

  Future<List<Map<String, dynamic>>> pendingNotifications() async {
    try {
      final raw = await storage.read(key: kNotifications);
      if (raw == null) return [];
      return (json.decode(raw) as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<void> addNotification(Map<String, dynamic> data) async {
    final list = await pendingNotifications();
    list.add(data);
    await storage.write(key: kNotifications, value: json.encode(list));
  }
}

// =========================================================
// RATE LIMITER WITH BACKOFF
// =========================================================

class RateLimiter {

  RateLimiter({this.maxAttempts = 5, this.base = const Duration(seconds: 30)});
  final int maxAttempts;
  final Duration base;
  int failures = 0;
  DateTime? lockedUntil;

  bool get isLocked => lockedUntil != null && DateTime.now().isBefore(lockedUntil!);

  Duration remaining() =>
      isLocked ? lockedUntil!.difference(DateTime.now()) : Duration.zero;

  void registerFailure() {
    failures++;
    if (failures >= maxAttempts) {
      final lock = base * (1 << (failures - maxAttempts));
      lockedUntil = DateTime.now().add(lock);
    }
  }

  void reset() {
    failures = 0;
    lockedUntil = null;
  }
}

// =========================================================
// DEVICE INTEGRITY CHECKER
// =========================================================

class DeviceIntegrityChecker {
  Future<List<String>> check() async {
    final failures = <String>[];

    if (await _isRooted()) failures.add("root_or_jailbreak");

    if (await _isEmulator()) failures.add("emulator_detected");

    if (await _clockTampered()) failures.add("clock_tamper");

    return failures;
  }

  Future<bool> _isRooted() async {
    if (Platform.isIOS) {
      return _iosJailbroken();
    }
    if (Platform.isAndroid) {
      return _androidRooted();
    }
    return false;
  }

  Future<bool> _iosJailbroken() async {
    final paths = [
      "/Applications/Cydia.app",
      "/bin/bash",
      "/usr/sbin/sshd",
      "/etc/apt",
    ];
    for (final p in paths) {
      if (File(p).existsSync()) return true;
    }
    return false;
  }

  Future<bool> _androidRooted() async {
    final indicators = [
      "/system/xbin/su",
      "/system/bin/su",
      "/system/app/Superuser.apk",
      "/system/app/SuperSU.apk",
    ];
    for (final p in indicators) {
      if (File(p).existsSync()) return true;
    }
    return false;
  }

  Future<bool> _isEmulator() async {
    final info = await DeviceInfoPlugin().androidInfo;
    final model = info.model.toLowerCase();
    return model.contains("emulator") || model.contains("sdk");
  }

  Future<bool> _clockTampered() async {
    final now = DateTime.now();
    final monotonic = now.millisecondsSinceEpoch; 
    final drift = DateTime.now().millisecondsSinceEpoch - monotonic;
    return drift.abs() > 120000;
  }
}

// =========================================================
// MAIN BIOMETRIC SERVICE
// =========================================================

class IndustrialBiometricService {
  final LocalAuthentication auth = LocalAuthentication();
  final BiometricKeystore store = BiometricKeystore();
  final DeviceIntegrityChecker integrity = DeviceIntegrityChecker();
  final RateLimiter rateLimiter = RateLimiter();

  Future<BiometricAuthResult> authenticate(BiometricOptions opts) async {
    final failed = await integrity.check();
    if (failed.isNotEmpty) return BiometricIntegrityFailed(failed);

    if (rateLimiter.isLocked) {
      return BiometricLockedOut(rateLimiter.remaining(), rateLimiter.lockedUntil!);
    }

    final available = await auth.canCheckBiometrics;
    if (!available) return const BiometricUnavailable("Biometrics not available");

    final types = await auth.getAvailableBiometrics();
    if (types.isEmpty) return const BiometricUnavailable("No biometrics enrolled");

    final type = types.first;
    final strength = await _strength(type);

    if (opts.requireStrong && strength == BiometricStrength.weak) {
      return const BiometricUnavailable("Requires strong biometrics");
    }

    bool ok;
    try {
      ok = await auth.authenticate(
        localizedReason: opts.description,
        options: AuthenticationOptions(
          biometricOnly: !opts.allowDeviceCredential,
          sensitiveTransaction: false,
          useErrorDialogs: false,
        ),
      );
    } catch (e) {
      return const BiometricFailed(
        code: BiometricErrorCode.notAvailable,
        attemptsRemaining: 3,
      );
    }

    if (!ok) {
      rateLimiter.registerFailure();
      return BiometricFailed(
        code: BiometricErrorCode.notRecognized,
        attemptsRemaining: 5 - rateLimiter.failures,
      );
    }

    rateLimiter.reset();
    final session = SecureSession(
      token: _randomToken(),
      expiresAt: DateTime.now().add(const Duration(minutes: 10)),
      type: type,
      strength: strength,
    );
    return BiometricSuccess(session, type);
  }

  Future<BiometricStrength> _strength(BiometricType t) async {
    if (Platform.isIOS) {
      return (t == BiometricType.face || t == BiometricType.fingerprint)
          ? BiometricStrength.strong
          : BiometricStrength.weak;
    }

    final info = await DeviceInfoPlugin().androidInfo;
    return info.version.sdkInt >= 28
        ? BiometricStrength.strong
        : BiometricStrength.weak;
  }

  String _randomToken() {
    final b = List<int>.generate(32, (_) => (Random.secure().nextInt(256)));
    return base64Url.encode(b);
  }
}
