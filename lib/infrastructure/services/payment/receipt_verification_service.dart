// lib/infrastructure/services/receipt_verification_service.dart

import 'package:flutter/foundation.dart';

/// Service to handle server-side receipt validation logic.
enum ReceiptVerificationResult {
  valid,
  invalid,
  backendUnavailable,
  error,
}

extension ReceiptVerificationResultX on ReceiptVerificationResult {
  bool get grantsEntitlement => this == ReceiptVerificationResult.valid;
}

class ReceiptVerificationService {
  // Release gate: do not activate new paid entitlements from client-only stubs.
  static const bool _backendVerificationEnabled = bool.fromEnvironment(
    'ENABLE_PURCHASE_VERIFICATION_BACKEND',
    defaultValue: false,
  );

  static bool get isBackendVerificationAvailable => _backendVerificationEnabled;

  /// Verifies a purchase receipt with the backend.
  Future<ReceiptVerificationResult> verify(
    String serverVerificationData,
    String userId,
  ) async {
    if (serverVerificationData.trim().isEmpty || userId.trim().isEmpty) {
      _log('Verification skipped: missing receipt payload or userId.');
      return ReceiptVerificationResult.invalid;
    }

    if (!isBackendVerificationAvailable) {
      _log(
        '[RELEASE-GATE] Purchase verification backend unavailable. '
        'Blocking entitlement activation.',
      );
      return ReceiptVerificationResult.backendUnavailable;
    }

    try {
      /*
      final response = await http.post(
        Uri(path: 'https://your-api.com/verify-purchase'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'receipt': serverVerificationData,
          'user_id': userId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['status'] == 'valid'
            ? ReceiptVerificationResult.valid
            : ReceiptVerificationResult.invalid;
      }
      */

      _log(
        '[RELEASE-GATE] Backend verification is enabled but API integration is missing.',
      );
      return ReceiptVerificationResult.error;
    } catch (e) {
      _log('Verification error: $e');
      return ReceiptVerificationResult.error;
    }
  }

  void _log(String msg) {
    if (kDebugMode) debugPrint('[ReceiptVerification] $msg');
  }
}
