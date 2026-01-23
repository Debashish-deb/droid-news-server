import '../../core/architecture/either.dart';
import '../../core/architecture/failure.dart';
import '../entities/user_profile.dart';

/// Repository interface for user-related operations.
abstract class UserRepository {
  /// Gets the current authenticated user's profile.
  ///
  /// Returns [Right] with user profile,
  /// or [Left] with [AuthFailure] if not authenticated.
  Future<Either<AppFailure, UserProfile>> getCurrentUser();

  /// Updates the user's profile information.
  ///
  /// Parameters:
  /// - [displayName]: New display name (optional)
  /// - [photoUrl]: New photo URL (optional)
  ///
  /// Returns [Right] with updated profile,
  /// or [Left] with [StorageFailure]/[NetworkFailure] on error.
  Future<Either<AppFailure, UserProfile>> updateProfile({
    String? displayName,
    String? photoUrl,
  });

  /// Updates user preferences.
  ///
  /// Parameters:
  /// - [preferences]: Map of preference key-value pairs
  ///
  /// Returns [Right] with updated profile,
  /// or [Left] with [StorageFailure] on error.
  Future<Either<AppFailure, UserProfile>> updatePreferences(
    Map<String, dynamic> preferences,
  );

  /// Signs out the current user.
  ///
  /// Returns [Right] with void on success,
  /// or [Left] with [AuthFailure] on error.
  Future<Either<AppFailure, void>> signOut();

  /// Deletes the user's account and all associated data.
  ///
  /// This is a destructive operation that cannot be undone.
  ///
  /// Returns [Right] with void on success,
  /// or [Left] with [AuthFailure]/[NetworkFailure] on error.
  Future<Either<AppFailure, void>> deleteAccount();
}
