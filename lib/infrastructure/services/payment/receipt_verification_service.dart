import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Service to handle server-side receipt validation logic.
enum ReceiptVerificationResult { valid, invalid, backendUnavailable, error }

extension ReceiptVerificationResultX on ReceiptVerificationResult {
  bool get grantsEntitlement => this == ReceiptVerificationResult.valid;
}

class ReceiptVerificationService {
  // Purchase activation is gated by the backend response itself, not by a
  // compile-time flag that can silently disable revenue in production.
  static bool get isBackendVerificationAvailable => true;

  Future<ReceiptVerificationResult> verifyPurchase(
    PurchaseDetails purchase,
    String userId,
  ) async {
    if (userId.trim().isEmpty) {
      _log('Verification skipped: missing userId.');
      return ReceiptVerificationResult.invalid;
    }

    try {
      final verificationData = purchase.verificationData.serverVerificationData
          .trim();
      if (verificationData.isEmpty) {
        _log('Verification skipped: missing purchase token.');
        return ReceiptVerificationResult.invalid;
      }

      final packageInfo = await PackageInfo.fromPlatform();
      final callable = FirebaseFunctions.instance.httpsCallable(
        'validateReceipt',
      );
      final platform = defaultTargetPlatform == TargetPlatform.iOS
          ? 'ios'
          : 'android';
      final payload = <String, dynamic>{
        'platform': platform,
        'packageName': packageInfo.packageName,
        'productId': purchase.productID,
        'userId': userId,
      };
      if (platform == 'ios') {
        payload['receiptData'] = verificationData;
      } else {
        payload['purchaseToken'] = verificationData;
      }

      final response = await callable.call(payload);

      final data = response.data;
      if (data is Map<Object?, Object?>) {
        final normalized = Map<String, dynamic>.fromEntries(
          data.entries.map(
            (entry) => MapEntry(entry.key.toString(), entry.value),
          ),
        );
        if (normalized['success'] == true) {
          return ReceiptVerificationResult.valid;
        }
      }
      return ReceiptVerificationResult.invalid;
    } on FirebaseFunctionsException catch (e) {
      if (_isBackendUnavailableError(e)) {
        _log('Verification backend unavailable: ${e.code} ${e.message}');
        return ReceiptVerificationResult.backendUnavailable;
      }
      _log('Verification function error: ${e.code} ${e.message}');
      return ReceiptVerificationResult.error;
    } catch (e) {
      _log('Verification error: $e');
      return ReceiptVerificationResult.error;
    }
  }

  void _log(String msg) {
    if (kDebugMode) debugPrint('[ReceiptVerification] $msg');
  }

  bool _isBackendUnavailableError(FirebaseFunctionsException error) {
    if (error.code == 'not-found' ||
        error.code == 'unavailable' ||
        error.code == 'deadline-exceeded' ||
        error.code == 'permission-denied' ||
        error.code == 'unauthenticated') {
      return true;
    }

    final message = (error.message ?? '').toLowerCase();
    return error.code == 'internal' &&
        (message.contains('insufficient permissions') ||
            message.contains('permission-denied') ||
            message.contains('permission denied') ||
            message.contains('unauthenticated'));
  }
}
