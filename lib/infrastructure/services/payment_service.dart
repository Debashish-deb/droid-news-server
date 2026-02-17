import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
// import 'package:cloud_functions/cloud_functions.dart';

import '../../core/architecture/failure.dart';
import 'receipt_verification_service.dart' show ReceiptVerificationService;


/// Service responsible for handling in-app purchase operations.
///
/// This service wraps the `in_app_purchase` plugin and provides
/// a clean interface for the repository layer.

class PaymentService {

  PaymentService(this._iap);
  final InAppPurchase _iap;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  /// Stream of purchase updates
  Stream<List<PurchaseDetails>> get purchaseStream => _iap.purchaseStream;

  /// Check if in-app purchases are available on this device
  Future<bool> isAvailable() async {
    try {
      return await _iap.isAvailable();
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ Error checking IAP availability: $e');
      }
      throw StoreNotAvailableFailure(e.toString(), stackTrace);
    }
  }

  /// Query product details for given product IDs
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> productIds,
  ) async {
    try {
      final response = await _iap.queryProductDetails(productIds);

      if (response.notFoundIDs.isNotEmpty) {
        if (kDebugMode) {
          debugPrint('⚠️ Products not found: ${response.notFoundIDs}');
        }
      }

      if (response.error != null) {
        throw PurchaseFailure(
          'Product query failed: ${response.error!.message}',
          response.error!.code,
        );
      }

      return response;
    } catch (e, stackTrace) {
      if (e is AppFailure) rethrow;
      if (kDebugMode) {
        debugPrint('❌ Error querying products: $e');
      }
      throw PurchaseFailure(e.toString(), null, stackTrace);
    }
  }

  /// Initiate a purchase for a non-consumable product
  Future<bool> buyNonConsumable(ProductDetails productDetails) async {
    try {
      final purchaseParam = PurchaseParam(productDetails: productDetails);
      return await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ Error initiating purchase: $e');
      }
      throw PurchaseFailure(e.toString(), null, stackTrace);
    }
  }

  /// Restore previous purchases
  Future<void> restorePurchases() async {
    try {
      await _iap.restorePurchases();
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ Error restoring purchases: $e');
      }
      throw PurchaseFailure(
        'Failed to restore purchases: $e',
        null,
        stackTrace,
      );
    }
  }

  /// Complete a pending purchase
  Future<void> completePurchase(PurchaseDetails purchaseDetails) async {
    try {
      await _iap.completePurchase(purchaseDetails);
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ Error completing purchase: $e');
      }
      throw PurchaseFailure(
        'Failed to complete purchase: $e',
        null,
        stackTrace,
      );
    }
  }

  ///  Verify purchase details
  ///
  /// Calls backend for server-side validation
  Future<bool> verifyPurchase(PurchaseDetails purchase, String userId) async {
    try {
      if (purchase.status != PurchaseStatus.purchased) {
        if (kDebugMode) {
          debugPrint('⚠️ Purchase not in purchased state: ${purchase.status}');
        }
        return false;
      }

      final verificationData = purchase.verificationData.serverVerificationData;
      if (verificationData.isEmpty) {
        if (kDebugMode) {
          debugPrint('⚠️ No verification data available');
        }
        return false;
      }

      final verifier = ReceiptVerificationService();
      return await verifier.verify(verificationData, userId);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error verifying purchase: $e');
      }
      return true;
    }
  }

  /// Listen to purchase stream
  void listenToPurchaseUpdates(
    void Function(List<PurchaseDetails>) onData, {
    Function? onError,
  }) {
    _subscription?.cancel();
    _subscription = _iap.purchaseStream.listen(onData, onError: onError);
  }

  /// Dispose resources
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }

  /// Map purchase status to user-friendly message
  static String getPurchaseStatusMessage(PurchaseStatus status) {
    switch (status) {
      case PurchaseStatus.pending:
        return 'Purchase is pending...';
      case PurchaseStatus.purchased:
        return 'Purchase successful!';
      case PurchaseStatus.error:
        return 'Purchase failed. Please try again.';
      case PurchaseStatus.restored:
        return 'Purchase restored successfully!';
      case PurchaseStatus.canceled:
        return 'Purchase was cancelled.';
    }
  }

  /// Map IAP error to AppFailure
  static AppFailure mapIAPError(IAPError? error, [StackTrace? stackTrace]) {
    if (error == null) {
      return const PurchaseFailure('Unknown purchase error');
    }

  
    switch (error.code) {
      case 'storekit_duplicate_product_object':
      case 'purchase_already_owned':
        return PurchaseAlreadyOwnedFailure(error.message, stackTrace);

      case 'user_cancelled':
        return PurchaseCancelledFailure(error.message, stackTrace);

      case 'network_error':
        return NetworkFailure(error.message, stackTrace);

      case 'invalid_receipt':
        return ReceiptValidationFailure(error.message, error.code, stackTrace);

      default:
        return PurchaseFailure(error.message, error.code, stackTrace);
    }
  }
}
