import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a device session for a user account
class DeviceSession {

  DeviceSession({
    required this.deviceId,
    required this.deviceName,
    required this.platform,
    required this.appVersion,
    required this.firstSeen, required this.lastActive, required this.loginCount, required this.status, this.fcmToken,
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

/// Result of device registration attempt
class DeviceRegistrationResult {

  const DeviceRegistrationResult._({
    required this.success,
    this.errorMessage,
    this.maxDevices,
    this.currentCount,
  });

  factory DeviceRegistrationResult.success() {
    return const DeviceRegistrationResult._(success: true);
  }

  factory DeviceRegistrationResult.limitExceeded({
    required int maxDevices,
    required int currentCount,
  }) {
    return DeviceRegistrationResult._(
      success: false,
      errorMessage: 'Device limit exceeded',
      maxDevices: maxDevices,
      currentCount: currentCount,
    );
  }

  factory DeviceRegistrationResult.error(String message) {
    return DeviceRegistrationResult._(success: false, errorMessage: message);
  }
  final bool success;
  final String? errorMessage;
  final int? maxDevices;
  final int? currentCount;
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
