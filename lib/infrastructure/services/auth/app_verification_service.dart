// import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

import '../../../core/bootstrap/firebase_bootstrapper.dart';

/// Service for app verification using Cloud Functions
/// Alternative to Firebase App Check
class AppVerificationService {
  AppVerificationService({FirebaseAuth? auth, FirebaseAppCheck? appCheck})
    : _auth = auth ?? FirebaseAuth.instance,
      _appCheck = appCheck ?? FirebaseAppCheck.instance;

  final FirebaseAuth _auth;
  final FirebaseAppCheck _appCheck;

  /// Validate app authenticity before critical operations
  Future<bool> validateApp({String? operation}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      if (!FirebaseBootstrapper.shouldEnableAppCheck) {
        if (kDebugMode) {
          debugPrint(
            '[AppVerification] App Check disabled for this build; allowing authenticated debug flow.',
          );
        }
        return true;
      }

      final token = await _appCheck.getToken(true);
      final isValid = token != null && token.trim().isNotEmpty;
      if (!isValid && kDebugMode) {
        debugPrint(
          '[AppVerification] Missing App Check token for ${operation ?? 'unknown_operation'}.',
        );
      }
      return isValid;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AppVerification] Unexpected error: $e');
      }
      return false;
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

      final isValid = await validateApp(operation: 'device_registration');
      return {
        'validated': isValid,
        'deviceId': deviceId,
        if (!isValid) 'error': 'App verification failed',
      };
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[DeviceVerification] Unexpected error: $e');
      }

      return {
        'validated': false,
        'deviceId': deviceId,
        'error': 'App verification failed',
      };
    }
  }
}
