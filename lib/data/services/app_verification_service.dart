import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:package_info_plus/package_info_plus.dart';

/// Service for app verification using Cloud Functions
/// Alternative to Firebase App Check
class AppVerificationService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Validate app authenticity before critical operations
  Future<bool> validateApp({String? operation}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final packageInfo = await PackageInfo.fromPlatform();

      final result = await _functions.httpsCallable('validateAppRequest').call({
        'appVersion': packageInfo.version,
        'platform': Platform.isAndroid ? 'android' : 'ios',
        'operation': operation ?? 'general',
      });

      return result.data['verified'] == true;
    } on FirebaseFunctionsException catch (e) {
      if (kDebugMode) {
        debugPrint('[AppVerification] Error: ${e.code} - ${e.message}');
      }

      // Return false for validation errors
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AppVerification] Unexpected error: $e');
      }
      // Fail open on unexpected errors (allow operation to continue)
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

      final result = await _functions
          .httpsCallable('validateDeviceRegistration')
          .call({
            'deviceId': deviceId,
            'platform': platform,
            'appVersion': packageInfo.version,
          });

      return {
        'validated': result.data['validated'] == true,
        'deviceId': result.data['deviceId'],
      };
    } on FirebaseFunctionsException catch (e) {
      if (kDebugMode) {
        debugPrint('[DeviceVerification] Error: ${e.code} - ${e.message}');
      }

      return {
        'validated': false,
        'error': e.message ?? 'Verification failed',
        'code': e.code,
      };
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[DeviceVerification] Unexpected error: $e');
      }

      // Fail open on unexpected errors
      return {'validated': true, 'deviceId': deviceId};
    }
  }
}
