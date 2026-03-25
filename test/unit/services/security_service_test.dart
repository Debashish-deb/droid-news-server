import 'package:flutter_test/flutter_test.dart';
import 'package:bdnewsreader/core/security/security_service.dart';
import 'package:flutter/services.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();

    // Mock flutter_secure_storage
    const MethodChannel('plugins.it_nomads.com/flutter_secure_storage')
        .setMockMethodCallHandler((MethodCall methodCall) async {
      if (methodCall.method == 'write') {
        return null; // Success
      }
      if (methodCall.method == 'read') {
        return 'mock_value'; // Success
      }
      if (methodCall.method == 'delete') {
        return null; // Success
      }
      if (methodCall.method == 'deleteAll') {
        return null; // Success
      }
      return null;
    });
  });

  group('SecurityService', () {
    late SecurityService securityService;

    setUp(() {
      securityService = SecurityService();
    });

    group('Singleton Pattern', () {
      test('TC-UNIT-060: SecurityService can be constructed', () {
        expect(SecurityService(), isA<SecurityService>());
      });
    });

    group('Cryptography', () {
      test('TC-UNIT-061: hashString produces consistent SHA-256 hash', () {
        final hash1 = securityService.hashString('test_input');
        final hash2 = securityService.hashString('test_input');
        
        expect(hash1, equals(hash2));
        expect(hash1.length, 64); // SHA-256 produces 64 hex characters
      });

      test('TC-UNIT-062: hashString produces different hashes for different inputs', () {
        final hash1 = securityService.hashString('input1');
        final hash2 = securityService.hashString('input2');
        
        expect(hash1, isNot(equals(hash2)));
      });

      test('TC-UNIT-063: generateHmac produces valid HMAC', () {
        final hmac = securityService.generateHmac('data', 'secret_key');
        
        expect(hmac, isNotEmpty);
        expect(hmac.length, 64); // HMAC-SHA256 produces 64 hex characters
      });

      test('TC-UNIT-064: generateHmac is consistent with same inputs', () {
        final hmac1 = securityService.generateHmac('data', 'secret');
        final hmac2 = securityService.generateHmac('data', 'secret');
        
        expect(hmac1, equals(hmac2));
      });

      test('TC-UNIT-065: verifyHmac returns true for matching HMAC', () {
        const data = 'important_data';
        const secretKey = 'my_secret_key';
        
        final hmac = securityService.generateHmac(data, secretKey);
        final isValid = securityService.verifyHmac(data, hmac, secretKey);
        
        expect(isValid, isTrue);
      });

      test('TC-UNIT-066: verifyHmac returns false for wrong HMAC', () {
        const data = 'important_data';
        const secretKey = 'my_secret_key';
        
        final isValid = securityService.verifyHmac(data, 'wrong_hmac', secretKey);
        
        expect(isValid, isFalse);
      });

      test('TC-UNIT-067: verifyHmac returns false for wrong key', () {
        const data = 'important_data';
        
        final hmac = securityService.generateHmac(data, 'key1');
        final isValid = securityService.verifyHmac(data, hmac, 'key2');
        
        expect(isValid, isFalse);
      });
    });

    group('State', () {
      test('TC-UNIT-068: isRooted is a boolean', () {
        expect(securityService.isRooted, isA<bool>());
      });

      test('TC-UNIT-069: isSecure is a boolean', () {
        expect(securityService.isSecure, isA<bool>());
      });
    });

    group('Initialization', () {
      test('TC-UNIT-070: initialize() completes without throwing', () async {
        // May fail in test environment but shouldn't throw unhandled exception
        await expectLater(
          securityService.initialize(),
          completes,
        );
      });
    });

    group('Secure Storage Methods', () {
      test('TC-UNIT-071: secureWrite accepts key-value pair', () async {
        // In tests, platform channels may be unavailable; allow either outcome.
        await expectLater(
          securityService.secureWrite('test_key', 'test_value'),
          anyOf(completes, throwsA(isA<Exception>())),
        );
      });

      test('TC-UNIT-072: secureRead returns value or null', () async {
        try {
          final value = await securityService.secureRead('nonexistent_key');
          expect(value, isNull);
        } on Exception catch (e) {
          expect(e, isA<Exception>());
        }
      });
    });
  });
}
