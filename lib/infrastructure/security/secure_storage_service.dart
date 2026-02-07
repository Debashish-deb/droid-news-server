import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/architecture/failure.dart';
import '../../core/architecture/either.dart';

/// Service for storing sensitive data (Tokens, Keys) using hardware encryption.
/// 
/// Wraps [FlutterSecureStorage] with platform-specific configurations
/// to ensure data is stored in the Secure Enclave (iOS) or Keystore (Android).
class SecureStorageService {

  const SecureStorageService({FlutterSecureStorage? storage}) 
      : _storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _storage;

  AndroidOptions _getAndroidOptions() => const AndroidOptions(
    encryptedSharedPreferences: true, 
  );

  IOSOptions _getIOSOptions() => const IOSOptions(
    accessibility: KeychainAccessibility.first_unlock,
  );

  /// Writes a value to secure storage.
  Future<Either<AppFailure, void>> write({required String key, required String value}) async {
    try {
      await _storage.write(
        key: key, 
        value: value,
        iOptions: _getIOSOptions(),
        aOptions: _getAndroidOptions(),
      );
      return const Right(null);
    } catch (e) {
      return Left(StorageFailure('Secure write failed: $e'));
    }
  }

  /// Reads a value from secure storage.
  Future<Either<AppFailure, String?>> read({required String key}) async {
    try {
      final value = await _storage.read(
        key: key,
        iOptions: _getIOSOptions(),
        aOptions: _getAndroidOptions(),
      );
      return Right(value);
    } catch (e) {
      return Left(StorageFailure('Secure read failed: $e'));
    }
  }

  /// Deletes a value from secure storage.
  Future<Either<AppFailure, void>> delete({required String key}) async {
    try {
      await _storage.delete(
        key: key,
        iOptions: _getIOSOptions(),
        aOptions: _getAndroidOptions(),
      );
      return const Right(null);
    } catch (e) {
      return Left(StorageFailure('Secure delete failed: $e'));
    }
  }

  /// Clears all secure storage (Use with caution - typically on logout).
  Future<Either<AppFailure, void>> clearAll() async {
    try {
      await _storage.deleteAll(
        iOptions: _getIOSOptions(),
        aOptions: _getAndroidOptions(),
      );
      return const Right(null);
    } catch (e) {
      return Left(StorageFailure('Secure clear failed: $e'));
    }
  }
}
