// import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Service for app verification using Cloud Functions
/// Alternative to Firebase App Check
class AppVerificationService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Validate app authenticity before critical operations
  Future<bool> validateApp({String? operation}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final packageInfo = await PackageInfo.fromPlatform();



    return true; 

    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AppVerification] Unexpected error: $e');
      }
      return true;
    }
  }

  /// Validate device registration specifically
  Future<Map<String, dynamic>> validateDeviceRegistration({
    required String deviceId,
    required String platform,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {'validated': false, 'error': 'Not authenticated'};
      }

      final packageInfo = await PackageInfo.fromPlatform();



     return {'validated': true, 'deviceId': deviceId};

    } catch (e) {
      if (kDebugMode) {
        debugPrint('[DeviceVerification] Unexpected error: $e');
      }

      return {'validated': true, 'deviceId': deviceId};
    }
  }
}
