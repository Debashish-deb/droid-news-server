// lib/infrastructure/auth/auth_service_impl.dart
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../persistence/vault/vault_database.dart';
import '../repositories/favorites_repository_impl.dart';
import '../../domain/facades/auth_facade.dart';
import '../../domain/repositories/premium_repository.dart';
import '../../platform/identity/session_manager.dart';
import '../../core/security/secure_prefs.dart';
import '../../core/telemetry/structured_logger.dart';

class AuthService implements AuthFacade {
  AuthService({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
    required FirebaseStorage storage,
    required IdentitySessionManager sessionManager,
    required PremiumRepository premiumRepository,
    required GoogleSignIn googleSignIn,
    required StructuredLogger logger,
    required SecurePrefs securePrefs,
  })  : _auth = auth,
        _firestore = firestore,
        _storage = storage,
        _sessionManager = sessionManager,
        _premiumRepository = premiumRepository,
        _googleSignIn = googleSignIn,
        _logger = logger,
        _securePrefs = securePrefs;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final StructuredLogger _logger;
  final IdentitySessionManager _sessionManager;
  final PremiumRepository _premiumRepository;
  final GoogleSignIn _googleSignIn;
  final SecurePrefs _securePrefs;

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

  @override
  Future<void> init() async {
    _logger.info('AuthService.init() STARTED');
    try {
      final String? loggedStatus = await _securePrefs.getString('isLoggedIn');
      final bool logged = loggedStatus == 'true';
      
      if (!logged || _auth.currentUser == null) {
        await logout(); 
      } else {
        // Updated call to repository
        await _premiumRepository.refreshStatus();
      }
    } catch (e, stack) {
      _logger.error('AuthService.init() ERROR', e, stack);
      rethrow;
    }
  }

  @override
  Future<String?> signUp(String name, String email, String password) async {
    try {
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
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

      await _cacheProfile(name: name, email: email);

      try {
        await _sessionManager.startSession(uid);
      } catch (e) {
        await logout();
        return 'Device verification failed: ${e.toString()}';
      }

      await _premiumRepository.refreshStatus();

      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  @override
  Future<String?> login(String email, String password) async {
    try {
      final UserCredential userCredential = await _auth
          .signInWithEmailAndPassword(email: email.trim(), password: password);

      final String uid = userCredential.user!.uid;
      final DocumentSnapshot<Map<String, dynamic>> doc =
          await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        await _cacheProfileMap(doc.data() ?? <String, dynamic>{});
      }

      try {
        await _sessionManager.startSession(uid);
      } catch (e) {
        await logout();
        return 'Device verification failed: ${e.toString()}';
      }

      await _premiumRepository.refreshStatus();

      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  @override
  Future<String?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return 'Google sign-in cancelled.';

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(idToken: googleAuth.idToken);

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User user = userCredential.user!;

      final DocumentSnapshot<Map<String, dynamic>> doc =
          await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) {
        await _firestore.collection('users').doc(user.uid).set(<String, dynamic>{
              'name': user.displayName ?? 'User',
              'email': user.email ?? '',
              'phone': '',
              'role': '',
              'department': '',
              'image': user.photoURL ?? '',
              'is_premium': false,
            });
      }

      await _cacheProfile(
        name: user.displayName ?? 'User',
        email: user.email ?? '',
        imagePath: user.photoURL ?? _getGravatarUrl(user.email ?? ''),
      );

      try {
        await _sessionManager.startSession(user.uid);
      } catch (e) {
        await logout();
        return 'Device verification failed: ${e.toString()}';
      }

      await _premiumRepository.refreshStatus();

      return null;
    } catch (e) {
      return 'Google Sign-in error: ${e.toString()}';
    }
  }

  @override
  Future<void> logout() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    final int? themeMode = prefs.getInt('theme_mode');
    final double? readerLineHeight = prefs.getDouble('reader_line_height');
    final double? readerContrast = prefs.getDouble('reader_contrast');
    final bool? dataSaver = prefs.getBool('data_saver_mode');
    final String? language = prefs.getString('language_code');

