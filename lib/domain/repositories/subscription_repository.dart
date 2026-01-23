import '../../core/architecture/either.dart';
import '../../core/architecture/failure.dart';
import '../entities/subscription.dart';

/// Repository interface for subscription-related operations.
abstract class SubscriptionRepository {
  /// Gets the current user's subscription.
  ///
  /// Returns [Right] with subscription details,
  /// or [Left] with [AuthFailure] if user not authenticated,
  /// or [SubscriptionFailure] on error.
  Future<Either<AppFailure, Subscription>> getCurrentSubscription();

  /// Checks if user has access to a specific feature.
  ///
  /// Parameters:
  /// - [featureId]: Unique identifier for the feature
  ///
  /// Returns [Right] with true/false,
  /// or [Left] with [SubscriptionFailure] on error.
  Future<Either<AppFailure, bool>> canAccessFeature(String featureId);

  /// Upgrades user subscription to a new tier.
  ///
  /// Parameters:
  /// - [newTier]: Target subscription tier
  ///
  /// Returns [Right] with updated subscription,
  /// or [Left] with [SubscriptionFailure] on error.
  Future<Either<AppFailure, Subscription>> upgradeSubscription(
    SubscriptionTier newTier,
  );

  /// Cancels the current subscription.
  ///
  /// Returns [Right] with cancelled subscription,
  /// or [Left] with [SubscriptionFailure] on error.
  Future<Either<AppFailure, Subscription>> cancelSubscription();

  /// Restores a previously purchased subscription.
  ///
  /// Useful for iOS/Android in-app purchases restoration.
  ///
  /// Returns [Right] with restored subscription,
  /// or [Left] with [SubscriptionFailure] if nothing to restore.
  Future<Either<AppFailure, Subscription>> restoreSubscription();

  /// Gets available subscription tiers and their features.
  ///
  /// Returns [Right] with map of tier -> feature list,
  /// or [Left] with [NetworkFailure] on error.
  Future<Either<AppFailure, Map<SubscriptionTier, List<String>>>>
  getAvailableTiers();

  /// Validates subscription status and refreshes if needed.
  ///
  /// Should be called periodically to ensure subscription is still valid.
  ///
  /// Returns [Right] with refreshed subscription,
  /// or [Left] with [SubscriptionFailure] on error.
  Future<Either<AppFailure, Subscription>> validateAndRefreshSubscription();
}
