// lib/infrastructure/auth/auth_service_impl.dart
import 'dart:async' show TimeoutException, unawaited;
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../domain/facades/auth_facade.dart';
import '../../domain/repositories/premium_repository.dart';
import '../../core/errors/security_exception.dart';
import '../../core/security/secure_prefs.dart';
import '../../core/telemetry/structured_logger.dart';
import '../persistence/auth/device_session.dart';
import '../services/auth/device_session_service.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/providers.dart';

class AuthService implements AuthFacade {
  AuthService(this._ref);

  final Ref _ref;

  // ─── Rate Limiting ────────────────────────────────────────────────────────
  static const int _maxAuthAttempts = 5;
  static const Duration _rateLimitWindow = Duration(seconds: 60);
  final List<DateTime> _authAttempts = [];

  /// Returns true if the user has exceeded the auth rate limit.
  bool _isRateLimited() {
    final now = DateTime.now();
    _authAttempts.removeWhere((t) => now.difference(t) > _rateLimitWindow);
    return _authAttempts.length >= _maxAuthAttempts;
  }

  void _recordAuthAttempt() {
    _authAttempts.add(DateTime.now());
  }

  FirebaseAuth get _auth => _ref.read(firebaseAuthProvider);
  FirebaseFirestore get _firestore => _ref.read(firestoreProvider);
  FirebaseStorage get _storage => _ref.read(storageProvider);
  StructuredLogger get _logger => _ref.read(structuredLoggerProvider);
  PremiumRepository get _premiumRepository =>
      _ref.read(premiumRepositoryProvider);
  GoogleSignIn get _googleSignIn => _ref.read(googleSignInProvider);
  SecurePrefs get _securePrefs => _ref.read(securePrefsProvider);
  DeviceSessionService get _deviceSessions =>
      _ref.read(deviceSessionServiceProvider);

  @override
  User? get currentUser => _auth.currentUser;

  @override
  bool get isLoggedIn => _auth.currentUser != null;

  static const Map<String, String> _prefsKeys = <String, String>{
    'name': 'user_name',
    'email': 'user_email',
    'phone': 'user_phone',
    'role': 'user_role',
    'department': 'user_department',
    'image': 'user_image',
    'isLoggedIn': 'isLoggedIn',
  };

  static const String _pendingProfileSyncKey = 'pending_profile_sync_v1';

  @override
  Future<void> init() async {
    _logger.info('AuthService.init() STARTED');
    try {
      final String? loggedStatus = await _securePrefs.getString('isLoggedIn');
      final bool hadLocalLoggedInMarker = loggedStatus == 'true';

      User? restoredUser = _auth.currentUser;
      if (restoredUser == null && hadLocalLoggedInMarker) {
        // Only wait if we expect a user but Firebase hasn't restored it yet.
        restoredUser = await _auth
            .authStateChanges()
            .firstWhere((user) => user != null)
            .timeout(
              const Duration(seconds: 2),
              onTimeout: () => _auth.currentUser,
            );
      }

      if (restoredUser == null) {
        if (hadLocalLoggedInMarker) {
          _logger.warning(
            'AuthService.init() detected stale local login marker. '
            'Clearing local auth session non-destructively.',
          );
          await _markLoggedOutLocallyNonDestructive();
        } else {
          await _ensureLoggedOutMarker();
        }
        return;
      }

      if (!hadLocalLoggedInMarker) {
        await _persistLoggedInState();
        _logger.info('AuthService.init() repaired missing local login marker');
      }

      // Non-fatal: premium can resolve later; don't block auth init.
      try {
        await _premiumRepository.refreshStatus();
      } catch (e) {
        _logger.warning('Premium refresh failed during init (non-fatal)', e);
      }
      await _syncCloudSettingsAfterAuth();
      try {
        await _flushPendingProfileSync();
      } catch (e) {
        _logger.warning('Profile sync flush failed during init (non-fatal)', e);
      }
    } catch (e, stack) {
      _logger.error('AuthService.init() ERROR', e, stack);
      // Don't rethrow — auth init failure should not crash the app.
    }
  }

  Future<void> _markLoggedOutLocallyNonDestructive() async {
    final prefs = await SharedPreferences.getInstance();
    await _clearCachedProfile();
    await _securePrefs.clearLastSuccessfulSessionValidationAt();
    await _securePrefs.delete(_pendingProfileSyncKey);
    await prefs.setBool('isLoggedIn', false);
  }

