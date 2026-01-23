import '../../../core/architecture/either.dart';
import '../../../core/architecture/failure.dart';
import '../../../core/architecture/use_case.dart';
import '../../entities/notification_settings.dart';
import '../../repositories/notification_repository.dart';

/// Use case for updating notification settings.
///
/// Handles the business logic for updating user notification preferences,
/// including validation and permission checks.
class UpdateNotificationSettingsUseCase
    implements UseCase<NotificationSettings, UpdateNotificationSettingsParams> {
  const UpdateNotificationSettingsUseCase(this._repository);
  final NotificationRepository _repository;

  @override
  Future<Either<AppFailure, NotificationSettings>> execute(
    UpdateNotificationSettingsParams params,
  ) async {
    // If user is enabling push notifications, check permission first
    if (params.settings.pushNotificationsEnabled) {
      final permissionResult = await _repository.checkNotificationPermission();

      final hasPermission = permissionResult.fold(
        (failure) => false,
        (authorized) => authorized,
      );

      if (!hasPermission) {
        // Attempt to request permission
        final requestResult = await _repository.requestNotificationPermission();

        final granted = requestResult.fold(
          (failure) => false,
          (wasGranted) => wasGranted,
        );

        if (!granted) {
          return const Left(
            NotificationPermissionDeniedFailure(
              'Push notification permission is required to enable notifications',
            ),
          );
        }
      }
    }

    // Update settings
    final result = await _repository.updateNotificationSettings(
      params.settings.copyWith(updatedAt: DateTime.now()),
    );

    return result.fold((failure) => Left(failure), (settings) async {
      // Subscribe/unsubscribe from topics based on settings
      if (settings.newsUpdatesEnabled) {
        await _repository.subscribeToTopic('news');
      } else {
        await _repository.unsubscribeFromTopic('news');
      }

      if (settings.magazineUpdatesEnabled) {
        await _repository.subscribeToTopic('magazine');
      } else {
        await _repository.unsubscribeFromTopic('magazine');
      }

      return Right(settings);
    });
  }
}

/// Parameters for updating notification settings.
class UpdateNotificationSettingsParams {
  const UpdateNotificationSettingsParams({required this.settings});
  final NotificationSettings settings;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UpdateNotificationSettingsParams &&
          runtimeType == other.runtimeType &&
          settings == other.settings;

  @override
  int get hashCode => settings.hashCode;

  @override
  String toString() => 'UpdateNotificationSettingsParams(settings: $settings)';
}
