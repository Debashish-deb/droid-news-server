// lib/infrastructure/auth/auth_service_impl.dart
import 'dart:async' show StreamSubscription, TimeoutException, unawaited;
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../domain/facades/auth_facade.dart';
import '../../domain/repositories/premium_repository.dart';
import '../../core/config/premium_plans.dart';
import '../../core/errors/security_exception.dart';
import '../../core/security/secure_prefs.dart';
import '../../core/telemetry/structured_logger.dart';
import 'google_sign_in_warmup_coordinator.dart';
import '../persistence/auth/device_session.dart';
import '../services/auth/device_session_service.dart';
import '../services/payment/payment_service.dart';
import '../services/payment/receipt_verification_service.dart'
    show ReceiptVerificationResult;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/providers.dart';

enum _VerificationEmailSendResult { sent, cooldown, failed }

class AuthService implements AuthFacade {
  AuthService(this._ref);

  final Ref _ref;
  static const Duration _googleDeviceRegistrationTimeout = Duration(
    milliseconds: 1200,
  );
  static const Duration _startupPurchaseRestoreTimeout = Duration(seconds: 8);
  static const Duration _authRestoreTimeout = Duration(seconds: 4);
  static const Duration _verificationEmailCooldown = Duration(minutes: 2);
  static const Duration _emailUserReloadTimeout = Duration(seconds: 5);
  static const Duration _emailProfileFetchTimeout = Duration(seconds: 4);
  static const Duration _startupUserReloadTimeout = Duration(seconds: 2);
  static const Duration _postAuthSettingsHydrationTimeout = Duration(
    seconds: 2,
  );
  static const Duration _startupPremiumRefreshDelay = Duration(seconds: 6);
  static const Duration _startupPurchaseRestoreDelay = Duration(seconds: 12);
  static const Duration _startupPendingProfileSyncDelay = Duration(seconds: 24);

  // ─── Rate Limiting ────────────────────────────────────────────────────────
  static const int _maxAuthAttempts = 5;
  static const Duration _rateLimitWindow = Duration(seconds: 60);
  static const String _authRateLimitKeyPrefix = 'auth_attempts_v1';

  FirebaseAuth get _auth => _ref.read(firebaseAuthProvider);
  FirebaseFirestore get _firestore => _ref.read(firestoreProvider);
  FirebaseStorage get _storage => _ref.read(storageProvider);
  StructuredLogger get _logger => _ref.read(structuredLoggerProvider);
  PremiumRepository get _premiumRepository =>
      _ref.read(premiumRepositoryProvider);
  GoogleSignIn get _googleSignIn => _ref.read(googleSignInProvider);
  GoogleSignInWarmupCoordinator get _googleSignInWarmup =>
      _ref.read(googleSignInWarmupProvider);
  SecurePrefs get _securePrefs => _ref.read(securePrefsProvider);
  DeviceSessionService get _deviceSessions =>
      _ref.read(deviceSessionServiceProvider);
  SharedPreferences? get _prefs => _ref.read(sharedPreferencesProvider);

  StreamSubscription<List<PurchaseDetails>>? _purchaseReconciliationSub;
  final Set<String> _activePurchaseKeys = <String>{};

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
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      final String? secureLoggedStatus = await _securePrefs.getString(
        'isLoggedIn',
      );
      final bool hadSecureLoggedInMarker = secureLoggedStatus == 'true';
      final bool hadSharedLoggedInMarker = prefs.getBool('isLoggedIn') ?? false;
      final bool hadLocalLoggedInMarker =
          hadSecureLoggedInMarker || hadSharedLoggedInMarker;

      User? restoredUser = _auth.currentUser;
      if (restoredUser == null && hadLocalLoggedInMarker) {
        // Only wait if we expect a user but Firebase hasn't restored it yet.
        restoredUser = await _auth
            .authStateChanges()
            .firstWhere((user) => user != null)
            .timeout(_authRestoreTimeout, onTimeout: () => _auth.currentUser);
      }