  Future<void> _ensureLoggedOutMarker() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('isLoggedIn') != false) {
      await prefs.setBool('isLoggedIn', false);
    }
  }

  @override
  Future<String?> signUp(String name, String email, String password) async {
    if (_isRateLimited()) {
      return 'Too many attempts. Please try again later.';
    }
    _recordAuthAttempt();
    try {
      final UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(
            email: email.trim(),
            password: password,
          );
      final String uid = userCredential.user!.uid;

      await _firestore.collection('users').doc(uid).set(<String, dynamic>{
        'name': name,
        'email': email,
        'phone': '',
        'role': '',
        'department': '',
        'image': '',
        'is_premium': false,
      });

      final registration = await _registerCurrentDevice();
      if (!registration.success) {
        await logout();
        return _deviceRegistrationMessage(registration);
      }

      await _cacheProfile(name: name, email: email);
      await _persistLoggedInState();
      await _premiumRepository.refreshStatus();
      await _syncCloudSettingsAfterAuth();

      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  @override
  Future<String?> login(String email, String password) async {
    if (_isRateLimited()) {
      return 'Too many attempts. Please try again later.';
    }
    _recordAuthAttempt();
    try {
      final UserCredential userCredential = await _auth
          .signInWithEmailAndPassword(email: email.trim(), password: password);

      final String uid = userCredential.user!.uid;
      final DocumentSnapshot<Map<String, dynamic>> doc = await _firestore
          .collection('users')
          .doc(uid)
          .get();
      final registration = await _registerCurrentDevice();
      if (!registration.success) {
        await logout();
        return _deviceRegistrationMessage(registration);
      }

      if (doc.exists) {
        await _cacheProfileMap(doc.data() ?? <String, dynamic>{});
      }

      await _persistLoggedInState();
      await _premiumRepository.refreshStatus();
      await _syncCloudSettingsAfterAuth();

      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  @override
  Future<String?> signInWithGoogle() async {
    if (_isRateLimited()) {
      return 'Too many attempts. Please try again later.';
    }
    _recordAuthAttempt();
    try {
      _logger.info('Starting Google Sign-in flow');
      final flowWatch = Stopwatch()..start();
      final googleUser =
          _googleSignIn.currentUser ??
          await _googleSignIn.signInSilently().timeout(
            const Duration(milliseconds: 1200),
            onTimeout: () => null,
          ) ??
          await _googleSignIn.signIn().timeout(const Duration(seconds: 30));

      if (googleUser == null) {
        _logger.info('Google sign-in cancelled by user');
        return 'Google sign-in cancelled.';
      }

      // SECURITY: Do NOT log user email or serverClientId (PII)
      _logger.info('Google user obtained, fetching authentication tokens');
      final googleAuth = await googleUser.authentication.timeout(
        const Duration(seconds: 20),
      );

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );

      _logger.info('Signing into Firebase with Google credential');
      final userCredential = await _auth
          .signInWithCredential(credential)
          .timeout(const Duration(seconds: 20));
      final user = userCredential.user!;

      _logger.info('Firebase login successful, registering device');

      // Device registration: we still attempt it, but if it fails or times out,
      // we proceed with the login if the core Firebase auth was successful.
      // This solves the 'hot restart works but login fails' issue where registration
      // was likely the part timing out.
      try {
        final registration = await _registerCurrentDevice().timeout(
          const Duration(seconds: 6),
        );

        if (!registration.success) {
          _logger.warning(
            'Device registration failed during sign-in: ${registration.errorMessage}',
          );

          // If it's a critical security failure, we should still block.
          final isSecurityFailure =
              registration.failureCode ==
                  DeviceRegistrationFailureCode.untrustedDevice ||
              registration.failureCode ==
                  DeviceRegistrationFailureCode.verificationFailed;

          if (isSecurityFailure) {
            await logout();
            return _deviceRegistrationMessage(registration);
          }
          // Otherwise, we allow the login but log the warning.
        } else {
          _logger.info('Device registered successfully');
        }
      } catch (e) {
        _logger.warning(
          'Device registration timed out or failed during sign-in: $e',
        );
        // Non-blocking on timeout/generic error
      }

      await Future.wait([
        _cacheProfile(
          name: user.displayName ?? 'User',
          email: user.email ?? '',
          imagePath: user.photoURL ?? _getGravatarUrl(user.email ?? ''),
        ),
        _persistLoggedInState(),
      ]);

      // Non-critical post-auth tasks run in background so the UI can
      // transition immediately after core auth succeeds.
      unawaited(_refreshEntitlementAfterGoogleSignIn());
      unawaited(_syncCloudSettingsAfterAuth());

      // These do not need to block the sign-in completion path.
      unawaited(_ensureUserDocument(user));
      unawaited(_flushPendingProfileSync());

      flowWatch.stop();
      _logger.info(
        'Google Sign-in flow completed successfully',
        <String, dynamic>{'durationMs': flowWatch.elapsedMilliseconds},
      );
      return null;
    } on TimeoutException catch (e) {
      _logger.error('Google sign-in timed out', e);
      return 'Google sign-in timed out. Please try again.';
    } catch (e, stack) {
      _logger.error('Google Sign-in error', e, stack);
      // SECURITY: Do NOT expose exception details to user
      return 'Google Sign-in failed. Please try again.';
    }
  }

  Future<void> _refreshEntitlementAfterGoogleSignIn() async {
    try {
      await _premiumRepository.refreshStatus().timeout(
        const Duration(seconds: 4),
      );
    } on TimeoutException catch (_) {
      _logger.warning('Premium refresh timed out after Google sign-in');
    } catch (e, stack) {
      _logger.warning('Premium refresh failed after Google sign-in', e, stack);
    }
  }

  Future<void> _ensureUserDocument(User user) async {
    try {
      final userRef = _firestore.collection('users').doc(user.uid);
      final snapshot = await userRef.get();

      final profilePatch = <String, dynamic>{
        'name': user.displayName ?? 'User',
        'email': user.email ?? '',
        if ((user.photoURL ?? '').trim().isNotEmpty) 'image': user.photoURL,
        'last_login_at': FieldValue.serverTimestamp(),
      };

      if (!snapshot.exists) {
        await userRef.set(<String, dynamic>{
          ...profilePatch,
          'phone': '',
          'role': '',
          'department': '',
          'is_premium': false,
          'current_subscription_tier': 'free',
          'created_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return;
      }

      // Existing users: never overwrite entitlement fields here.
      await userRef.set(profilePatch, SetOptions(merge: true));
    } catch (e, stack) {
      _logger.warning('Failed to ensure Google user document', e, stack);
    }
  }

  @override
  Future<void> logout() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    final String? theme = prefs.getString('theme');
    final double? readerLineHeight = prefs.getDouble('reader_line_height');
    final double? readerContrast = prefs.getDouble('reader_contrast');
    final double? readerFontSize = prefs.getDouble('reader_font_size');
    final int? readerFontFamily = prefs.getInt('reader_font_family');
    final int? readerTheme = prefs.getInt('reader_theme');
    final bool? dataSaver = prefs.getBool('data_saver');
    final bool? pushNotif = prefs.getBool('push_notif');
    final String? language = prefs.getString('language_code');

    await prefs.clear();
    await _clearCachedProfile();
    await _securePrefs.clearLastSuccessfulSessionValidationAt();
    await _securePrefs.delete('is_premium');
    await prefs.setBool('isLoggedIn', false);

    if (theme != null) {
      await prefs.setString('theme', theme);
    }
    if (readerLineHeight != null) {
      await prefs.setDouble('reader_line_height', readerLineHeight);
    }
    if (readerContrast != null) {
      await prefs.setDouble('reader_contrast', readerContrast);
    }
    if (readerFontSize != null) {
      await prefs.setDouble('reader_font_size', readerFontSize);
    }
    if (readerFontFamily != null) {
      await prefs.setInt('reader_font_family', readerFontFamily);
    }
    if (readerTheme != null) {
      await prefs.setInt('reader_theme', readerTheme);
    }
    if (dataSaver != null) {
      await prefs.setBool('data_saver', dataSaver);
    }
    if (pushNotif != null) {
      await prefs.setBool('push_notif', pushNotif);
    }
    if (language != null) {
      await prefs.setString('language_code', language);
    }

    await _premiumRepository.refreshStatus();
  }

  @override
  Future<String?> resetPassword(String email) async {
    if (_isRateLimited()) {
      return 'Too many attempts. Please try again later.';
    }
    _recordAuthAttempt();
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return null;
    } on FirebaseAuthException catch (e) {
      _logger.warning('Password reset failed', e);
      // SECURITY: Generic message to prevent email enumeration
      return 'If an account exists with this email, a reset link has been sent.';
    }
  }

  @override
  Future<Map<String, String>> getProfile() async {
    final local = await _readLocalProfile();
    final resolvedLocal = _withResolvedImage(local);
    final hasLocalData = resolvedLocal.values.any((v) => v.trim().isNotEmpty);

    // Fast path: return cached profile immediately and refresh in background.
    if (hasLocalData) {
      unawaited(_refreshProfileCacheFromFirebase());
      return resolvedLocal;
    }

    try {
      await _refreshProfileCacheFromFirebase();
      return _withResolvedImage(await _readLocalProfile());
    } catch (e, stack) {
      _logger.warning('Profile fetch fallback to local cache', e, stack);
    }

    return resolvedLocal;
  }

  Future<void> _refreshProfileCacheFromFirebase() async {
    await _flushPendingProfileSync();
    final remote = await _fetchProfileFromFirebase();
    if (remote != null) {
      await _cacheProfileMap(remote);
    }
  }

  Future<Map<String, String>> _readLocalProfile() async {
    final secure = _securePrefs;
    return <String, String>{
      'name': await secure.getString(_prefsKeys['name']!) ?? '',
      'email': await secure.getString(_prefsKeys['email']!) ?? '',
      'phone': await secure.getString(_prefsKeys['phone']!) ?? '',
      'role': await secure.getString(_prefsKeys['role']!) ?? '',
      'department': await secure.getString(_prefsKeys['department']!) ?? '',
      'image': await secure.getString(_prefsKeys['image']!) ?? '',
    };
  }

  Map<String, String> _withResolvedImage(Map<String, String> profile) {
    var image = profile['image'] ?? '';
    final email = profile['email'] ?? '';

    if (image.isEmpty) {
      if (_auth.currentUser?.photoURL != null &&
          _auth.currentUser!.photoURL!.isNotEmpty) {
        image = _auth.currentUser!.photoURL!;
      } else if (email.isNotEmpty) {
        image = _getGravatarUrl(email);
      }
    }

    return <String, String>{
      'name': profile['name'] ?? '',
      'email': email,
      'phone': profile['phone'] ?? '',
      'role': profile['role'] ?? '',
      'department': profile['department'] ?? '',
      'image': image,
    };
  }

  Future<Map<String, dynamic>?> _fetchProfileFromFirebase() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    final doc = await _firestore
        .collection('users')
        .doc(uid)
        .get()
        .timeout(const Duration(seconds: 8));
    if (!doc.exists) return null;
    return doc.data();
  }

  Future<void> _queuePendingProfileSync(Map<String, dynamic> payload) async {
    await _securePrefs.setString(_pendingProfileSyncKey, jsonEncode(payload));
  }

  Future<void> _flushPendingProfileSync() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final raw = await _securePrefs.getString(_pendingProfileSyncKey);
    if (raw == null || raw.isEmpty) return;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;
      final payload = Map<String, dynamic>.from(decoded);
      if (payload.containsKey('updated_at_iso')) {
        payload.remove('updated_at_iso');
        payload['updated_at'] = FieldValue.serverTimestamp();
      }
      await _firestore
          .collection('users')
          .doc(uid)
          .set(payload, SetOptions(merge: true));
      await _securePrefs.delete(_pendingProfileSyncKey);
      _logger.info('Flushed pending profile sync to Firebase');
    } catch (e, stack) {
      _logger.warning('Failed to flush pending profile sync', e, stack);
    }
  }

  Future<void> _syncCloudSettingsAfterAuth() async {
    try {
      await _ref
          .read(syncOrchestratorProvider)
          .syncSettingsAfterAuth()
          .timeout(const Duration(seconds: 5));
    } on TimeoutException catch (_) {
      _logger.warning('Post-auth cloud settings sync timed out');
    } catch (e, stack) {
      _logger.warning('Post-auth cloud settings sync failed', e, stack);
    }
  }

  String _getGravatarUrl(String email) {
    if (email.isEmpty) return '';
    final hash = md5
        .convert(utf8.encode(email.trim().toLowerCase()))
        .toString();
    return 'https://www.gravatar.com/avatar/$hash?d=mp';
  }

  @override
  Future<void> updateProfile({
    required String name,
    required String email,
    String phone = '',
    String role = '',
    String department = '',
    String imagePath = '',
  }) async {
    final String? uid = _auth.currentUser?.uid;
    String finalImageUrl = imagePath;

    // 1. Optimistic Update: Save to local cache IMMEDIATELY
    // This ensures the UI reflects changes instantly and data is persisted offline
    await _cacheProfile(
      name: name,
      email: email,
      phone: phone,
      role: role,
      department: department,
      imagePath:
          imagePath, // Cache the local path temporarily if needed, or old URL
    );

    // 2. Handle Image Upload (if needed)
    if (uid != null && imagePath.isNotEmpty) {
      final bool isLocalFile =
          !imagePath.startsWith('http') && !imagePath.startsWith('assets/');
      if (isLocalFile) {
        try {
          final imageUrl = await _uploadImage(File(imagePath), uid);
          if (imageUrl != null) {
            finalImageUrl = imageUrl;
            // Update cache again with the remote URL
            await _securePrefs.setString(_prefsKeys['image']!, finalImageUrl);
          }
        } catch (e) {
          _logger.warning('❌ Failed to upload profile image', e);
          // Don't throw - allow text profile update to proceed
        }
      }
    }

    // 3. Sync to Firebase (Background / Best Effort)
    if (uid != null) {
      final queuedPayload = <String, dynamic>{
        'name': name,
        'email': email,
        'phone': phone,
        'role': role,
        'department': department,
        'image': finalImageUrl,
        'updated_at_iso': DateTime.now().toUtc().toIso8601String(),
      };
      final firestorePayload = <String, dynamic>{
        'name': name,
        'email': email,
        'phone': phone,
        'role': role,
        'department': department,
        'image': finalImageUrl,
        'updated_at': FieldValue.serverTimestamp(),
      };

      // Queue first so profile edits are never lost if app/network fails.
      await _queuePendingProfileSync(queuedPayload);

      try {
        // Use set with merge: true to handle missing documents gracefully
        await _firestore
            .collection('users')
            .doc(uid)
            .set(firestorePayload, SetOptions(merge: true));
        await _securePrefs.delete(_pendingProfileSyncKey);

        // Update Auth Profile
        if (finalImageUrl.isNotEmpty && finalImageUrl.startsWith('http')) {
          await _auth.currentUser?.updatePhotoURL(finalImageUrl);
        }
        await _auth.currentUser?.updateDisplayName(name);
      } catch (e, stack) {
        _logger.error('Failed to sync profile to Firebase', e, stack);
        // Local cache is already updated, payload remains queued for retry.
      }
    }
  }

  Future<String?> _uploadImage(File imageFile, String uid) async {
    try {
      final ref = _storage.ref().child('user_avatars').child('$uid.jpg');
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {'uploaded_by': uid},
      );
      await ref.putFile(imageFile, metadata);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return null;
    }
  }

  Future<void> _cacheProfile({
    required String name,
    required String email,
    String phone = '',
    String role = '',
    String department = '',
    String imagePath = '',
  }) async {
    final secure = _securePrefs;
    await secure.setString(_prefsKeys['name']!, name);
    await secure.setString(_prefsKeys['email']!, email);
    await secure.setString(_prefsKeys['phone']!, phone);
    await secure.setString(_prefsKeys['role']!, role);
    await secure.setString(_prefsKeys['department']!, department);
    await secure.setString(_prefsKeys['image']!, imagePath);
  }

  Future<void> _cacheProfileMap(Map<String, dynamic> data) async {
    final secure = _securePrefs;
    await secure.setString(_prefsKeys['name']!, data['name'] ?? '');
    await secure.setString(_prefsKeys['email']!, data['email'] ?? '');
    await secure.setString(_prefsKeys['phone']!, data['phone'] ?? '');
    await secure.setString(_prefsKeys['role']!, data['role'] ?? '');
    await secure.setString(_prefsKeys['department']!, data['department'] ?? '');
    await secure.setString(_prefsKeys['image']!, data['image'] ?? '');
  }

  Future<void> _persistLoggedInState() async {
    await _securePrefs.setString('isLoggedIn', 'true');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
  }

  Future<void> _clearCachedProfile() async {
    for (final key in _prefsKeys.values) {
      await _securePrefs.delete(key);
    }
    await _securePrefs.delete('isLoggedIn');
  }

  String _deviceRegistrationMessage(DeviceRegistrationResult result) {
    switch (result.failureCode) {
      case DeviceRegistrationFailureCode.limitExceeded:
        return 'Device limit exceeded for this account.';
      case DeviceRegistrationFailureCode.verificationFailed:
        return result.errorMessage ?? 'App verification failed.';
      case DeviceRegistrationFailureCode.sessionStoreUnavailable:
        return result.errorMessage ??
            'Device session storage is temporarily unavailable.';
      case DeviceRegistrationFailureCode.untrustedDevice:
        return result.errorMessage ??
            'This device does not meet the security requirements.';
      case null:
        return result.errorMessage ?? 'Device registration failed.';
    }
  }

  Future<DeviceRegistrationResult> _registerCurrentDevice() async {
    try {
      return await _deviceSessions.registerDevice();
    } on SecurityException {
      return DeviceRegistrationResult.untrustedDevice();
    }
  }

  @override
  Future<bool> hasUsedTrial() async {
    final String? uid = _auth.currentUser?.uid;
    if (uid == null) return false;
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      return doc.data()?['trial_used'] == true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> markTrialUsed() async {
    final String? uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      await _firestore.collection('users').doc(uid).set({
        'trial_used': true,
      }, SetOptions(merge: true));
    } catch (e) {
      _logger.warning('Failed to mark trial used', e);
    }
  }
}
