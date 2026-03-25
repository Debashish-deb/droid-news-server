// ignore_for_file: avoid_classes_with_only_static_members, sort_constructors_first

import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a device session for a user account
class DeviceSession {
  DeviceSession({
    required this.deviceId,
    required this.deviceName,
    required this.platform,
    required this.appVersion,
    required this.firstSeen,
    required this.lastActive,
    required this.loginCount,
    required this.status,
    this.fcmToken,
    this.ipAddress,
    this.location,
  });

  factory DeviceSession.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DeviceSession(
      deviceId: doc.id,
      deviceName: data['deviceName'] ?? 'Unknown Device',
      platform: data['platform'] ?? 'unknown',
      appVersion: data['appVersion'] ?? '0.0.0',
      fcmToken: data['fcmToken'],
      firstSeen: (data['firstSeen'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastActive:
          (data['lastActive'] as Timestamp?)?.toDate() ?? DateTime.now(),
      loginCount: data['loginCount'] ?? 0,
      ipAddress: data['ipAddress'],
      location: data['location'],
      status: DeviceStatus.fromString(data['status'] ?? 'active'),
    );
  }
  final String deviceId;
  final String deviceName;
  final String platform;
  final String appVersion;
  final String? fcmToken;
  final DateTime firstSeen;
  final DateTime lastActive;
  final int loginCount;
  final String? ipAddress;
  final String? location;
  final DeviceStatus status;

  Map<String, dynamic> toFirestore() {
    return {
      'deviceId': deviceId,
      'deviceName': deviceName,
      'platform': platform,
      'appVersion': appVersion,
      if (fcmToken != null) 'fcmToken': fcmToken,
      'firstSeen': Timestamp.fromDate(firstSeen),
      'lastActive': Timestamp.fromDate(lastActive),
      'loginCount': loginCount,
      if (ipAddress != null) 'ipAddress': ipAddress,
      if (location != null) 'location': location,
      'status': status.value,
    };
  }

  bool get isActive => status == DeviceStatus.active;
  bool get isExpired {
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    return lastActive.isBefore(thirtyDaysAgo);
  }
}

enum DeviceStatus {
  active('active'),
  revoked('revoked'),
  expired('expired');

  final String value;
  const DeviceStatus(this.value);

  static DeviceStatus fromString(String value) {
    return DeviceStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => DeviceStatus.active,
    );
  }
}

enum DeviceRegistrationFailureCode {
  limitExceeded('limit_exceeded'),
  verificationFailed('verification_failed'),
  sessionStoreUnavailable('session_store_unavailable'),
  untrustedDevice('untrusted_device');

  const DeviceRegistrationFailureCode(this.value);
  final String value;
}

/// Result of device registration attempt
class DeviceRegistrationResult {
  const DeviceRegistrationResult._({
    required this.success,
    this.errorMessage,
    this.failureCode,
    this.maxDevices,
    this.currentCount,
    this.registeredDeviceId,
  });

  factory DeviceRegistrationResult.success({String? registeredDeviceId}) {
    return DeviceRegistrationResult._(
      success: true,
      registeredDeviceId: registeredDeviceId,
    );
  }

  factory DeviceRegistrationResult.limitExceeded({
    required int maxDevices,
    required int currentCount,
  }) {
    return DeviceRegistrationResult._(
      success: false,
      errorMessage: 'Device limit exceeded',
      failureCode: DeviceRegistrationFailureCode.limitExceeded,
      maxDevices: maxDevices,
      currentCount: currentCount,
    );
  }

  factory DeviceRegistrationResult.error(
    String message, {
    DeviceRegistrationFailureCode? code,
  }) {
    return DeviceRegistrationResult._(
      success: false,
      errorMessage: message,
      failureCode: code,
    );
  }

  factory DeviceRegistrationResult.sessionStoreUnavailable() {
    return const DeviceRegistrationResult._(
      success: false,
      errorMessage:
          'Device session storage is temporarily unavailable. Please try again.',
      failureCode: DeviceRegistrationFailureCode.sessionStoreUnavailable,
    );
  }

  factory DeviceRegistrationResult.untrustedDevice() {
    return const DeviceRegistrationResult._(
      success: false,
      errorMessage:
          'This device did not meet the security requirements for sign-in.',
      failureCode: DeviceRegistrationFailureCode.untrustedDevice,
    );
  }

