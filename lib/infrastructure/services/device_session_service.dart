import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../persistence/device_session.dart';
import '../persistence/device_session.dart' show DeviceLimitCheck, DeviceRegistrationResult, DeviceSession;
import 'security_audit_service.dart';
import 'app_verification_service.dart';
import '../../core/security/secure_prefs.dart'; 
import '../../core/telemetry/structured_logger.dart';

// Service for managing device sessions and enforcing device limits
class DeviceSessionService {

  DeviceSessionService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    SecurityAuditService? auditService,
    AppVerificationService? appVerification,
    required SecurePrefs securePrefs,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _auditService = auditService ?? SecurityAuditService(),
       _appVerification = appVerification ?? AppVerificationService(),
       _securePrefs = securePrefs;
  final SecurePrefs _securePrefs;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final SecurityAuditService _auditService;
  final AppVerificationService _appVerification;

  
  static final Map<String, DateTime> _lastRegistration = {};
  static const Duration _registrationCooldown = Duration(minutes: 5);


  static const int maxFreeAndroidDevices = 1;
  static const int maxFreeIosDevices = 1;
  static const int maxPremiumAndroidDevices = 2;
  static const int maxPremiumIosDevices = 1;
  static const Duration sessionTimeout = Duration(days: 30);

  Future<DeviceRegistrationResult> registerDevice() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return DeviceRegistrationResult.error('Not authenticated');
      }

      
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

      final sanitizedDeviceName = _sanitizeDeviceName(
        deviceInfo['model'] ?? 'Unknown Device',
      );
      final validatedPlatform = _validatePlatform(
        deviceInfo['platform'] ?? 'unknown',
      );

      final limitCheck = await _checkDeviceLimit(user.uid, deviceId);
      if (!limitCheck.allowed) {
        return DeviceRegistrationResult.limitExceeded(
          maxDevices: limitCheck.maxDevices,
          currentCount: limitCheck.currentCount,
        );
      }

      await _firestore
          .collection('user_sessions')
          .doc(user.uid)
          .collection('devices')
          .doc(deviceId)
          .set({
            'deviceId': deviceId,
            'deviceName': sanitizedDeviceName, 
            'platform': validatedPlatform,
            'appVersion': appVersion,
            if (fcmToken != null) 'fcmToken': fcmToken,
            'firstSeen': FieldValue.serverTimestamp(),
            'lastActive': FieldValue.serverTimestamp(),
            'loginCount': FieldValue.increment(1),
            'status': 'active',
          }, SetOptions(merge: true));

      
      _lastRegistration[user.uid] = DateTime.now();

     
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

  Future<DeviceLimitCheck> _checkDeviceLimit(
    String userId,
    String currentDeviceId,
  ) async {
    try {

      final userDoc = await _firestore.collection('users').doc(userId).get();
      final isPremium = userDoc.data()?['isPremium'] ?? false;

      final deviceInfo = await _getDeviceInfo();
      final currentPlatform =
          deviceInfo['platform']?.toLowerCase() ?? 'unknown';

      final activeDevices = await _getActiveDevicesForUser(userId);

      final existingDevice = activeDevices.firstWhere(
        (doc) => doc.id == currentDeviceId,
        orElse: () => throw StateError('not_found'),
      );

      if (existingDevice.id == currentDeviceId) {
        return DeviceLimitCheck(
          allowed: true,
          maxDevices: _getTotalMaxDevices(isPremium),
          currentCount: activeDevices.length,
        );
      }
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

    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final isPremium = userDoc.data()?['isPremium'] ?? false;
      final deviceInfo = await _getDeviceInfo();
      final currentPlatform =
          deviceInfo['platform']?.toLowerCase() ?? 'unknown';
      final activeDevices = await _getActiveDevicesForUser(userId);

      final platformCounts = _countDevicesByPlatform(activeDevices);
      final androidCount = platformCounts['android'] ?? 0;
      final iosCount = platformCounts['ios'] ?? 0;

      final limit = _getPlatformLimit(currentPlatform, isPremium);
      final currentCount =
          currentPlatform == 'android' ? androidCount : iosCount;

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

  int _getPlatformLimit(String platform, bool isPremium) {
    if (platform == 'android') {
      return isPremium ? maxPremiumAndroidDevices : maxFreeAndroidDevices;
    } else if (platform == 'ios') {
      return isPremium ? maxPremiumIosDevices : maxFreeIosDevices;
    }
    return 0; 
  }

  int _getTotalMaxDevices(bool isPremium) {
    return isPremium
        ? maxPremiumAndroidDevices + maxPremiumIosDevices
        : maxFreeAndroidDevices + maxFreeIosDevices;
  }

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
      if (e.toString().contains('permission-denied')) {
        return;
      }
      if (kDebugMode) {
        debugPrint('[DeviceSession] Activity update failed: $e');
      }
    }
  }

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

      await _auditService.logEvent(SecurityEventType.deviceRevoked, {
        'deviceId': deviceId,
        'revokedBy': 'user',
      });

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

  Future<bool> validateSession() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return true; 

      final deviceId = await _getDeviceId();
      final deviceDoc =
          await _firestore
              .collection('user_sessions')
              .doc(user.uid)
              .collection('devices')
              .doc(deviceId)
              .get();

      if (!deviceDoc.exists) return true; 

      final session = DeviceSession.fromFirestore(deviceDoc);
      return session.isActive && !session.isExpired;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[DeviceSession] Session validation failed: $e');
      }
      return true; 
    }
  }

  Future<String> _getDeviceId() async {
    final cachedId = await _securePrefs.getDeviceId();
    if (cachedId != null && cachedId.isNotEmpty) {
      return cachedId;
    }

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

    await _securePrefs.setDeviceId(deviceId);
    return deviceId;
  }

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

  Future<String> _getAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.version;
    } catch (e) {
      return '0.0.0';
    }
  }

  Future<String?> _getFCMToken() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      return null;
    }
  }

  Future<String> getCurrentDeviceId() => _getDeviceId();


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

  String _sanitizeDeviceName(String name) {
    /// Remove leading/trailing whitespace
    name = name.trim();

    if (name.length > 100) {
      name = name.substring(0, 100);
    }

    name = name.replaceAll(RegExp(r'[^\w\s\-\(\)]'), '');

    name = name.replaceAll(RegExp(r'\s+'), ' ');

    if (name.isEmpty) {
      return 'Unknown Device';
    }

    return name;
  }

  String _validatePlatform(String platform) {
    const allowedPlatforms = ['android', 'ios'];
    final normalized = platform.toLowerCase().trim();

    return allowedPlatforms.contains(normalized) ? normalized : 'unknown';
  }
}
