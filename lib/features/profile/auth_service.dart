import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/premium_service.dart';
import '../../data/services/device_session_service.dart';
import '../../core/security/secure_prefs.dart'; // BUILD_FIXES: Secure storage

class AuthService {
  factory AuthService() => _instance;
  AuthService._internal();
  static final AuthService _instance = AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DeviceSessionService _deviceSession = DeviceSessionService();

  // Reference to PremiumService for reloading premium status
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
    // Use SecurePrefs for login status (more secure)
    final String? loggedStatus = await SecurePrefs.instance.getString('isLoggedIn');
    final bool logged = loggedStatus == 'true';
    if (!logged || _auth.currentUser == null) {
      await logout(); // ensure clean state
    }
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

      // Register device session
      final deviceResult = await _deviceSession.registerDevice();
      if (!deviceResult.success) {
        // Device limit exceeded, logout
        await logout();
        return 'Device limit exceeded: ${deviceResult.errorMessage}';
      }

      // Reload premium status after signup (check whitelist)
      await _premiumService?.reloadStatus();

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

      // Register/validate device session
      final deviceResult = await _deviceSession.registerDevice();
      if (!deviceResult.success) {
        // Device limit exceeded, logout
        await logout();
        if (deviceResult.maxDevices != null) {
          // More specific error message
          return 'Device limit reached (${deviceResult.currentCount}/${deviceResult.maxDevices}). '
              'Free: 1 Android + 1 iOS. Premium: 2 Android + 1 iOS. '
              'Please logout from another device or upgrade to Premium.';
        }
        return 'Device registration failed: ${deviceResult.errorMessage}';
      }

      // Reload premium status after login (check whitelist)
      await _premiumService?.reloadStatus();

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

      // Reload premium status after Google sign-in (check whitelist)
      await _premiumService?.reloadStatus();

      return null;
    } catch (e) {
      return 'Google Sign-in error: ${e.toString()}';
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
    await GoogleSignIn().signOut();
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    // Preserve theme and app settings - only clear user data
    final int? themeMode = prefs.getInt('theme_mode');
    final double? readerLineHeight = prefs.getDouble('reader_line_height');
    final double? readerContrast = prefs.getDouble('reader_contrast');
    final bool? dataSaver = prefs.getBool('data_saver_mode');
    final String? language = prefs.getString('language_code');

    // Clear all preferences
    await prefs.clear();

    // Restore preserved settings
    if (themeMode != null) await prefs.setInt('theme_mode', themeMode);
    if (readerLineHeight != null) {
      await prefs.setDouble('reader_line_height', readerLineHeight);
    }
    if (readerContrast != null) {
      await prefs.setDouble('reader_contrast', readerContrast);
    }
    if (dataSaver != null) await prefs.setBool('data_saver_mode', dataSaver);
    if (language != null) await prefs.setString('language_code', language);

    // Reload premium status after logout (should clear premium state)
    await _premiumService?.reloadStatus();
  }

  Future<Map<String, String>> getProfile() async {
    final secure = SecurePrefs.instance;
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
    final secure = SecurePrefs.instance;
    await secure.setString(_prefsKeys['name']!, name);
    await secure.setString(_prefsKeys['email']!, email);
    await secure.setString(_prefsKeys['phone']!, phone);
    await secure.setString(_prefsKeys['role']!, role);
    await secure.setString(_prefsKeys['department']!, department);
    await secure.setString(_prefsKeys['image']!, imagePath);
    // Store login status in SecurePrefs for better security
    await secure.setString('isLoggedIn', 'true');
  }

  Future<void> _cacheProfileMap(Map<String, dynamic> data) async {
    final secure = SecurePrefs.instance;
    await secure.setString(_prefsKeys['name']!, data['name'] ?? '');
    await secure.setString(_prefsKeys['email']!, data['email'] ?? '');
    await secure.setString(_prefsKeys['phone']!, data['phone'] ?? '');
    await secure.setString(_prefsKeys['role']!, data['role'] ?? '');
    await secure.setString(_prefsKeys['department']!, data['department'] ?? '');
    await secure.setString(_prefsKeys['image']!, data['image'] ?? '');
    // Store login status in SecurePrefs for better security
    await secure.setString('isLoggedIn', 'true');
  }
}