      if (restoredUser == null) {
        if (hadLocalLoggedInMarker) {
          _logger.info(
            'AuthService.init() cleared stale local login markers',
            <String, dynamic>{
              'secureMarker': hadSecureLoggedInMarker,
              'sharedMarker': hadSharedLoggedInMarker,
            },
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
      } else if (hadSecureLoggedInMarker != hadSharedLoggedInMarker) {
        await _persistLoggedInState();
        _logger.info('AuthService.init() repaired inconsistent login markers');
      }

      _ensureStorePurchaseReconciliation();
      restoredUser = await _reloadUser(restoredUser) ?? restoredUser;
      if (_requiresEmailVerification(restoredUser) &&
          !restoredUser.emailVerified) {
        _logger.warning(
          'AuthService.init() detected an unverified email/password session. '
          'Signing out until verification is completed.',
        );
        await _auth.signOut();
        await _markLoggedOutLocallyNonDestructive();
        return;
      }
      await _hydrateCloudSettingsAfterAuth();
      _scheduleStartupPostAuthWarmups();
    } catch (e, stack) {
      _logger.error('AuthService.init() ERROR', e, stack);
      // Don't rethrow — auth init failure should not crash the app.
    }
  }

  void _scheduleStartupPostAuthWarmups() {
    unawaited(
      _runStartupWarmupAfterDelay(_startupPremiumRefreshDelay, () async {
        try {
          await _premiumRepository.refreshStatus();
        } catch (e) {
          _logger.warning('Premium refresh failed during init (non-fatal)', e);
        }
      }),
    );

    unawaited(
      _runStartupWarmupAfterDelay(
        _startupPurchaseRestoreDelay,
        _reconcileStorePurchasesAfterAuth,
      ),
    );
    unawaited(
      _runStartupWarmupAfterDelay(
        _startupPendingProfileSyncDelay,
        _flushPendingProfileSync,
      ),
    );
  }

  Future<void> _runStartupWarmupAfterDelay(
    Duration delay,
    Future<void> Function() action,
  ) async {
    await Future<void>.delayed(delay);
    if (_auth.currentUser == null) {
      return;
    }
    await action();
  }

