// lib/core/utils/retry_helper.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Utility for retrying operations with exponential backoff
class RetryHelper {
  RetryHelper._(); // Private constructor prevents instantiation

  /// Execute an operation with retry logic
  ///
  /// [operation] - The async operation to execute
  /// [maxRetries] - Maximum number of retry attempts (default: 3)
  /// [shouldRetry] - Function to determine if an error is retryable (optional)
  static Future<T> retry<T>({
    required Future<T> Function() operation,
    int maxRetries = 3,
    bool Function(dynamic error)? shouldRetry,
    Duration? delayDuration,
  }) async {
    int attempt = 0;

    while (true) {
      try {
        return await operation();
      } catch (e) {
        attempt++;

        // Check if we should retry this error
        final bool isRetryable = shouldRetry?.call(e) ?? _isRetryableError(e);

        if (!isRetryable || attempt >= maxRetries) {
          debugPrint('❌ Operation failed after $attempt attempts: $e');
          rethrow;
        }

        // Calculate exponential backoff delay
        final Duration delay = Duration(seconds: _calculateDelay(attempt));

        debugPrint(
          '⚠️ Retry attempt $attempt/$maxRetries after ${delay.inSeconds}s: $e',
        );

        // Wait before retrying
        await Future<void>.delayed(delay);
      }
    }
  }

  /// Calculate exponential backoff delay
  /// Returns: 1s, 2s, 4s for attempts 1, 2, 3
  static int _calculateDelay(int attempt) {
    return 1; // Fast: max 1 second delay // Max 8 seconds
  }

  /// Determine if an error is retryable
  static bool _isRetryableError(dynamic error) {
    // Network errors - always retry
    if (error is SocketException) return true;
    if (error is TimeoutException) return true;
    if (error is http.ClientException) return true;

    // HTTP errors - retry only on 5xx (server errors) and 429 (rate limit)
    if (error is http.Response) {
      final int statusCode = error.statusCode;
      return statusCode >= 500 || statusCode == 429;
    }

    // Don't retry other errors (like parsing errors, 4xx client errors)
    return false;
  }
}
