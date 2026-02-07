import 'dart:async';
import 'dart:io';
import '../architecture/either.dart';
import '../architecture/failure.dart';
import '../telemetry/structured_logger.dart';
import 'package:http/http.dart' as http;

/// Utility for retrying operations with exponential backoff
class RetryHelper {
  RetryHelper._();

  static final _logger = StructuredLogger();

  /// Execute an operation with retry logic and return an Either.
  static Future<Either<AppFailure, T>> retryEither<T>({
    required Future<Either<AppFailure, T>> Function() operation,
    int maxRetries = 3,
    Duration delayDuration = const Duration(seconds: 1),
    bool Function(AppFailure failure)? shouldRetry,
  }) async {
    int attempt = 0;

    while (true) {
      final result = await operation();
      
      switch (result) {
        case Right():
          return result;
        
        case Left(value: final failure):
          attempt++;
          final bool isRetryable = shouldRetry?.call(failure) ?? _isRetryableFailure(failure);

          if (!isRetryable || attempt >= maxRetries) {
            _logger.error('Operation failed after $attempt attempts', failure);
            return result;
          }

          final Duration delay = Duration(
            milliseconds: delayDuration.inMilliseconds * attempt,
          ); // Simple linear backoff
          _logger.warn('Retry attempt $attempt/$maxRetries after ${delay.inSeconds}s', {'failure': failure.toString()});

          await Future<void>.delayed(delay);
      }
    }
  }

  /// Original retry for compatibility, but updated to use logger
  static Future<T> retry<T>({
    required Future<T> Function() operation,
    int maxRetries = 3,
    Duration delayDuration = const Duration(seconds: 1),
    bool Function(dynamic error)? shouldRetry,
  }) async {
    int attempt = 0;

    while (true) {
      try {
        return await operation();
      } catch (e) {
        attempt++;

        final bool isRetryable = shouldRetry?.call(e) ?? _isRetryableError(e);

        if (!isRetryable || attempt >= maxRetries) {
          _logger.error('Operation failed after $attempt attempts', e);
          rethrow;
        }

        final Duration delay = Duration(
          milliseconds: delayDuration.inMilliseconds * attempt,
        );
        _logger.warn('Retry attempt $attempt/$maxRetries after ${delay.inSeconds}s', {'error': e.toString()});

        await Future<void>.delayed(delay);
      }
    }
  }

  static bool _isRetryableFailure(AppFailure failure) {
    if (failure is NetworkFailure) return true;
    if (failure is ServerFailure) return true;
    return false;
  }

  /// Determine if an error is retryable
  static bool _isRetryableError(dynamic error) {
    if (error is SocketException) return true;
    if (error is TimeoutException) return true;
    if (error is http.ClientException) return true;

    if (error is http.Response) {
      final int statusCode = error.statusCode;
      return statusCode >= 500 || statusCode == 429;
    }

    return false;
  }
}
