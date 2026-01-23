import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Service for logging security-relevant events
class SecurityAuditService {

  SecurityAuditService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  /// Log a security event to Firestore
  Future<void> logEvent(
    SecurityEventType eventType,
    Map<String, dynamic> data,
  ) async {
    try {
      final user = _auth.currentUser;
      final appVersion = await _getAppVersion();

      await _firestore.collection('security_audit_log').add({
        'userId': user?.uid,
        'email': user?.email,
        'eventType': eventType.name,
        'timestamp': FieldValue.serverTimestamp(),
        'data': data,
        'appVersion': appVersion,
        'platform': Platform.isAndroid ? 'android' : 'ios',
      });
    } catch (e) {
      // Silent fail - don't block operations if logging fails
      // In production, you might want to use Crashlytics here
    }
  }

  /// Get app version
  Future<String> _getAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.version;
    } catch (e) {
      return 'unknown';
    }
  }
}

/// Types of security events to track
enum SecurityEventType {
  // Device management
  deviceRegistered,
  deviceLimitExceeded,
  deviceRevoked,
  allDevicesRevoked,

  // Session management
  sessionValidationFailed,
  sessionExpired,

  // Suspicious activity
  suspiciousActivity,
  fingerprintMismatch,

  // Rate limiting
  rateLimitTriggered,

  // Authentication
  loginAttempt,
  logoutAttempt,
}
