import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../bootstrap/di/injection_container.dart';
import '../../../core/security/secure_prefs.dart';
import '../../../core/premium_service.dart';
// import 'package:bdnewsreader/infrastructure/services/device_session_service.dart'; // Deprecated
import '../../../platform/identity/session_manager.dart';

class AuthService extends ChangeNotifier {
  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    IdentitySessionManager? sessionManager,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _sessionManager = sessionManager ?? sl<IdentitySessionManager>();

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  late final IdentitySessionManager _sessionManager;

  PremiumService? _premiumService;

  User? get currentUser => _auth.currentUser;
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

  /// Initialize AuthService with PremiumService reference
  Future<void> init({PremiumService? premiumService}) async {
    _premiumService = premiumService;
    final String? loggedStatus = await sl<SecurePrefs>().getString('isLoggedIn');
    final bool logged = loggedStatus == 'true';
    if (!logged || _auth.currentUser == null) {
      await logout(); 
    } else {
      await _premiumService?.reloadStatus();
      // Sync to Firestore if developer
      if (_premiumService?.isPremium == true) {
         await _firestore.collection('users').doc(_auth.currentUser!.uid).update({'is_premium': true});
      }
    }
    notifyListeners();
  }

  Future<String?> signUp(String name, String email, String password) async {
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
      });

      await _cacheProfile(name: name, email: email);

      await _cacheProfile(name: name, email: email);

      try {
        await _sessionManager.startSession(uid);
      } catch (e) {
        await logout();
        return 'Device verification failed: ${e.toString()}';
      }

      await _premiumService?.reloadStatus();
      if (_premiumService?.isPremium == true) {
         final String uid = _auth.currentUser!.uid;
         await _firestore.collection('users').doc(uid).update({'is_premium': true});
      }

      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

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

      await _premiumService?.reloadStatus();
      if (_premiumService?.isPremium == true) {
        final String uid = _auth.currentUser!.uid;
        await _firestore.collection('users').doc(uid).update({'is_premium': true});
      }

      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  Future<String?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return 'Google sign-in cancelled.';

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );
      final User user = userCredential.user!;

      final DocumentSnapshot<Map<String, dynamic>> doc =
          await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .set(<String, dynamic>{
              'name': user.displayName ?? 'User',
              'email': user.email ?? '',
              'phone': '',
              'role': '',
              'department': '',
              'image': user.photoURL ?? '',
            });
      }

      await _cacheProfile(
        name: user.displayName ?? 'User',
        email: user.email ?? '',
        imagePath: user.photoURL ?? '',
      );

      try {
        await _sessionManager.startSession(user.uid);
      } catch (e) {
        await logout();
        return 'Device verification failed: ${e.toString()}';
      }

      await _premiumService?.reloadStatus();
      if (_premiumService?.isPremium == true) {
        final String uid = _auth.currentUser!.uid;
        await _firestore.collection('users').doc(uid).update({'is_premium': true});
      }

      return null;
    } catch (e) {
      return 'Google Sign-in error: ${e.toString()}';
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
    await GoogleSignIn().signOut();
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    final int? themeMode = prefs.getInt('theme_mode');
    final double? readerLineHeight = prefs.getDouble('reader_line_height');
    final double? readerContrast = prefs.getDouble('reader_contrast');
    final bool? dataSaver = prefs.getBool('data_saver_mode');
    final String? language = prefs.getString('language_code');


    await prefs.clear();


    if (themeMode != null) await prefs.setInt('theme_mode', themeMode);
    if (readerLineHeight != null) {
      await prefs.setDouble('reader_line_height', readerLineHeight);
    }
    if (readerContrast != null) {
      await prefs.setDouble('reader_contrast', readerContrast);
    }
    if (dataSaver != null) await prefs.setBool('data_saver_mode', dataSaver);
    if (language != null) await prefs.setString('language_code', language);

    await _premiumService?.reloadStatus();
    notifyListeners();
  }

  Future<Map<String, String>> getProfile() async {
    final secure = sl<SecurePrefs>();
    return <String, String>{
      'name': await secure.getString(_prefsKeys['name']!) ?? '',
      'email': await secure.getString(_prefsKeys['email']!) ?? '',
      'phone': await secure.getString(_prefsKeys['phone']!) ?? '',
      'role': await secure.getString(_prefsKeys['role']!) ?? '',
      'department': await secure.getString(_prefsKeys['department']!) ?? '',
      'image': await secure.getString(_prefsKeys['image']!) ?? '',
    };
  }

  Future<void> updateProfile({
    required String name,
    required String email,
    String phone = '',
    String role = '',
    String department = '',
    String imagePath = '',
  }) async {
    final String? uid = _auth.currentUser?.uid;
    if (uid != null) {
      await _firestore.collection('users').doc(uid).update(<Object, Object?>{
        'name': name,
        'email': email,
        'phone': phone,
        'role': role,
        'department': department,
        'image': imagePath,
      });
    }

    await _cacheProfile(
      name: name,
      email: email,
      phone: phone,
      role: role,
      department: department,
      imagePath: imagePath,
    );
  }

  Future<void> _cacheProfile({
    required String name,
    required String email,
    String phone = '',
    String role = '',
    String department = '',
    String imagePath = '',
  }) async {
    final secure = sl<SecurePrefs>();
    await secure.setString(_prefsKeys['name']!, name);
    await secure.setString(_prefsKeys['email']!, email);
    await secure.setString(_prefsKeys['phone']!, phone);
    await secure.setString(_prefsKeys['role']!, role);
    await secure.setString(_prefsKeys['department']!, department);
    await secure.setString(_prefsKeys['image']!, imagePath);
    await secure.setString('isLoggedIn', 'true');
  }

  Future<void> _cacheProfileMap(Map<String, dynamic> data) async {
    final secure = sl<SecurePrefs>();
    await secure.setString(_prefsKeys['name']!, data['name'] ?? '');
    await secure.setString(_prefsKeys['email']!, data['email'] ?? '');
    await secure.setString(_prefsKeys['phone']!, data['phone'] ?? '');
    await secure.setString(_prefsKeys['role']!, data['role'] ?? '');
    await secure.setString(_prefsKeys['department']!, data['department'] ?? '');
    await secure.setString(_prefsKeys['image']!, data['image'] ?? '');
    await secure.setString('isLoggedIn', 'true');
  }

  /// Check if the user has already used their one-time trial (Strict Check)
  Future<bool> hasUsedTrial() async {
    final String? uid = _auth.currentUser?.uid;
    if (uid == null) return false;

    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return false;
      
      return doc.data()?['trial_used'] == true;
    } catch (e) {
      return false;
    }
  }

  /// Mark the one-time trial as used in Firestore (Irreversible)
  Future<void> markTrialUsed() async {
    final String? uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      await _firestore.collection('users').doc(uid).set(
        {'trial_used': true},
        SetOptions(merge: true),
      );
    } catch (e) {
    }
  }
}
