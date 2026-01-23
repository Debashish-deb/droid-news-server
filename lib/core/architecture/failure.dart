/// Base class for all application failures.
///
/// All failures should extend this class to ensure consistent error handling
/// across the application. This allows for:
/// - Centralized error logging
/// - User-friendly error messages
/// - Type-safe error handling
/// - Structured error recovery strategies
sealed class AppFailure {
  const AppFailure(this.message, [this.stackTrace]);
  final String message;
  final StackTrace? stackTrace;

  /// Returns a user-friendly message for this failure.
  String get userMessage => message;

  /// Optional action label for retry/fix button
  String? get actionLabel => null;

  /// Icon to display with error
  String get icon => '⚠️';

  @override
  String toString() => 'AppFailure: $message';
}

// ============================================================================
// Network & Connectivity Failures
// ============================================================================

/// Failure indicating a network connectivity issue.
class NetworkFailure extends AppFailure {
  const NetworkFailure([
    super.message = 'Network error occurred. Please check your connection.',
    super.stackTrace,
  ]);

  @override
  String get userMessage =>
      'Unable to connect. Please check your internet connection.';

  @override
  String get actionLabel => 'Retry';

  @override
  String get icon => '📡';
}

/// Failure indicating a server error (5xx status codes).
class ServerFailure extends AppFailure {
  const ServerFailure([
    super.message = 'Server error occurred.',
    this.statusCode,
    super.stackTrace,
  ]);
  final int? statusCode;

  @override
  String get userMessage =>
      'Server is experiencing issues. Please try again later.';
}

/// Failure indicating a timeout during a network request.
class TimeoutFailure extends AppFailure {
  const TimeoutFailure([
    super.message = 'Request timed out.',
    super.stackTrace,
  ]);

  @override
  String get userMessage => 'Request timed out. Please try again.';
}

// ============================================================================
// Authentication & Authorization Failures
// ============================================================================

/// Failure indicating an authentication problem.
class AuthFailure extends AppFailure {
  const AuthFailure([
    super.message = 'Authentication failed.',
    super.stackTrace,
  ]);

  @override
  String get userMessage => 'Authentication failed. Please sign in again.';
}

/// Failure indicating the user is not authorized to perform an action.
class UnauthorizedFailure extends AppFailure {
  const UnauthorizedFailure([
    super.message = 'Unauthorized access.',
    super.stackTrace,
  ]);

  @override
  String get userMessage => 'You are not authorized to perform this action.';
}

/// Failure indicating the user's session has expired.
class SessionExpiredFailure extends AppFailure {
  const SessionExpiredFailure([
    super.message = 'Session expired.',
    super.stackTrace,
  ]);

  @override
  String get userMessage => 'Your session has expired. Please sign in again.';
}

// ============================================================================
// Subscription & Feature Access Failures
// ============================================================================

/// Failure indicating a subscription-related error.
class SubscriptionFailure extends AppFailure {
  const SubscriptionFailure([
    super.message = 'Subscription error occurred.',
    super.stackTrace,
  ]);

  @override
  String get userMessage =>
      'There was an issue with your subscription. Please try again.';
}

/// Failure indicating the user has exceeded their quota.
class QuotaExceededFailure extends AppFailure {
  const QuotaExceededFailure([
    super.message = 'Quota exceeded.',
    this.quotaType,
    super.stackTrace,
  ]);
  final String? quotaType;

  @override
  String get userMessage {
    if (quotaType != null) {
      return 'You have exceeded your $quotaType limit. Please upgrade your plan.';
    }
    return 'You have exceeded your usage limit. Please upgrade your plan.';
  }
}

/// Failure indicating a feature is locked for the current subscription tier.
class FeatureLockedFailure extends AppFailure {
  const FeatureLockedFailure(
    this.featureName,
    this.requiredTier, [
    String? message,
    StackTrace? stackTrace,
  ]) : super(
         message ??
             'Feature "$featureName" requires $requiredTier subscription.',
         stackTrace,
       );
  final String featureName;
  final String requiredTier;

  @override
  String get userMessage =>
      '$featureName is only available for $requiredTier subscribers. Upgrade to access this feature.';
}

// ============================================================================
// Payment & Purchase Failures
// ============================================================================

/// Failure indicating a general payment/purchase error.
class PurchaseFailure extends AppFailure {
  const PurchaseFailure([
    super.message = 'Purchase failed.',
    this.errorCode,
    super.stackTrace,
  ]);
  final String? errorCode;

  @override
  String get userMessage =>
      'Purchase could not be completed. Please try again.';

  @override
  String get actionLabel => 'Retry';

  @override
  String get icon => '💳';
}

/// Failure indicating user cancelled the purchase.
class PurchaseCancelledFailure extends AppFailure {
  const PurchaseCancelledFailure([
    super.message = 'Purchase cancelled by user.',
    super.stackTrace,
  ]);

  @override
  String get userMessage => 'Purchase was cancelled.';

  @override
  String get icon => '❌';
}

/// Failure indicating receipt validation failed.
class ReceiptValidationFailure extends AppFailure {
  const ReceiptValidationFailure([
    super.message = 'Receipt validation failed.',
    this.reason,
    super.stackTrace,
  ]);
  final String? reason;

