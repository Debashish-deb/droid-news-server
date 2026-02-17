import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'package:connectivity_plus/connectivity_plus.dart';

// Global error handling and retry utility for network operations
class NetworkUtils {
  NetworkUtils();

  final Connectivity _connectivity = Connectivity();
  bool _isOnline = true;

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

  bool get isOnline => _isOnline;

  Future<T> withRetry<T>({
    required Future<T> Function() operation,
    int maxRetries = 3,
    Duration initialDelay = const Duration(seconds: 1),
    void Function(int attempt, Exception error)? onRetry,
  }) async {
    Exception? lastException;
    
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
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

      if (onRetry != null) {
        onRetry(attempt, lastException);
      }

      if (attempt < maxRetries) {
        final delay = initialDelay * (1 << (attempt - 1)); 
        await Future.delayed(delay);
      }
    }

    throw lastException ?? Exception('Unknown network error');
  }

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

// Custom exception for network errors
class NetworkException implements Exception {
  NetworkException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  
  @override
  String toString() => 'NetworkException: $message (status: $statusCode)';
}
