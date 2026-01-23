import '../../core/architecture/either.dart';
import '../../core/architecture/failure.dart';
import '../entities/notification_settings.dart';

/// Repository interface for notification-related operations.
abstract class NotificationRepository {
  /// Gets the current user's notification settings.
  ///
  /// Returns [Right] with notification settings,
  /// or [Left] with [StorageFailure] on error.
  Future<Either<AppFailure, NotificationSettings>> getNotificationSettings();

  /// Updates notification settings.
  ///
  /// Returns [Right] with updated settings,
  /// or [Left] with [StorageFailure]/[NotificationFailure] on error.
  Future<Either<AppFailure, NotificationSettings>> updateNotificationSettings(
    NotificationSettings settings,
  );

  /// Checks if push notifications are authorized at the system level.
  ///
  /// Returns [Right] with true if authorized, false otherwise.
  Future<Either<AppFailure, bool>> checkNotificationPermission();

  /// Requests push notification permission from the system.
  ///
  /// Returns [Right] with true if granted, false if denied,
  /// or [Left] with [NotificationPermissionDeniedFailure] on error.
  Future<Either<AppFailure, bool>> requestNotificationPermission();

  /// Registers the device for push notifications.
  ///
  /// Returns [Right] with the FCM token on success,
  /// or [Left] with [NotificationFailure] on error.
  Future<Either<AppFailure, String>> registerForPushNotifications();

  /// Unregisters the device from push notifications.
  ///
  /// Returns [Right] with void on success,
  /// or [Left] with [NotificationFailure] on error.
  Future<Either<AppFailure, void>> unregisterFromPushNotifications();

  /// Subscribes to a notification topic.
  ///
  /// Parameters:
  /// - [topic]: Topic identifier (e.g., 'news', 'breaking', category name)
  ///
  /// Returns [Right] with void on success,
  /// or [Left] with [NotificationFailure] on error.
  Future<Either<AppFailure, void>> subscribeToTopic(String topic);

  /// Unsubscribes from a notification topic.
  ///
  /// Returns [Right] with void on success,
  /// or [Left] with [NotificationFailure] on error.
  Future<Either<AppFailure, void>> unsubscribeFromTopic(String topic);
}