  @override
  String get userMessage =>
      'Could not verify your purchase. Please contact support if you were charged.';

  @override
  String get icon => '🔒';
}

/// Failure indicating purchase is already owned.
class PurchaseAlreadyOwnedFailure extends AppFailure {
  const PurchaseAlreadyOwnedFailure([
    super.message = 'Item already purchased.',
    super.stackTrace,
  ]);

  @override
  String get userMessage => 'You already own this item.';

  @override
  String get icon => '✅';
}

/// Failure indicating store is not available.
class StoreNotAvailableFailure extends AppFailure {
  const StoreNotAvailableFailure([
    super.message = 'App store not available.',
    super.stackTrace,
  ]);

  @override
  String get userMessage =>
      'Purchase feature is currently unavailable. Please try again later.';

  @override
  String get actionLabel => 'Retry';

  @override
  String get icon => '🏪';
}

// ============================================================================
// Data & Storage Failures
// ============================================================================

/// Failure indicating a local storage operation failed.
class StorageFailure extends AppFailure {
  const StorageFailure([
    super.message = 'Storage operation failed.',
    super.stackTrace,
  ]);

  @override
  String get userMessage => 'Failed to save data locally. Please try again.';
}

/// Failure indicating data parsing or serialization failed.
class ParseFailure extends AppFailure {
  const ParseFailure([
    super.message = 'Failed to parse data.',
    super.stackTrace,
  ]);

  @override
  String get userMessage =>
      'Received invalid data from server. Please try again.';
}

/// Failure indicating the requested resource was not found.
class NotFoundFailure extends AppFailure {
  const NotFoundFailure([
    super.message = 'Resource not found.',
    super.stackTrace,
  ]);

  @override
  String get userMessage => 'The requested item could not be found.';
}

/// Failure indicating data corruption or integrity check failed.
class DataCorruptionFailure extends AppFailure {
  const DataCorruptionFailure([
    super.message = 'Data corruption detected.',
    super.stackTrace,
  ]);

  @override
  String get userMessage =>
      'Data integrity check failed. Your data may be corrupted.';
}

// ============================================================================
// ML & OCR Failures
// ============================================================================

/// Failure indicating an OCR processing error.
class OCRFailure extends AppFailure {
  const OCRFailure([
    super.message = 'OCR processing failed.',
    this.confidence,
    super.stackTrace,
  ]);
  final double? confidence;

  @override
  String get userMessage {
    if (confidence != null && confidence! < 0.7) {
      return 'Unable to read the image clearly. Please try with better lighting or a clearer image.';
    }
    return 'Failed to process the image. Please try again.';
  }
}

/// Failure indicating ML model inference failed.
class MLInferenceFailure extends AppFailure {
  const MLInferenceFailure([
    super.message = 'ML inference failed.',
    this.modelVersion,
    super.stackTrace,
  ]);
  final String? modelVersion;

  @override
  String get userMessage =>
      'AI processing failed. Please try again or contact support.';
}

/// Failure indicating the ML model is not available or not loaded.
class ModelNotAvailableFailure extends AppFailure {
  const ModelNotAvailableFailure([
    super.message = 'ML model not available.',
    super.stackTrace,
  ]);

  @override
  String get userMessage =>
      'AI features are currently unavailable. Please try again later.';
}

// ============================================================================
// Notification Failures
// ============================================================================

/// Failure indicating a push notification error.
class NotificationFailure extends AppFailure {
  const NotificationFailure([
    super.message = 'Notification operation failed.',
    super.stackTrace,
  ]);

  @override
  String get userMessage =>
      'Failed to update notification settings. Please try again.';
}

/// Failure indicating notification permission was denied.
class NotificationPermissionDeniedFailure extends AppFailure {
  const NotificationPermissionDeniedFailure([
    super.message = 'Notification permission denied.',
    super.stackTrace,
  ]);

  @override
  String get userMessage =>
      'Notification permission is required. Please enable it in settings.';
}

// ============================================================================
// Validation Failures
// ============================================================================

/// Failure indicating input validation failed.
class ValidationFailure extends AppFailure {
  const ValidationFailure([
    super.message = 'Validation failed.',
    this.fieldErrors,
    super.stackTrace,
  ]);
  final Map<String, String>? fieldErrors;

  @override
  String get userMessage {
    if (fieldErrors != null && fieldErrors!.isNotEmpty) {
      return fieldErrors!.values.first;
    }
    return 'Please check your input and try again.';
  }
}

// ============================================================================
// Generic Failures
// ============================================================================

/// Failure for unexpected errors that don't fit other categories.
class UnknownFailure extends AppFailure {
  const UnknownFailure([
    super.message = 'An unexpected error occurred.',
    super.stackTrace,
  ]);

  @override
  String get userMessage =>
      'Something went wrong. Please try again or contact support.';
}

/// Failure indicating an operation was cancelled by the user or system.
class CancelledFailure extends AppFailure {
  const CancelledFailure([
    super.message = 'Operation cancelled.',
    super.stackTrace,
  ]);

  @override
  String get userMessage => 'Operation was cancelled.';
}
