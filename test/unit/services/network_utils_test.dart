// test/unit/services/network_utils_test.dart
// ============================================
// Unit tests for NetworkUtils
// ============================================

import 'package:flutter_test/flutter_test.dart';
import 'package:bdnewsreader/core/utils/network_utils.dart';
import 'package:bdnewsreader/core/security/input_sanitizer.dart';

void main() {
  group('NetworkUtils', () {
    test('withFallback should return fallback on error', () async {
      final utils = NetworkUtils();
      final result = await utils.withFallback(
        operation: () async => throw Exception('Test error'),
        fallbackValue: 'fallback',
      );
      expect(result, 'fallback');
    });
  });

  group('NetworkException', () {
    test('should contain message and status code', () {
      final exception = NetworkException('Connection failed', statusCode: 500);
      expect(exception.message, 'Connection failed');
      expect(exception.statusCode, 500);
      expect(exception.toString(), contains('Connection failed'));
      expect(exception.toString(), contains('500'));
    });
  });

  group('InputSanitizer', () {
    test('isValidExternalUrl should reject localhost', () {
      expect(InputSanitizer.isValidExternalUrl('http://localhost:8080'), isFalse);
      expect(InputSanitizer.isValidExternalUrl('http://127.0.0.1'), isFalse);
      expect(InputSanitizer.isValidExternalUrl('http://192.168.1.2'), isFalse);
      expect(InputSanitizer.isValidExternalUrl('https://example.com'), isTrue);
    });

    test('sanitizeUrl should reject javascript protocol', () {
      expect(InputSanitizer.sanitizeUrl('javascript:alert(1)'), isNull);
      expect(InputSanitizer.sanitizeUrl('data:text/html;base64,PHNjcmlwdD5hbGVydCgxKTwvc2NyaXB0Pg=='), isNull);
      expect(InputSanitizer.sanitizeUrl('https://example.com/page'), equals('https://example.com/page'));
    });
  });
}
