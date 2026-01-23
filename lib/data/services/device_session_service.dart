import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../models/device_session.dart';
import 'security_audit_service.dart';
import 'app_verification_service.dart';
import '../../core/security/secure_prefs.dart'; // BUILD_FIXES: Secure device ID storage

/// Service for managing device sessions and enforcing device limits
class DeviceSessionService {

  DeviceSessionService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    SecurityAuditService? auditService,
    AppVerificationService? appVerification,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _auditService = auditService ?? SecurityAuditService(),
       _appVerification = appVerification ?? AppVerificationService();
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final SecurityAuditService _auditService;
  final AppVerificationService _appVerification;

  // Rate limiting - prevent DoS attacks
  static final Map<String, DateTime> _lastRegistration = {};
  static const Duration _registrationCooldown = Duration(minutes: 5);

  // Configuration - Platform-specific limits
  static const int maxFreeAndroidDevices = 1;
  static const int maxFreeIosDevices = 1;
  static const int maxPremiumAndroidDevices = 2;
  static const int maxPremiumIosDevices = 1;
  static const Duration sessionTimeout = Duration(days: 30);

  /// Register the current device for the authenticated user
  Future<DeviceRegistrationResult> registerDevice() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return DeviceRegistrationResult.error('Not authenticated');
      }

      // Rate limit check - prevent DoS
      final rateLimitResult = _checkRateLimit(user.uid);
      if (!rateLimitResult.allowed) {
        return DeviceRegistrationResult.error(
          'Too many registration attempts. Please wait ${rateLimitResult.waitMinutes} minutes.',
        );
      }

      final deviceId = await _getDeviceId();
      final deviceInfo = await _getDeviceInfo();
      final appVersion = await _getAppVersion();
      final fcmToken = await _getFCMToken();

      // App verification - Validate request authenticity
      final isVerified = await _appVerification.validateApp(
        operation: 'device_registration',
      );

      if (!isVerified) {
        await _auditService.logEvent(SecurityEventType.suspiciousActivity, {
          'reason': 'app_verification_failed',
        });
        return DeviceRegistrationResult.error(
          'App verification failed. Please ensure you are using the official app.',
        );
      }

      // Validate and sanitize inputs
      final sanitizedDeviceName = _sanitizeDeviceName(
        deviceInfo['model'] ?? 'Unknown Device',
      );
      final validatedPlatform = _validatePlatform(
        deviceInfo['platform'] ?? 'unknown',
      );

      // Check device limit
      final limitCheck = await _checkDeviceLimit(user.uid, deviceId);
      if (!limitCheck.allowed) {
        return DeviceRegistrationResult.limitExceeded(
          maxDevices: limitCheck.maxDevices,
          currentCount: limitCheck.currentCount,
        );
      }

      // Register/update device with sanitized data
      await _firestore
          .collection('user_sessions')
          .doc(user.uid)
          .collection('devices')
          .doc(deviceId)
          .set({
            'deviceId': deviceId,
            'deviceName': sanitizedDeviceName, // Sanitized
            'platform': validatedPlatform, // Validated
            'appVersion': appVersion,
            if (fcmToken != null) 'fcmToken': fcmToken,
            'firstSeen': FieldValue.serverTimestamp(),
            'lastActive': FieldValue.serverTimestamp(),
            'loginCount': FieldValue.increment(1),
            'status': 'active',
          }, SetOptions(merge: true));

      // Update rate limit timestamp
      _lastRegistration[user.uid] = DateTime.now();

      // Log successful registration
      await _auditService.logEvent(SecurityEventType.deviceRegistered, {
        'deviceId': deviceId,
        'deviceName': sanitizedDeviceName,
        'platform': validatedPlatform,
      });

      if (kDebugMode) {
        debugPrint('[DeviceSession] Device registered: $deviceId');
      }

      return DeviceRegistrationResult.success();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[DeviceSession] Registration failed: $e');
      }
      return DeviceRegistrationResult.error(e.toString());
    }
  }

  /// Check if device limit is exceeded
  Future<DeviceLimitCheck> _checkDeviceLimit(
    String userId,
    String currentDeviceId,
  ) async {
    try {
      // Get user's premium status
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final isPremium = userDoc.data()?['isPremium'] ?? false;

      // Get current device platform
      final deviceInfo = await _getDeviceInfo();
      final currentPlatform =
          deviceInfo['platform']?.toLowerCase() ?? 'unknown';

      // Get active devices
      final activeDevices = await _getActiveDevicesForUser(userId);

      // Check if current device already registered
      final existingDevice = activeDevices.firstWhere(
        (doc) => doc.id == currentDeviceId,
        orElse: () => throw StateError('not_found'),
      );

      // If device already exists, always allow (re-login)
      if (existingDevice.id == currentDeviceId) {
        return DeviceLimitCheck(
          allowed: true,
          maxDevices: _getTotalMaxDevices(isPremium),
          currentCount: activeDevices.length,
        );
      }
    } on StateError {
      // Device not found - this is a new device, check limits
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[DeviceSession] Limit check failed: $e');
      }
      // On error, allow (fail open for better UX)
      return DeviceLimitCheck(
        allowed: true,
        maxDevices: _getTotalMaxDevices(false),
        currentCount: 0,
      );
    }

    try {
      // Re-fetch variables for new device check
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final isPremium = userDoc.data()?['isPremium'] ?? false;
      final deviceInfo = await _getDeviceInfo();
      final currentPlatform =
          deviceInfo['platform']?.toLowerCase() ?? 'unknown';
      final activeDevices = await _getActiveDevicesForUser(userId);

      // Count devices by platform
      final platformCounts = _countDevicesByPlatform(activeDevices);
      final androidCount = platformCounts['android'] ?? 0;
      final iosCount = platformCounts['ios'] ?? 0;

      // Get platform-specific limit
      final limit = _getPlatformLimit(currentPlatform, isPremium);
      final currentCount =
          currentPlatform == 'android' ? androidCount : iosCount;

      // Check if new device exceeds platform limit
      final allowed = currentCount < limit;

      return DeviceLimitCheck(
        allowed: allowed,
        maxDevices: _getTotalMaxDevices(isPremium),
        currentCount: activeDevices.length,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[DeviceSession] Limit check failed: $e');
      }
      return DeviceLimitCheck(
        allowed: true,
        maxDevices: _getTotalMaxDevices(false),
        currentCount: 0,
      );
    }
  }

  /// Get active devices for a user (helper method)
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  _getActiveDevicesForUser(String userId) async {
    final cutoffDate = DateTime.now().subtract(sessionTimeout);
    final snapshot =
        await _firestore
            .collection('user_sessions')
            .doc(userId)
            .collection('devices')
            .where('status', isEqualTo: 'active')
            .where('lastActive', isGreaterThan: Timestamp.fromDate(cutoffDate))
            .get();
    return snapshot.docs;
  }

  /// Count devices by platform (helper method)
  Map<String, int> _countDevicesByPlatform(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> devices,
  ) {
    final counts = <String, int>{'android': 0, 'ios': 0};

    for (final doc in devices) {
      final platform =
          doc.data()['platform']?.toString().toLowerCase() ?? 'unknown';
      if (platform == 'android' || platform == 'ios') {
        counts[platform] = (counts[platform] ?? 0) + 1;
      }
    }

    return counts;
  }

  /// Get platform-specific device limit
  int _getPlatformLimit(String platform, bool isPremium) {
    if (platform == 'android') {
      return isPremium ? maxPremiumAndroidDevices : maxFreeAndroidDevices;
    } else if (platform == 'ios') {
      return isPremium ? maxPremiumIosDevices : maxFreeIosDevices;
    }
    return 0; // Unknown platforms not allowed
  }

  /// Get total max devices across all platforms
  int _getTotalMaxDevices(bool isPremium) {
    return isPremium
        ? maxPremiumAndroidDevices + maxPremiumIosDevices
        : maxFreeAndroidDevices + maxFreeIosDevices;
  }

  /// Update activity timestamp for current device
  Future<void> updateActivity() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final deviceId = await _getDeviceId();
      await _firestore
          .collection('user_sessions')
          .doc(user.uid)
          .collection('devices')
          .doc(deviceId)
          .update({'lastActive': FieldValue.serverTimestamp()});
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[DeviceSession] Activity update failed: $e');
      }
    }
  }

  /// Get all active devices for current user
  Future<List<DeviceSession>> getActiveDevices() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      final snapshot =
          await _firestore
              .collection('user_sessions')
              .doc(user.uid)
              .collection('devices')
              .where('status', isEqualTo: 'active')
              .orderBy('lastActive', descending: true)
              .get();

      return snapshot.docs
          .map((doc) => DeviceSession.fromFirestore(doc))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[DeviceSession] Failed to get devices: $e');
      }
      return [];
    }
  }

  /// Revoke a device session (logout)
  Future<void> revokeDevice(String deviceId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore
          .collection('user_sessions')
          .doc(user.uid)
          .collection('devices')
          .doc(deviceId)
          .update({'status': 'revoked'});

      // Log device revocation
      await _auditService.logEvent(SecurityEventType.deviceRevoked, {
        'deviceId': deviceId,
        'revokedBy': 'user',
      });

      // If revoking current device, logout locally
      final currentDeviceId = await _getDeviceId();
      if (deviceId == currentDeviceId) {
        await _auth.signOut();
      }

      if (kDebugMode) {
        debugPrint('[DeviceSession] Device revoked: $deviceId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[DeviceSession] Revoke failed: $e');
      }
      rethrow;
    }
  }

  /// Revoke all devices except current one
  Future<void> revokeAllOtherDevices() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final currentDeviceId = await _getDeviceId();
      final devices = await getActiveDevices();

      int revokedCount = 0;
      for (final device in devices) {
        if (device.deviceId != currentDeviceId) {
          await revokeDevice(device.deviceId);
          revokedCount++;
        }
      }

      // Log bulk revocation
      await _auditService.logEvent(SecurityEventType.allDevicesRevoked, {
        'deviceCount': revokedCount,
        'keptDevice': currentDeviceId,
      });

      if (kDebugMode) {
        debugPrint('[DeviceSession] All other devices revoked');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[DeviceSession] Revoke all failed: $e');
      }
      rethrow;
    }
  }

  /// Check if current device session is valid
  Future<bool> validateSession() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return true; // Fail open - don't logout on errors

      final deviceId = await _getDeviceId();
      final deviceDoc =
          await _firestore
              .collection('user_sessions')
              .doc(user.uid)
              .collection('devices')
              .doc(deviceId)
              .get();

      if (!deviceDoc.exists) return true; // Fail open - don't logout on errors

      final session = DeviceSession.fromFirestore(deviceDoc);
      return session.isActive && !session.isExpired;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[DeviceSession] Session validation failed: $e');
      }
      return true; // Fail open - don't logout on errors
    }
  }

  /// Get current device ID (cached in SecurePrefs)
  Future<String> _getDeviceId() async {
    // Try to get cached device ID from SecurePrefs
    final cachedId = await SecurePrefs.instance.getDeviceId();
    if (cachedId != null && cachedId.isNotEmpty) {
      return cachedId;
    }

    // If not cached, fetch from device and cache it
    final deviceInfo = DeviceInfoPlugin();
    String deviceId;
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      deviceId = androidInfo.id;
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      deviceId = iosInfo.identifierForVendor ?? 'unknown-ios';
    } else {
      deviceId = 'unknown-platform';
    }

    // Cache device ID in SecurePrefs
    await SecurePrefs.instance.setDeviceId(deviceId);
    return deviceId;
  }

  /// Get device information
  Future<Map<String, String>> _getDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return {
        'model': '${androidInfo.manufacturer} ${androidInfo.model}',
        'platform': 'android',
      };
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return {'model': iosInfo.model, 'platform': 'ios'};
    }
    return {'model': 'Unknown', 'platform': 'unknown'};
  }

  /// Get app version
  Future<String> _getAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.version;
    } catch (e) {
      return '0.0.0';
    }
  }

  /// Get FCM token
  Future<String?> _getFCMToken() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      return null;
    }
  }

  /// Get current device ID (public method)
  Future<String> getCurrentDeviceId() => _getDeviceId();

  // ==========================================
  // SECURITY: Rate Limiting & Input Validation
  // ==========================================

  /// Check rate limit for device registration
  ({bool allowed, int waitMinutes}) _checkRateLimit(String userId) {
    final lastAttempt = _lastRegistration[userId];

    if (lastAttempt == null) {
      return (allowed: true, waitMinutes: 0);
    }

    final timeSince = DateTime.now().difference(lastAttempt);

    if (timeSince < _registrationCooldown) {
      final waitMinutes = _registrationCooldown.inMinutes - timeSince.inMinutes;
      return (allowed: false, waitMinutes: waitMinutes);
    }

    return (allowed: true, waitMinutes: 0);
  }

  /// Sanitize device name to prevent injection attacks
  String _sanitizeDeviceName(String name) {
    // Remove leading/trailing whitespace
    name = name.trim();

    // Limit length to 100 characters
    if (name.length > 100) {
      name = name.substring(0, 100);
    }

    // Remove potentially dangerous characters
    // Allow: letters, numbers, spaces, hyphens, underscores, parentheses
    name = name.replaceAll(RegExp(r'[^\w\s\-\(\)]'), '');

    // Remove excessive whitespace
    name = name.replaceAll(RegExp(r'\s+'), ' ');

    // If empty after sanitization, use default
    if (name.isEmpty) {
      return 'Unknown Device';
    }

    return name;
  }

  /// Validate platform value
  String _validatePlatform(String platform) {
    const allowedPlatforms = ['android', 'ios'];
    final normalized = platform.toLowerCase().trim();

    return allowedPlatforms.contains(normalized) ? normalized : 'unknown';
  }
}