  Future<void> _markLoggedOutLocallyNonDestructive() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await _clearCachedProfile();
    await _securePrefs.clearLastSuccessfulSessionValidationAt();
    await _securePrefs.delete(_pendingProfileSyncKey);
    await _securePrefs.delete('isLoggedIn');
    await prefs.setBool('isLoggedIn', false);
  }

  Future<void> _ensureLoggedOutMarker() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await _securePrefs.delete('isLoggedIn');
    if (prefs.getBool('isLoggedIn') != false) {
      await prefs.setBool('isLoggedIn', false);
    }
  }

  @override
  Future<String?> signUp(String name, String email, String password) async {
    final normalizedEmail = email.trim().toLowerCase();
    final rateLimitMessage = await _checkAndRecordRateLimit(normalizedEmail);
    if (rateLimitMessage != null) {
      return rateLimitMessage;
    }
    User? createdUser;
    try {
      final UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(
            email: normalizedEmail,
            password: password,
          );
      final User? user = userCredential.user;
      if (user == null) {
        return 'Unable to create your account right now. Please try again.';
      }
      createdUser = user;

      await user.updateDisplayName(name);

      if (_requiresEmailVerification(user) && !user.emailVerified) {
        await user.sendEmailVerification();
      }

      await _clearRateLimit(normalizedEmail);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    } finally {
      if (createdUser != null) {
        await _auth.signOut();
        await _markLoggedOutLocallyNonDestructive();
      }
    }
  }

  @override
  Future<String?> login(String email, String password) async {
    final normalizedEmail = email.trim().toLowerCase();
    final rateLimitMessage = await _checkAndRecordRateLimit(normalizedEmail);
    if (rateLimitMessage != null) {
      return rateLimitMessage;
    }
    try {
      final UserCredential userCredential = await _auth
          .signInWithEmailAndPassword(
            email: normalizedEmail,
            password: password,
          );
      final User? signedInUser = await _reloadUser(userCredential.user).timeout(
        _emailUserReloadTimeout,
        onTimeout: () => _auth.currentUser ?? userCredential.user,
      );
      if (signedInUser == null) {
        await _markLoggedOutLocallyNonDestructive();
        return 'Unable to complete sign in. Please try again.';
      }
      if (_requiresEmailVerification(signedInUser) &&
          !signedInUser.emailVerified) {
        return _handleUnverifiedEmailLogin(signedInUser);
      }

      await _ensureUserDocument(signedInUser);

      final String uid = signedInUser.uid;
      Map<String, dynamic>? cachedProfile;
      try {
        final doc = await _firestore
            .collection('users')
            .doc(uid)
            .get()
            .timeout(_emailProfileFetchTimeout);
        if (doc.exists) {
          cachedProfile = doc.data();
        }
      } on TimeoutException catch (_) {
        _logger.warning('Profile fetch timed out during email sign-in');
      } catch (e, stack) {
        _logger.warning('Profile fetch failed during email sign-in', e, stack);
      }

      try {
        final registration = await _awaitDeviceRegistrationWithinBudget(
          flowLabel: 'email sign-in',
        );
        if (registration == null) {
          // Continue the sign-in path while the best-effort registration
          // finishes in the background.
        } else if (!registration.success) {
          if (registration.failureCode !=
              DeviceRegistrationFailureCode.sessionStoreUnavailable) {
            await logout();
            return _deviceRegistrationMessage(registration);
          }
          _logger.warning(
            'Proceeding without device registration because the session store is unavailable.',
          );
        }
      } catch (e, stack) {
        _logger.warning(
          'Device registration failed during email sign-in',
          e,
          stack,
        );
      }

      await Future.wait([
        if (cachedProfile != null)
          _cacheProfileMap(cachedProfile)
        else
          _cacheProfile(
            name: signedInUser.displayName ?? 'User',
            email: signedInUser.email ?? normalizedEmail,
            imagePath:
                signedInUser.photoURL ??
                _getGravatarUrl(signedInUser.email ?? normalizedEmail),
          ),
        _persistLoggedInState(),
      ]);
      _ensureStorePurchaseReconciliation();
      await _hydrateCloudSettingsAfterAuth();

      unawaited(_refreshEntitlementAfterGoogleSignIn());
      unawaited(_reconcileStorePurchasesAfterAuth());
      unawaited(_flushPendingProfileSync());
      await _clearRateLimit(normalizedEmail);

      return null;
    } on TimeoutException catch (e) {
      final recoveredUser = await _reloadUser(
        _auth.currentUser,
      ).timeout(_emailUserReloadTimeout, onTimeout: () => _auth.currentUser);
      if (recoveredUser != null) {
        _logger.warning(
          'Email sign-in timed out after Firebase auth completed; recovering signed-in state',
          e,
        );
        if (_requiresEmailVerification(recoveredUser) &&
            !recoveredUser.emailVerified) {
          return _handleUnverifiedEmailLogin(recoveredUser);
        }

        await _recoverCompletedSignInAfterTimeout(
          user: recoveredUser,
          fallbackEmail: normalizedEmail,
          flowLabel: 'email sign-in',
        );
        await _clearRateLimit(normalizedEmail);
        return null;
      }
      return 'Connection timed out. Please try again.';
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e, stack) {
      _logger.error('Email sign-in failed unexpectedly', e, stack);
      return 'Unable to sign in right now. Please try again.';
    }
  }

  @override
  Future<String?> resendEmailVerification(String email, String password) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty || password.isEmpty) {
      return 'Please enter your email and password first.';
    }

    final rateLimitScope = 'verification_resend:$normalizedEmail';
    final rateLimitMessage = await _checkAndRecordRateLimit(rateLimitScope);
    if (rateLimitMessage != null) {
      return rateLimitMessage;
    }

    var shouldSignOut = false;
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
      shouldSignOut = true;

      final user = await _reloadUser(credential.user).timeout(
        _emailUserReloadTimeout,
        onTimeout: () => _auth.currentUser ?? credential.user,
      );
      if (user == null) {
        return 'Unable to load account. Please try again.';
      }

      if (!_requiresEmailVerification(user)) {
        return 'This account does not require email verification.';
      }

      if (user.emailVerified) {
        return 'Your email is already verified. Please sign in.';
      }

      final sendResult = await _sendVerificationEmailIfAllowed(
        user,
        logContext: 'explicit resend',
      );
      switch (sendResult) {
        case _VerificationEmailSendResult.sent:
          await _clearRateLimit(rateLimitScope);
          return null;
        case _VerificationEmailSendResult.cooldown:
          return 'Verification email was sent recently. Please wait before requesting another one.';
        case _VerificationEmailSendResult.failed:
          return 'Failed to send verification email. Please try again.';
      }
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Unable to resend verification email.';
    } catch (e, stack) {
      _logger.warning(
        'Verification email resend failed unexpectedly',
        e,
        stack,
      );
      return 'Unable to resend verification email right now.';
    } finally {
      if (shouldSignOut) {
        await _auth.signOut();
        await _markLoggedOutLocallyNonDestructive();
      }
    }
  }

  @override
  Future<String?> signInWithGoogle() async {
    const rateLimitScope = 'google_sign_in';
    final rateLimitMessage = await _checkAndRecordRateLimit(rateLimitScope);
    if (rateLimitMessage != null) {
      return rateLimitMessage;
    }
    try {
      _logger.info('Starting Google Sign-in flow');
      final flowWatch = Stopwatch()..start();
      final googleUser =
          _googleSignIn.currentUser ??
          await _googleSignInWarmup.takePrewarmedUser() ??
          await _googleSignIn.signIn();

      if (googleUser == null) {
        _logger.info('Google sign-in cancelled by user');
        return 'Google sign-in cancelled.';
      }

      // SECURITY: Do NOT log user email or serverClientId (PII)
      _logger.info('Google user obtained, fetching authentication tokens');
      final googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );

      _logger.info('Signing into Firebase with Google credential');
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user!;

      _logger.info('Firebase login successful, registering device');

      // Device registration: we still attempt it, but if it fails or times out,
      // we proceed with the login if the core Firebase auth was successful.
      // This solves the 'hot restart works but login fails' issue where registration
      // was likely the part timing out.
      try {
        final registration = await _awaitDeviceRegistrationWithinBudget(
          flowLabel: 'google sign-in',
        );
        if (registration == null) {
          // Background completion has already been scheduled; do not block the
          // interactive sign-in transition on a slow session-store write.
        } else if (!registration.success) {
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
      } catch (e, stack) {
        _logger.warning(
          'Device registration failed during Google sign-in',
          e,
          stack,
        );
      }

      await Future.wait([
        _cacheProfile(
          name: user.displayName ?? 'User',
          email: user.email ?? '',
          imagePath: user.photoURL ?? _getGravatarUrl(user.email ?? ''),
        ),
        _persistLoggedInState(),
      ]);

      _ensureStorePurchaseReconciliation();
      await _hydrateCloudSettingsAfterAuth();

      // Non-critical post-auth tasks run in background so the UI can
      // transition immediately after core auth succeeds.
      unawaited(_refreshEntitlementAfterGoogleSignIn());
      unawaited(_reconcileStorePurchasesAfterAuth());

      // These do not need to block the sign-in completion path.
      unawaited(_ensureUserDocument(user));
      unawaited(_flushPendingProfileSync());

      flowWatch.stop();
      _logger.info(
        'Google Sign-in flow completed successfully',
        <String, dynamic>{'durationMs': flowWatch.elapsedMilliseconds},
      );
      await _clearRateLimit(rateLimitScope);
      return null;
    } on TimeoutException catch (e) {
      final recoveredUser = _auth.currentUser;
      if (recoveredUser != null) {
        _logger.warning(
          'Google sign-in timed out after Firebase auth completed; recovering signed-in state',
          e,
        );
        await _recoverCompletedSignInAfterTimeout(
          user: recoveredUser,
          fallbackEmail: recoveredUser.email,
          flowLabel: 'google sign-in',
        );
        await _clearRateLimit(rateLimitScope);
        return null;
      }
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
      final snapshot = await userRef.get().timeout(_emailProfileFetchTimeout);
      final data = snapshot.data() ?? const <String, dynamic>{};
      final normalizedEmail = (user.email ?? '').trim().toLowerCase();
      final displayName = (user.displayName ?? '').trim();
      final existingName = (data['name'] as String? ?? '').trim();
      final photoUrl = (user.photoURL ?? '').trim();
      final existingImage = (data['image'] as String? ?? '').trim();

      final profilePatch = <String, dynamic>{
        'email': normalizedEmail,
        'email_verified': user.emailVerified,
        if (displayName.isNotEmpty && existingName.isEmpty) 'name': displayName,
        if (photoUrl.isNotEmpty && existingImage.isEmpty) 'image': photoUrl,
        'last_login_at': FieldValue.serverTimestamp(),
      };

      if (!snapshot.exists) {
        await userRef
            .set(<String, dynamic>{
              ...profilePatch,
              'name': displayName.isNotEmpty ? displayName : 'User',
              'image': photoUrl,
              'phone': '',
              'role': '',
              'department': '',
              'is_premium': false,
              'current_subscription_tier': 'free',
              'created_at': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true))
            .timeout(_emailProfileFetchTimeout);
        return;
      }

      // Existing users: never overwrite entitlement fields here.
      await userRef
          .set(profilePatch, SetOptions(merge: true))
          .timeout(_emailProfileFetchTimeout);
    } on TimeoutException catch (_) {
      _logger.warning('Timed out while ensuring user document');
    } catch (e, stack) {
      _logger.warning('Failed to ensure user document', e, stack);
    }
  }

  Future<void> _recoverCompletedSignInAfterTimeout({
    required User user,
    required String flowLabel,
    String? fallbackEmail,
  }) async {
    await _ensureUserDocument(user);

    try {
      final normalizedEmail = (user.email ?? fallbackEmail ?? '')
          .trim()
          .toLowerCase();
      await Future.wait([
        _cacheProfile(
          name: user.displayName ?? 'User',
          email: normalizedEmail,
          imagePath: user.photoURL ?? _getGravatarUrl(normalizedEmail),
        ),
        _persistLoggedInState(),
      ]).timeout(const Duration(seconds: 2));
    } on TimeoutException catch (_) {
      _logger.warning(
        'Timed out while recovering local auth state after $flowLabel',
      );
    } catch (e, stack) {
      _logger.warning(
        'Failed to recover local auth state after $flowLabel',
        e,
        stack,
      );
    }

    _ensureStorePurchaseReconciliation();
    unawaited(_hydrateCloudSettingsAfterAuth());
    unawaited(_refreshEntitlementAfterGoogleSignIn());
    unawaited(_reconcileStorePurchasesAfterAuth());
    unawaited(_flushPendingProfileSync());
  }

  @override
  Future<void> logout() async {
    await _purchaseReconciliationSub?.cancel();
    _purchaseReconciliationSub = null;
    _activePurchaseKeys.clear();
    await _auth.signOut();
    await _googleSignIn.signOut();
    _googleSignInWarmup.clear();
    final SharedPreferences prefs =
        _prefs ?? await SharedPreferences.getInstance();

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
    final rateLimitMessage = await _checkAndRecordRateLimit(email);
    if (rateLimitMessage != null) {
      return rateLimitMessage;
    }
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      await _clearRateLimit(email);
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

  Future<void> _hydrateCloudSettingsAfterAuth({
    Duration timeout = _postAuthSettingsHydrationTimeout,
  }) async {
    final orchestrator = _ref.read(syncOrchestratorProvider);
    try {
      await orchestrator.syncSettingsAfterAuth().timeout(timeout);
    } on TimeoutException catch (_) {
      _logger.info(
        'Post-auth cloud settings hydration continuing in background',
        {'timeoutMs': timeout.inMilliseconds},
      );
      orchestrator.startRealtimeSync();
    } catch (e, stack) {
      _logger.warning('Post-auth cloud settings hydration failed', e, stack);
      orchestrator.startRealtimeSync();
    }
  }

  void _ensureStorePurchaseReconciliation() {
    if (_purchaseReconciliationSub != null) {
      return;
    }

    _purchaseReconciliationSub = _ref
        .read(paymentServiceProvider)
        .purchaseStream
        .listen(
          (purchases) => unawaited(_handleStorePurchaseUpdates(purchases)),
          onError: (Object error, StackTrace stackTrace) {
            _logger.warning(
              'Store purchase reconciliation listener failed',
              error,
              stackTrace,
            );
          },
        );
  }

  Future<void> _reconcileStorePurchasesAfterAuth() async {
    try {
      final payment = _ref.read(paymentServiceProvider);
      final isAvailable = await payment.isAvailable().timeout(
        const Duration(seconds: 4),
      );
      if (!isAvailable) {
        return;
      }
      await payment.restorePurchases().timeout(_startupPurchaseRestoreTimeout);
    } on TimeoutException catch (_) {
      _logger.warning('Store purchase reconciliation timed out after auth');
    } catch (e, stack) {
      _logger.warning('Store purchase reconciliation failed', e, stack);
    }
  }

  Future<void> _handleStorePurchaseUpdates(
    List<PurchaseDetails> purchases,
  ) async {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous || purchases.isEmpty) {
      return;
    }

    for (final purchase in purchases) {
      if (purchase.status != PurchaseStatus.pending &&
          purchase.status != PurchaseStatus.purchased &&
          purchase.status != PurchaseStatus.restored) {
        continue;
      }

      final purchaseKey = _purchaseEventKey(purchase);
      if (!_activePurchaseKeys.add(purchaseKey)) {
        continue;
      }

      try {
        await _reconcileStorePurchaseLocally(purchase);
      } catch (e, stack) {
        _logger.warning('Store purchase reconciliation crashed', e, stack);
      } finally {
        _activePurchaseKeys.remove(purchaseKey);
      }
    }
  }

  String _purchaseEventKey(PurchaseDetails purchase) {
    final token = purchase.verificationData.serverVerificationData.trim();
    if (token.isNotEmpty) {
      return '${purchase.productID}:${purchase.status.name}:$token';
    }
    return '${purchase.productID}:${purchase.status.name}:${purchase.purchaseID ?? "unknown"}';
  }

  Future<void> _reconcileStorePurchaseLocally(PurchaseDetails purchase) async {
    if (purchase.status == PurchaseStatus.pending ||
        purchase.status == PurchaseStatus.canceled ||
        purchase.status == PurchaseStatus.error) {
      return;
    }

    if (purchase.status != PurchaseStatus.purchased &&
        purchase.status != PurchaseStatus.restored) {
      return;
    }

    if (!_isKnownPremiumProductId(purchase.productID)) {
      _logger.warning(
        'Ignoring unknown store purchase during reconciliation',
        <String, dynamic>{'productId': purchase.productID},
      );
      return;
    }

    final userId = _auth.currentUser?.uid ?? 'anonymous';
    final payment = _ref.read(paymentServiceProvider);
    final verification = await payment.verifyPurchase(purchase, userId);

    if (verification == ReceiptVerificationResult.backendUnavailable) {
      if (purchase.status == PurchaseStatus.restored &&
          _hasLocallyEntitledTier()) {
        await _completePurchaseIfNeededForReconciliation(
          payment,
          purchase,
          swallowErrors: true,
        );
        return;
      }
      _logger.warning(
        'Store purchase reconciliation skipped because verification backend is unavailable',
        <String, dynamic>{
          'productId': purchase.productID,
          'status': purchase.status.name,
        },
      );
      return;
    }

    if (verification != ReceiptVerificationResult.valid) {
      _logger.warning(
        'Store purchase reconciliation did not grant entitlement',
        <String, dynamic>{
          'productId': purchase.productID,
          'status': purchase.status.name,
          'verification': verification.name,
        },
      );
      return;
    }

    await _completePurchaseIfNeededForReconciliation(payment, purchase);

    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.setString('current_subscription_tier', 'pro');
    await prefs.setBool('is_premium', true);
    await prefs.setString(
      'subscription_id',
      purchase.purchaseID ?? purchase.productID,
    );
    await prefs.setString(
      'subscription_start_date',
      DateTime.now().toIso8601String(),
    );
    await prefs.remove('subscription_end_date');

    await _premiumRepository.setPremium(true);
  }

  bool _isKnownPremiumProductId(String productId) {
    return PremiumPlanConfig.allKnownProductIds.contains(productId);
  }

  bool _hasLocallyEntitledTier() {
    final prefs = _prefs;
    if (_premiumRepository.isPremium) {
      return true;
    }
    return prefs?.getBool('is_premium') ?? false;
  }

  Future<void> _completePurchaseIfNeededForReconciliation(
    PaymentService payment,
    PurchaseDetails purchase, {
    bool swallowErrors = false,
  }) async {
    if (!purchase.pendingCompletePurchase) {
      return;
    }

    try {
      await payment.completePurchase(purchase);
    } catch (e, stack) {
      if (swallowErrors) {
        _logger.warning(
          'Non-fatal store purchase completion failure during reconciliation',
          e,
          stack,
        );
        return;
      }
      rethrow;
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
    final prefs = _prefs ?? await SharedPreferences.getInstance();
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

  Future<DeviceRegistrationResult?> _awaitDeviceRegistrationWithinBudget({
    required String flowLabel,
  }) async {
    final registrationFuture = _registerCurrentDevice();
    try {
      return await registrationFuture.timeout(_googleDeviceRegistrationTimeout);
    } on TimeoutException {
      _logger.info(
        'Device registration continuing in background after sign-in budget',
        <String, dynamic>{
          'flow': flowLabel,
          'timeoutMs': _googleDeviceRegistrationTimeout.inMilliseconds,
        },
      );
      unawaited(
        _logLateDeviceRegistrationOutcome(
          registrationFuture,
          flowLabel: flowLabel,
        ),
      );
      return null;
    }
  }

  Future<void> _logLateDeviceRegistrationOutcome(
    Future<DeviceRegistrationResult> registrationFuture, {
    required String flowLabel,
  }) async {
    try {
      final result = await registrationFuture;
      if (result.success) {
        _logger.info(
          'Device registration completed in background after sign-in budget',
          <String, dynamic>{'flow': flowLabel},
        );
        return;
      }
      if (result.failureCode ==
          DeviceRegistrationFailureCode.sessionStoreUnavailable) {
        _logger.info(
          'Device registration finished without session-store access after sign-in budget',
          <String, dynamic>{'flow': flowLabel},
        );
        return;
      }
      _logger.warn(
        'Late device registration completed with a non-blocking failure',
        <String, dynamic>{
          'flow': flowLabel,
          'failureCode': result.failureCode?.value,
          'message': result.errorMessage,
        },
      );
    } catch (e, stack) {
      _logger.warning(
        'Late device registration failed after sign-in budget',
        e,
        stack,
      );
    }
  }

  bool _requiresEmailVerification(User user) {
    return user.providerData.any(
      (provider) => provider.providerId == EmailAuthProvider.PROVIDER_ID,
    );
  }

  Future<User?> _reloadUser(User? user) async {
    if (user == null) {
      return null;
    }
    try {
      await user.reload().timeout(_startupUserReloadTimeout);
    } on TimeoutException catch (_) {
      _logger.warning('Firebase user reload timed out');
    } catch (e, stack) {
      _logger.warning('Failed to reload Firebase user', e, stack);
    }
    return _auth.currentUser ?? user;
  }

  Future<String> _handleUnverifiedEmailLogin(User user) async {
    final email = (user.email ?? '').trim();
    final sendResult = await _sendVerificationEmailIfAllowed(
      user,
      logContext: 'login',
    );
    await _auth.signOut();
    await _markLoggedOutLocallyNonDestructive();

    if (sendResult == _VerificationEmailSendResult.sent) {
      if (email.isNotEmpty) {
        return 'Please verify your email address before logging in. '
            'A new verification email has been sent to $email.';
      }
      return 'Please verify your email address before logging in. '
          'A new verification email has been sent.';
    }

    return 'Please verify your email address before logging in. '
        'Check your inbox and spam folder, then try again.';
  }

  Future<_VerificationEmailSendResult> _sendVerificationEmailIfAllowed(
    User user, {
    required String logContext,
  }) async {
    final key = 'verification_email_last_sent_v1:${user.uid}';
    final now = DateTime.now().toUtc();
    final raw = await _securePrefs.getString(key);
    final lastSentAt = raw == null ? null : DateTime.tryParse(raw);

    if (lastSentAt != null &&
        now.difference(lastSentAt) < _verificationEmailCooldown) {
      return _VerificationEmailSendResult.cooldown;
    }

    try {
      await user.sendEmailVerification();
      await _securePrefs.setString(key, now.toIso8601String());
      return _VerificationEmailSendResult.sent;
    } catch (e, stack) {
      _logger.warning(
        'Failed to send email verification during $logContext',
        e,
        stack,
      );
      return _VerificationEmailSendResult.failed;
    }
  }

  String _rateLimitKeyForIdentifier(String identifier) {
    final normalized = identifier.trim().toLowerCase();
    final material = normalized.isEmpty
        ? 'anonymous'
        : sha256.convert(utf8.encode(normalized)).toString();
    return '$_authRateLimitKeyPrefix:$material';
  }

  Future<List<DateTime>> _loadAuthAttempts(String key) async {
    final raw = await _securePrefs.getString(key);
    if (raw == null || raw.isEmpty) {
      return <DateTime>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return <DateTime>[];
      }
      return decoded
          .map<DateTime?>((value) {
            if (value is int) {
              return DateTime.fromMillisecondsSinceEpoch(value);
            }
            if (value is String) {
              return DateTime.tryParse(value);
            }
            return null;
          })
          .whereType<DateTime>()
          .toList();
    } catch (e, stack) {
      _logger.warning('Failed to decode auth rate-limit state', e, stack);
      return <DateTime>[];
    }
  }

  Future<void> _persistAuthAttempts(String key, List<DateTime> attempts) async {
    if (attempts.isEmpty) {
      await _securePrefs.delete(key);
      return;
    }
    await _securePrefs.setString(
      key,
      jsonEncode(
        attempts.map((attempt) => attempt.millisecondsSinceEpoch).toList(),
      ),
    );
  }

  Future<String?> _checkAndRecordRateLimit(String identifier) async {
    final key = _rateLimitKeyForIdentifier(identifier);
    final now = DateTime.now();
    final attempts = await _loadAuthAttempts(key);
    attempts.removeWhere(
      (attempt) => now.difference(attempt) > _rateLimitWindow,
    );
    if (attempts.length >= _maxAuthAttempts) {
      await _persistAuthAttempts(key, attempts);
      return 'Too many attempts. Please try again later.';
    }
    attempts.add(now);
    await _persistAuthAttempts(key, attempts);
    return null;
  }

  Future<void> _clearRateLimit(String identifier) async {
    await _securePrefs.delete(_rateLimitKeyForIdentifier(identifier));
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
  Future<void> markTrialUsed({
    required DateTime startedAt,
    required DateTime endsAt,
  }) async {
    final String? uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('Please sign in to start your free trial.');
    }
    try {
      final userRef = _firestore.collection('users').doc(uid);
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(userRef);
        if (snapshot.data()?['trial_used'] == true) {
          throw StateError('Trial already used.');
        }
        transaction.set(userRef, <String, dynamic>{
          'trial_used': true,
          'trial_started_at': Timestamp.fromDate(startedAt.toUtc()),
          'trial_ends_at': Timestamp.fromDate(endsAt.toUtc()),
        }, SetOptions(merge: true));
      });
    } on StateError {
      rethrow;
    } catch (e) {
      _logger.warning('Failed to mark trial used', e);
      rethrow;
    }
  }
}
