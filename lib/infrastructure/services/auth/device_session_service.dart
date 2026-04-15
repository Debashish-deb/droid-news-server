import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';
import '../../persistence/auth/device_session.dart';
import 'security_audit_service.dart';
import 'app_verification_service.dart';
import '../../../core/errors/security_exception.dart';
import '../../../core/security/secure_prefs.dart';

// Service for managing device sessions and enforcing device limits
class DeviceSessionService {
  DeviceSessionService({
    required SecurePrefs securePrefs,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    SecurityAuditService? auditService,
    AppVerificationService? appVerification,
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
  static bool _sessionStoreUnavailable = false;
  static bool _sessionStoreUnavailableLogged = false;

  static const int maxFreeAndroidDevices = 1;
  static const int maxFreeIosDevices = 1;
  static const int maxPremiumAndroidDevices = 2;
  static const int maxPremiumIosDevices = 1;
  static const Duration sessionTimeout = Duration(days: 30);
  static const Uuid _uuid = Uuid();

  Future<DeviceRegistrationResult> registerDevice() async {
    if (_sessionStoreUnavailable) {
      return DeviceRegistrationResult.sessionStoreUnavailable();
    }
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

      final deviceIdFuture = _getDeviceId();
      final deviceInfoFuture = _getDeviceInfo();
      final appVersionFuture = _getAppVersion();
      final fcmTokenFuture = _getFCMToken();
      final isVerifiedFuture = _appVerification.validateApp(
        operation: 'device_registration',
      );

      var deviceId = await deviceIdFuture;
      final deviceInfo = await deviceInfoFuture;
      final appVersion = await appVersionFuture;
      final fcmToken = await fcmTokenFuture;
      final isVerified = await isVerifiedFuture;

      if (!isVerified) {
        await _auditService.logEvent(SecurityEventType.suspiciousActivity, {
          'reason': 'app_verification_failed',
        });
        return DeviceRegistrationResult.verificationFailed();
      }

      final sanitizedDeviceName = _sanitizeDeviceName(
        deviceInfo['model'] ?? 'Unknown Device',
      );
      final validatedPlatform = _validatePlatform(
        deviceInfo['platform'] ?? 'unknown',
      );
      final reclaimedDeviceId = await _reclaimExistingSessionForSameDevice(
        userId: user.uid,
        currentDeviceId: deviceId,
        currentDeviceName: sanitizedDeviceName,
        currentPlatform: validatedPlatform,
      );
      if (reclaimedDeviceId != null && reclaimedDeviceId.isNotEmpty) {
        deviceId = reclaimedDeviceId;
      }

      final limitCheck = await _checkDeviceLimit(
        user.uid,
        deviceId,
        validatedPlatform,
      );
      if (!limitCheck.allowed) {
        return DeviceRegistrationResult.limitExceeded(
          maxDevices: limitCheck.maxDevices,
          currentCount: limitCheck.currentCount,
        );
      }

      final sessionPayload = <String, dynamic>{
        'deviceId': deviceId,
        'deviceName': sanitizedDeviceName,
        'platform': validatedPlatform,
        'appVersion': appVersion,
        'firstSeen': FieldValue.serverTimestamp(),
        'lastActive': FieldValue.serverTimestamp(),
        'loginCount': FieldValue.increment(1),
        'status': 'active',
      };
      if (fcmToken != null) {
        sessionPayload['fcmToken'] = fcmToken;
      }

      await _firestore
          .collection('user_sessions')
          .doc(user.uid)
          .collection('devices')
          .doc(deviceId)
          .set(sessionPayload, SetOptions(merge: true));

      await _securePrefs.setRegisteredDeviceId(deviceId);
      await _securePrefs.setLastSuccessfulSessionValidationAt(DateTime.now());
      _sessionStoreUnavailable = false;
      _sessionStoreUnavailableLogged = false;

      _lastRegistration[user.uid] = DateTime.now();

      await _auditService.logEvent(SecurityEventType.deviceRegistered, {
        'deviceId': deviceId,
        'deviceName': sanitizedDeviceName,
        'platform': validatedPlatform,
      });

      if (kDebugMode) {
        debugPrint('[DeviceSession] Device registered: $deviceId');
      }

      return DeviceRegistrationResult.success(registeredDeviceId: deviceId);
    } on SecurityException {
      return DeviceRegistrationResult.untrustedDevice();
    } on FirebaseException catch (e) {
      if (_isSessionStoreAccessError(e)) {
        _markSessionStoreUnavailable(e, operation: 'registerDevice');
        return DeviceRegistrationResult.sessionStoreUnavailable();
      }
      if (kDebugMode) {
        debugPrint('[DeviceSession] Registration failed: $e');
      }
      return DeviceRegistrationResult.sessionStoreUnavailable();
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
    String currentPlatform,
  ) async {
    final userDocFuture = _firestore.collection('users').doc(userId).get();
    final activeDevicesFuture = _getActiveDeviceSessionsForUser(userId);

    final userDoc = await userDocFuture;
    final isPremium = _isPremiumUser(userDoc.data());
    final activeDevices = await activeDevicesFuture;

    return DeviceSessionPolicy.evaluateDeviceLimit(
      isPremium: isPremium,
      currentPlatform: currentPlatform,
      currentDeviceId: currentDeviceId,
      activeDevices: activeDevices,
      freeAndroidLimit: maxFreeAndroidDevices,
      freeIosLimit: maxFreeIosDevices,
      premiumAndroidLimit: maxPremiumAndroidDevices,
      premiumIosLimit: maxPremiumIosDevices,
    );
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  _getActiveDevicesForUser(String userId) async {
    final snapshot = await _firestore
        .collection('user_sessions')
        .doc(userId)
        .collection('devices')
        .where('status', isEqualTo: 'active')
        .get();
    return snapshot.docs;
  }

  Future<void> updateActivity() async {
    if (_sessionStoreUnavailable) {
      return;
    }
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final deviceId = await _securePrefs.getRegisteredDeviceId();
      if (deviceId == null || deviceId.isEmpty) {
        return;
      }
      await _firestore
          .collection('user_sessions')
          .doc(user.uid)
          .collection('devices')
          .doc(deviceId)
          .update({'lastActive': FieldValue.serverTimestamp()});
    } on FirebaseException catch (e) {
      if (_isSessionStoreAccessError(e)) {
        _markSessionStoreUnavailable(e, operation: 'updateActivity');
        return;
      }
      if (kDebugMode) {
        debugPrint('[DeviceSession] Activity update failed: $e');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[DeviceSession] Activity update failed: $e');
      }
    }
  }

  Future<List<DeviceSession>> getActiveDevices() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      final sessions = await _getActiveDeviceSessionsForUser(user.uid);
      sessions.sort((a, b) => b.lastActive.compareTo(a.lastActive));
      return sessions;
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
        await _securePrefs.clearLastSuccessfulSessionValidationAt();
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
    if (_sessionStoreUnavailable) {
      return _allowSessionWhileStoreUnavailable();
    }
    try {
      final user = _auth.currentUser;
      if (user == null) return true;

      final deviceId = await _getDeviceId();
      final deviceDoc = await _firestore
          .collection('user_sessions')
          .doc(user.uid)
          .collection('devices')
          .doc(deviceId)
          .get();

      final session = deviceDoc.exists
          ? DeviceSession.fromFirestore(deviceDoc)
          : null;

      if (session == null) {
        // Attempt silent registration for legacy sessions missing a device document.
        final regResult = await registerDevice();
        if (regResult.success) {
          await _securePrefs.setRegisteredDeviceId(deviceId);
          await _securePrefs.setLastSuccessfulSessionValidationAt(
            DateTime.now(),
          );
          return true;
        } else if (regResult.failureCode ==
                DeviceRegistrationFailureCode.limitExceeded ||
            regResult.failureCode ==
                DeviceRegistrationFailureCode.untrustedDevice ||
            regResult.failureCode ==
                DeviceRegistrationFailureCode.verificationFailed) {
          return false;
        } else {
          return _allowSessionWhileStoreUnavailable();
        }
      }

      final decision = DeviceSessionPolicy.validateStoredSession(session);
      if (decision.shouldPersistSuccess) {
        await _securePrefs.setRegisteredDeviceId(deviceId);
        await _securePrefs.setLastSuccessfulSessionValidationAt(DateTime.now());
      } else {
        await _securePrefs.clearLastSuccessfulSessionValidationAt();
      }
      return decision.isValid;
    } on FirebaseException catch (e) {
      if (_isSessionStoreAccessError(e)) {
        _markSessionStoreUnavailable(e, operation: 'validateSession');
        return _allowSessionWhileStoreUnavailable();
      }
      if (_isTransientSessionStoreError(e)) {
        final lastSuccessfulValidationAt = await _securePrefs
            .getLastSuccessfulSessionValidationAt();
        return DeviceSessionPolicy.canUseValidationGraceWindow(
          lastSuccessfulValidationAt,
        );
      }
      if (kDebugMode) {
        debugPrint('[DeviceSession] Session validation failed: $e');
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[DeviceSession] Session validation failed: $e');
      }
      return false;
    }
  }

  Future<String> _getDeviceId() async {
    final cachedId = await _securePrefs.getDeviceId();
    if (cachedId != null && cachedId.isNotEmpty) {
      return cachedId;
    }

    final deviceId = _uuid.v4();

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

  Future<List<DeviceSession>> _getActiveDeviceSessionsForUser(
    String userId,
  ) async {
    final docs = await _getActiveDevicesForUser(userId);
    return docs
        .map(DeviceSession.fromFirestore)
        .where((session) => !session.isExpired)
        .toList(growable: false);
  }

  Future<String?> _reclaimExistingSessionForSameDevice({
    required String userId,
    required String currentDeviceId,
    required String currentDeviceName,
    required String currentPlatform,
  }) async {
    final activeDevices = await _getActiveDeviceSessionsForUser(userId);
    if (activeDevices.any((device) => device.deviceId == currentDeviceId)) {
      return currentDeviceId;
    }

    final normalizedCurrentName = _normalizeDeviceNameForMatch(
      currentDeviceName,
    );
    if (normalizedCurrentName.isEmpty) {
      return null;
    }

    final matchingDevices = activeDevices
        .where((device) {
          return device.platform.toLowerCase() == currentPlatform &&
              _normalizeDeviceNameForMatch(device.deviceName) ==
                  normalizedCurrentName;
        })
        .toList(growable: false);

    if (matchingDevices.length != 1) {
      return null;
    }

    final existingDevice = matchingDevices.single;
    await _securePrefs.setDeviceId(existingDevice.deviceId);
    await _securePrefs.setRegisteredDeviceId(existingDevice.deviceId);

    if (kDebugMode) {
      debugPrint(
        '[DeviceSession] Reclaimed existing device session '
        '${existingDevice.deviceId} for $currentDeviceName',
      );
    }

    return existingDevice.deviceId;
  }

  bool _isPremiumUser(Map<String, dynamic>? data) {
    final canonicalValue = data?['is_premium'];
    if (canonicalValue is bool) {
      return canonicalValue;
    }

    final legacyValue = data?['isPremium'];
    if (legacyValue is bool) {
      return legacyValue;
    }

    return false;
  }

  bool _isTransientSessionStoreError(FirebaseException error) {
    return const <String>{
      'aborted',
      'cancelled',
      'deadline-exceeded',
      'internal',
      'resource-exhausted',
      'unavailable',
      'unknown',
    }.contains(error.code);
  }

  bool _isSessionStoreAccessError(FirebaseException error) {
    return const <String>{
      'permission-denied',
      'failed-precondition',
    }.contains(error.code);
  }

  void _markSessionStoreUnavailable(
    FirebaseException error, {
    required String operation,
  }) {
    _sessionStoreUnavailable = true;
    if (_sessionStoreUnavailableLogged || !kDebugMode) {
      return;
    }
    _sessionStoreUnavailableLogged = true;
    debugPrint(
      '[DeviceSession] Session store unavailable during $operation '
      '(${error.code}); suppressing further startup writes for this session.',
    );
  }

  Future<bool> _allowSessionWhileStoreUnavailable() async {
    final lastSuccessfulValidationAt = await _securePrefs
        .getLastSuccessfulSessionValidationAt();
    if (DeviceSessionPolicy.canUseValidationGraceWindow(
      lastSuccessfulValidationAt,
    )) {
      return true;
    }

    final user = _auth.currentUser;
    if (user == null) {
      return false;
    }

    await _securePrefs.setLastSuccessfulSessionValidationAt(DateTime.now());
    return true;
  }

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

  String _normalizeDeviceNameForMatch(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[^a-z0-9\s\-\(\)]'), '')
        .trim();
  }

  String _validatePlatform(String platform) {
    const allowedPlatforms = [
      'android',
      'ios',
      'macos',
      'web',
      'windows',
      'linux',
      'unknown',
    ];
    final normalized = platform.toLowerCase().trim();

    return allowedPlatforms.contains(normalized) ? normalized : 'unknown';
  }
}
