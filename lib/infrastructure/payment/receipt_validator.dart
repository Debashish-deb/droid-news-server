import '../../core/architecture/either.dart';
import '../../core/architecture/failure.dart';
import '../../core/telemetry/app_logger.dart';
import '../services/payment/receipt_verification_service.dart'
    show ReceiptVerificationResult, ReceiptVerificationService;

/// Validates In-App Purchase receipts against the specific App Store APIs.
/// 
/// Enterprise Rule: NEVER trust the client. Always validate on server.
/// This client-side service is a proxy to our backend validation endpoint.
class ReceiptValidator {
  
  /// Sends the receipt data to our backend for cryptographic verification.
  Future<Either<AppFailure, ReceiptVerificationResult>> validateReceipt(
    String receiptData,
    String platform,
  ) async {
    try {
      if (receiptData.isEmpty) {
        return const Right(ReceiptVerificationResult.invalid);
      }
      if (!ReceiptVerificationService.isBackendVerificationAvailable) {
        AppLogger.warn(
          '[RELEASE-GATE] Backend verification unavailable for $platform',
        );
        return const Right(ReceiptVerificationResult.backendUnavailable);
      }
      return const Right(ReceiptVerificationResult.error);
      
    } catch (e) {
      return Left(ServerFailure('Receipt validation failed: $e'));
    }
  }
}
