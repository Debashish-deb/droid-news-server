import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:bdnewsreader/core/utils/retry_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RetryHelper', () {
    group('Successful Operations', () {
      test('TC-UNIT-050: retry succeeds on first attempt', () async {
        var attempts = 0;
        
        final result = await RetryHelper.retry<String>(
          operation: () async {
            attempts++;
            return 'success';
          },
        );
        
        expect(result, 'success');
        expect(attempts, 1);
      });

      test('TC-UNIT-051: retry succeeds after transient failure', () async {
        var attempts = 0;
        
        final result = await RetryHelper.retry<String>(
          operation: () async {
            attempts++;
            if (attempts < 2) {
              throw const SocketException('Temporary network error');
            }
            return 'success';
          },
        );
        
        expect(result, 'success');
        expect(attempts, 2);
      });

      test('TC-UNIT-052: retry succeeds on third attempt', () async {
        var attempts = 0;
        
        final result = await RetryHelper.retry<String>(
          operation: () async {
            attempts++;
            if (attempts < 3) {
              throw const SocketException('Network error');
            }
            return 'success';
          },
        );
        
        expect(result, 'success');
        expect(attempts, 3);
      });
    });

    group('Failed Operations', () {
      test('TC-UNIT-053: retry fails after max retries', () async {
        var attempts = 0;
        
        await expectLater(
          RetryHelper.retry<String>(
            operation: () async {
              attempts++;
              throw const SocketException('Persistent failure');
            },
          ),
          throwsA(isA<SocketException>()),
        );
        
        expect(attempts, 3);
      });

      test('TC-UNIT-054: non-retryable errors fail immediately', () async {
        var attempts = 0;
        
        await expectLater(
          RetryHelper.retry<String>(
            operation: () async {
              attempts++;
              throw const FormatException('Parse error');
            },
          ),
          throwsA(isA<FormatException>()),
        );
        
        // FormatException is not retryable, should fail on first attempt
        expect(attempts, 1);
      });
    });

    group('Retryable Error Detection', () {
      test('TC-UNIT-055: SocketException is retryable', () async {
        var attempts = 0;
        
        try {
          await RetryHelper.retry<String>(
            operation: () async {
              attempts++;
              throw const SocketException('Network');
            },
            maxRetries: 2,
          );
        } catch (_) {}
        
        expect(attempts, 2); // Should retry
      });

      test('TC-UNIT-056: TimeoutException is retryable', () async {
        var attempts = 0;
        
        try {
          await RetryHelper.retry<String>(
            operation: () async {
              attempts++;
              throw TimeoutException('Timeout');
            },
            maxRetries: 2,
          );
        } catch (_) {}
        
        expect(attempts, 2); // Should retry
      });

      test('TC-UNIT-057: http.ClientException is retryable', () async {
        var attempts = 0;
        
        try {
          await RetryHelper.retry<String>(
            operation: () async {
              attempts++;
              throw http.ClientException('HTTP error');
            },
            maxRetries: 2,
          );
        } catch (_) {}
        
        expect(attempts, 2); // Should retry
      });
    });

    group('Custom Retry Logic', () {
      test('TC-UNIT-058: custom shouldRetry function is respected', () async {
        var attempts = 0;
        
        await expectLater(
          RetryHelper.retry<String>(
            operation: () async {
              attempts++;
              throw Exception('Custom error');
            },
            shouldRetry: (error) => false, // Never retry
          ),
          throwsException,
        );
        
        expect(attempts, 1); // Should not retry
      });

      test('TC-UNIT-059: custom maxRetries is respected', () async {
        var attempts = 0;
        
        try {
          await RetryHelper.retry<String>(
            operation: () async {
              attempts++;
              throw const SocketException('Error');
            },
            maxRetries: 5,
          );
        } catch (_) {}
        
        expect(attempts, 5);
      });
    });
  });
}
