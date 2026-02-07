import '../../core/architecture/either.dart';
import '../../core/architecture/failure.dart';
import 'secure_storage_service.dart';

/// Manages the lifecycle of Auth Tokens (Part of Session Orchestration).
/// 
/// Policies:
/// - Access Token: 15 minutes (Memory only - NOT IMPLEMENTED HERE, handled by State Manager)
/// - Refresh Token: 7 days (Secure Storage)
/// - Rotation: Refresh Token rotated on every use.
class TokenStorageService {

  TokenStorageService(this._storage);
  final SecureStorageService _storage;
  
  static const String _refreshTokenKey = 'auth_refresh_token';
  static const String _deviceIdKey = 'auth_device_binding_id';

  /// Persists the long-lived refresh token.
  Future<Either<AppFailure, void>> saveRefreshToken(String token) {
    return _storage.write(key: _refreshTokenKey, value: token);
  }

  /// Retrieves the refresh token for rotation.
  Future<Either<AppFailure, String?>> getRefreshToken() {
    return _storage.read(key: _refreshTokenKey);
  }

  /// Binds the session to a specific device ID.
  Future<Either<AppFailure, void>> bindDevice(String deviceId) {
    return _storage.write(key: _deviceIdKey, value: deviceId);
  }
  
  /// Verifies if the current session matches the bound device.
  Future<bool> verifyDeviceBinding(String currentDeviceId) async {
    final result = await _storage.read(key: _deviceIdKey);
    return result.fold(
      (fail) => false,
      (storedId) => storedId == currentDeviceId,
    );
  }

  /// Destroys all session artifacts (Logout/Kill Switch).
  Future<Either<AppFailure, void>> revokeSession() {
    return _storage.clearAll();
  }
}