    await prefs.clear();

    if (themeMode != null) await prefs.setInt('theme_mode', themeMode);
    if (readerLineHeight != null) await prefs.setDouble('reader_line_height', readerLineHeight);
    if (readerContrast != null) await prefs.setDouble('reader_contrast', readerContrast);
    if (dataSaver != null) await prefs.setBool('data_saver_mode', dataSaver);
    if (language != null) await prefs.setString('language_code', language);

    await _premiumRepository.refreshStatus();
  }

  @override
  Future<String?> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Failed to send password reset email';
    }
  }

  @override
  Future<Map<String, String>> getProfile() async {
    final secure = _securePrefs;
    String image = await secure.getString(_prefsKeys['image']!) ?? '';
    final String email = await secure.getString(_prefsKeys['email']!) ?? '';

    if (image.isEmpty) {
      if (_auth.currentUser?.photoURL != null) {
        image = _auth.currentUser!.photoURL!;
      } else if (email.isNotEmpty) {
        image = _getGravatarUrl(email);
      }
    }

    return <String, String>{
      'name': await secure.getString(_prefsKeys['name']!) ?? '',
      'email': email,
      'phone': await secure.getString(_prefsKeys['phone']!) ?? '',
      'role': await secure.getString(_prefsKeys['role']!) ?? '',
      'department': await secure.getString(_prefsKeys['department']!) ?? '',
      'image': image,
    };
  }

  String _getGravatarUrl(String email) {
    if (email.isEmpty) return '';
    final hash = md5.convert(utf8.encode(email.trim().toLowerCase())).toString();
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

    if (uid != null && imagePath.isNotEmpty) {
      final bool isLocalFile = !imagePath.startsWith('http') && !imagePath.startsWith('assets/');
      if (isLocalFile) {
        try {
          final imageUrl = await _uploadImage(File(imagePath), uid);
          if (imageUrl != null) finalImageUrl = imageUrl;
        } catch (e) {
          debugPrint('❌ Failed to upload profile image: $e');
        }
      }
    }

    if (uid != null) {
      await _firestore.collection('users').doc(uid).update(<Object, Object?>{
        'name': name,
        'email': email,
        'phone': phone,
        'role': role,
        'department': department,
        'image': finalImageUrl,
      });
      
      try {
         if (finalImageUrl.isNotEmpty && finalImageUrl.startsWith('http')) {
             await _auth.currentUser?.updatePhotoURL(finalImageUrl);
         }
         await _auth.currentUser?.updateDisplayName(name);
      } catch (e, stack) {
        _logger.warning('Failed to update Firebase Auth profile', e, stack);
      }
    }

    await _cacheProfile(
      name: name,
      email: email,
      phone: phone,
      role: role,
      department: department,
      imagePath: finalImageUrl,
    );
  }

  Future<String?> _uploadImage(File imageFile, String uid) async {
      try {
        final ref = _storage.ref().child('user_avatars').child('$uid.jpg');
        final metadata = SettableMetadata(contentType: 'image/jpeg', customMetadata: {'uploaded_by': uid});
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
    await secure.setString('isLoggedIn', 'true');
  }

  Future<void> _cacheProfileMap(Map<String, dynamic> data) async {
    final secure = _securePrefs;
    await secure.setString(_prefsKeys['name']!, data['name'] ?? '');
    await secure.setString(_prefsKeys['email']!, data['email'] ?? '');
    await secure.setString(_prefsKeys['phone']!, data['phone'] ?? '');
    await secure.setString(_prefsKeys['role']!, data['role'] ?? '');
    await secure.setString(_prefsKeys['department']!, data['department'] ?? '');
    await secure.setString(_prefsKeys['image']!, data['image'] ?? '');
    await secure.setString('isLoggedIn', 'true');
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
      await _firestore.collection('users').doc(uid).set({'trial_used': true}, SetOptions(merge: true));
    } catch (e) { }
  }
}