  factory DeviceRegistrationResult.verificationFailed() {
    return const DeviceRegistrationResult._(
      success: false,
      errorMessage:
          'App verification failed. Please ensure you are using the official app.',
      failureCode: DeviceRegistrationFailureCode.verificationFailed,
    );
  }
  final bool success;
  final String? errorMessage;
  final DeviceRegistrationFailureCode? failureCode;
  final int? maxDevices;
  final int? currentCount;
  final String? registeredDeviceId;
}

/// Result of device limit check
class DeviceLimitCheck {
  const DeviceLimitCheck({
    required this.allowed,
    required this.maxDevices,
    required this.currentCount,
  });
  final bool allowed;
  final int maxDevices;
  final int currentCount;
}

class SessionValidationDecision {
  const SessionValidationDecision({
    required this.isValid,
    this.reason,
    this.shouldPersistSuccess = false,
  });

  final bool isValid;
  final String? reason;
  final bool shouldPersistSuccess;
}

class DeviceSessionPolicy {
  static const Duration validationGraceWindow = Duration(hours: 24);

  static DeviceLimitCheck evaluateDeviceLimit({
    required bool isPremium,
    required String currentPlatform,
    required String currentDeviceId,
    required List<DeviceSession> activeDevices,
    required int freeAndroidLimit,
    required int freeIosLimit,
    required int premiumAndroidLimit,
    required int premiumIosLimit,
  }) {
    final isCurrentDeviceKnown = activeDevices.any(
      (device) => device.deviceId == currentDeviceId,
    );
    final maxDevices = _totalLimit(
      isPremium: isPremium,
      freeAndroidLimit: freeAndroidLimit,
      freeIosLimit: freeIosLimit,
      premiumAndroidLimit: premiumAndroidLimit,
      premiumIosLimit: premiumIosLimit,
    );

    if (isCurrentDeviceKnown) {
      return DeviceLimitCheck(
        allowed: true,
        maxDevices: maxDevices,
        currentCount: activeDevices.length,
      );
    }

    final platformCount = activeDevices
        .where((device) => device.platform.toLowerCase() == currentPlatform)
        .length;
    final platformLimit = _platformLimit(
      isPremium: isPremium,
      platform: currentPlatform,
      freeAndroidLimit: freeAndroidLimit,
      freeIosLimit: freeIosLimit,
      premiumAndroidLimit: premiumAndroidLimit,
      premiumIosLimit: premiumIosLimit,
    );

    return DeviceLimitCheck(
      allowed: platformCount < platformLimit,
      maxDevices: maxDevices,
      currentCount: activeDevices.length,
    );
  }

  static SessionValidationDecision validateStoredSession(
    DeviceSession? session,
  ) {
    if (session == null) {
      return const SessionValidationDecision(
        isValid: false,
        reason: 'missing_device',
      );
    }
    if (!session.isActive) {
      return const SessionValidationDecision(
        isValid: false,
        reason: 'revoked_device',
      );
    }
    if (session.isExpired) {
      return const SessionValidationDecision(
        isValid: false,
        reason: 'expired_device',
      );
    }
    return const SessionValidationDecision(
      isValid: true,
      shouldPersistSuccess: true,
    );
  }

  static bool canUseValidationGraceWindow(
    DateTime? lastSuccessfulValidationAt, {
    DateTime? now,
    Duration graceWindow = validationGraceWindow,
  }) {
    if (lastSuccessfulValidationAt == null) {
      return false;
    }
    final currentTime = now ?? DateTime.now();
    return currentTime.difference(lastSuccessfulValidationAt) <= graceWindow;
  }

  static int _platformLimit({
    required bool isPremium,
    required String platform,
    required int freeAndroidLimit,
    required int freeIosLimit,
    required int premiumAndroidLimit,
    required int premiumIosLimit,
  }) {
    switch (platform) {
      case 'android':
        return isPremium ? premiumAndroidLimit : freeAndroidLimit;
      case 'ios':
        return isPremium ? premiumIosLimit : freeIosLimit;
      default:
        // Generous limit for desktop/web testing
        return 3;
    }
  }

  static int _totalLimit({
    required bool isPremium,
    required int freeAndroidLimit,
    required int freeIosLimit,
    required int premiumAndroidLimit,
    required int premiumIosLimit,
  }) {
    return isPremium
        ? premiumAndroidLimit + premiumIosLimit + 3
        : freeAndroidLimit + freeIosLimit + 3;
  }
}
