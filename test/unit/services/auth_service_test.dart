import 'package:bdnewsreader/core/di/providers.dart';
import 'package:bdnewsreader/core/security/secure_prefs.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// These tests validate AuthService patterns without requiring Firebase
/// Firebase integration tests should use firebase_auth_mocks package
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthService (Patterns)', () {
    // Note: AuthService requires Firebase. These tests validate patterns
    // that can be tested without Firebase initialization.

    group('SharedPreferences Keys', () {
      test('TC-UNIT-001: User preference keys are properly formatted', () {
        const keys = <String, String>{
          'name': 'user_name',
          'email': 'user_email',
          'phone': 'user_phone',
          'role': 'user_role',
          'department': 'user_department',
          'image': 'user_image',
          'isLoggedIn': 'isLoggedIn',
        };

        for (final entry in keys.entries) {
          expect(entry.value, isNotEmpty);
          expect(
            entry.value.startsWith('user_') || entry.value == 'isLoggedIn',
            isTrue,
          );
        }
      });

      test('TC-UNIT-002: SharedPreferences can store profile data', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final prefs = await SharedPreferences.getInstance();

        await prefs.setString('user_name', 'Test User');
        await prefs.setString('user_email', 'test@example.com');
        await prefs.setBool('isLoggedIn', true);

        expect(prefs.getString('user_name'), 'Test User');
        expect(prefs.getString('user_email'), 'test@example.com');
        expect(prefs.getBool('isLoggedIn'), isTrue);
      });

      test(
        'TC-UNIT-003: Profile data can be cleared while preserving settings',
        () async {
          SharedPreferences.setMockInitialValues(<String, Object>{
            'user_name': 'Test User',
            'user_email': 'test@example.com',
            'isLoggedIn': true,
            'theme_mode': 2,
            'language_code': 'bn',
          });
          final prefs = await SharedPreferences.getInstance();

          // Simulate logout: clear user data but preserve settings
          final themeMode = prefs.getInt('theme_mode');
          final languageCode = prefs.getString('language_code');

          await prefs.clear();

          // Restore settings
          if (themeMode != null) {
            await prefs.setInt('theme_mode', themeMode);
          }
          if (languageCode != null) {
            await prefs.setString('language_code', languageCode);
          }

          // User data cleared
          expect(prefs.getString('user_name'), isNull);
          // Settings preserved
          expect(prefs.getInt('theme_mode'), 2);
          expect(prefs.getString('language_code'), 'bn');
        },
      );
    });

    group('Email Validation', () {
      test('TC-UNIT-004: Email regex validates correctly', () {
        final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');

        // Valid emails
        expect(emailRegex.hasMatch('user@example.com'), isTrue);
        expect(emailRegex.hasMatch('test.user@domain.org'), isTrue);
        expect(emailRegex.hasMatch('user-name@company.bd'), isTrue);

        // Invalid emails
        expect(emailRegex.hasMatch('notanemail'), isFalse);
        expect(emailRegex.hasMatch('@example.com'), isFalse);
        expect(emailRegex.hasMatch('user@'), isFalse);
        expect(emailRegex.hasMatch(''), isFalse);
      });
    });

    group('Password Validation', () {
      test('TC-UNIT-005: Password minimum length is 6', () {
        bool isValidPassword(String password) {
          return password.length >= 6;
        }

        expect(isValidPassword('123456'), isTrue);
        expect(isValidPassword('password'), isTrue);
        expect(isValidPassword('12345'), isFalse);
        expect(isValidPassword(''), isFalse);
      });
    });

    group('Profile Structure', () {
      test('TC-UNIT-006: Profile map has expected keys', () {
        final profile = <String, String>{
          'name': '',
          'email': '',
          'phone': '',
          'role': '',
          'department': '',
          'image': '',
        };

        expect(profile.containsKey('name'), isTrue);
        expect(profile.containsKey('email'), isTrue);
        expect(profile.containsKey('phone'), isTrue);
        expect(profile.containsKey('role'), isTrue);
        expect(profile.containsKey('department'), isTrue);
        expect(profile.containsKey('image'), isTrue);
      });
    });

    group('Email Verification Lifecycle', () {
      test(
        'TC-UNIT-007: signup sends verification without creating Firestore profile',
        () async {
          SharedPreferences.setMockInitialValues(<String, Object>{});
          final prefs = await SharedPreferences.getInstance();
          final auth = _MockFirebaseAuth();
          final firestore = _MockFirebaseFirestore();
          final credential = _MockUserCredential();
          final user = _MockUser();
          final providerInfo = _MockUserInfo();

          when(
            () => auth.createUserWithEmailAndPassword(
              email: 'reader@example.com',
              password: 'password123',
            ),
          ).thenAnswer((_) async => credential);
          when(() => credential.user).thenReturn(user);
          when(() => user.providerData).thenReturn(<UserInfo>[providerInfo]);
          when(
            () => providerInfo.providerId,
          ).thenReturn(EmailAuthProvider.PROVIDER_ID);
          when(() => user.emailVerified).thenReturn(false);
          when(() => user.updateDisplayName('Reader')).thenAnswer((_) async {});
          when(() => user.sendEmailVerification()).thenAnswer((_) async {});
          when(() => auth.signOut()).thenAnswer((_) async {});

          final container = ProviderContainer(
            overrides: [
              firebaseAuthProvider.overrideWithValue(auth),
              firestoreProvider.overrideWithValue(firestore),
              securePrefsProvider.overrideWithValue(_MemorySecurePrefs()),
              sharedPreferencesProvider.overrideWith((ref) => prefs),
            ],
          );
          addTearDown(container.dispose);

          final service = container.read(authFacadeProvider);
          final result = await service.signUp(
            'Reader',
            ' Reader@Example.COM ',
            'password123',
          );

          expect(result, isNull);
          verify(
            () => auth.createUserWithEmailAndPassword(
              email: 'reader@example.com',
              password: 'password123',
            ),
          ).called(1);
          verify(() => user.sendEmailVerification()).called(1);
          verify(() => auth.signOut()).called(1);
          verifyNever(() => firestore.collection('users'));
          expect(prefs.getBool('isLoggedIn'), isFalse);
        },
      );
    });
  });
}

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class _MockUserCredential extends Mock implements UserCredential {}

class _MockUser extends Mock implements User {}

class _MockUserInfo extends Mock implements UserInfo {}

class _MemorySecurePrefs extends SecurePrefs {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<String?> getString(String key) async => _values[key];

  @override
  Future<void> setString(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }

  @override
  Future<void> clearLastSuccessfulSessionValidationAt() async {}
}
