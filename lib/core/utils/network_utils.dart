import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Global error handling and retry utility for network operations
class NetworkUtils {
  NetworkUtils._();
  static final NetworkUtils instance = NetworkUtils._();

  final Connectivity _connectivity = Connectivity();
  bool _isOnline = true;

  /// Initialize connectivity listener
  Future<void> initialize() async {
    final result = await _connectivity.checkConnectivity();
    _isOnline = result != ConnectivityResult.none;

    _connectivity.onConnectivityChanged.listen((result) {
      _isOnline = result != ConnectivityResult.none;
      if (kDebugMode) {
        debugPrint('[NetworkUtils] Connectivity changed: $_isOnline');
      }
    });
  }

  /// Check if device is online
  bool get isOnline => _isOnline;

  /// Execute a network operation with retry strategy
  /// 
  /// [operation] - The async function to execute
  /// [maxRetries] - Maximum number of retry attempts (default: 3)
  /// [initialDelay] - Initial delay between retries (default: 1 second)
  /// [onRetry] - Callback when retrying (optional)
  /// 
  /// Returns the result on success, throws on final failure
  Future<T> withRetry<T>({
    required Future<T> Function() operation,
    int maxRetries = 3,
    Duration initialDelay = const Duration(seconds: 1),
    void Function(int attempt, Exception error)? onRetry,
  }) async {
    Exception? lastException;
    
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        // Check connectivity first
        if (!_isOnline) {
          throw NetworkException('No internet connection');
        }
        
        return await operation().timeout(
          const Duration(seconds: 30),
          onTimeout: () => throw TimeoutException('Request timed out'),
        );
      } on TimeoutException catch (e) {
        lastException = e;
        if (kDebugMode) {
          debugPrint('[NetworkUtils] Timeout on attempt $attempt');
        }
      } on NetworkException catch (e) {
        lastException = e;
        if (kDebugMode) {
          debugPrint('[NetworkUtils] Network error on attempt $attempt: ${e.message}');
        }
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
        if (kDebugMode) {
          debugPrint('[NetworkUtils] Error on attempt $attempt: $e');
        }
      }

      // Call retry callback if provided
      if (onRetry != null && lastException != null) {
        onRetry(attempt, lastException);
      }

      // Wait before next retry (exponential backoff)
      if (attempt < maxRetries) {
        final delay = initialDelay * (1 << (attempt - 1)); // 1s, 2s, 4s...
        await Future.delayed(delay);
      }
    }

    throw lastException ?? Exception('Unknown network error');
  }

  /// Execute operation with fallback value on failure
  Future<T> withFallback<T>({
    required Future<T> Function() operation,
    required T fallbackValue,
    void Function(Exception)? onError,
  }) async {
    try {
      return await withRetry(operation: operation, maxRetries: 2);
    } catch (e) {
      if (onError != null && e is Exception) {
        onError(e);
      }
      return fallbackValue;
    }
  }
}

/// Custom exception for network errors
class NetworkException implements Exception {
  final String message;
  final int? statusCode;
  
  NetworkException(this.message, {this.statusCode});
  
  @override
  String toString() => 'NetworkException: $message (status: $statusCode)';
}

/// Extension on Future for easy retry/fallback
extension FutureRetryExtension<T> on Future<T> {
  /// Add retry logic to any Future
  Future<T> withRetry({int maxRetries = 3}) {
    return NetworkUtils.instance.withRetry(
      operation: () => this,
      maxRetries: maxRetries,
    );
  }
  
  /// Add fallback value on failure
  Future<T> withFallback(T fallbackValue) {
    return NetworkUtils.instance.withFallback(
      operation: () => this,
      fallbackValue: fallbackValue,
    );
  }
}
