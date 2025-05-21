import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  bool get isLoggedIn => _auth.currentUser != null;

  static const _prefsKeys = {
    'name': 'user_name',
    'email': 'user_email',
    'phone': 'user_phone',
    'role': 'user_role',
    'department': 'user_department',
    'image': 'user_image',
    'isLoggedIn': 'isLoggedIn',
  };

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final logged = prefs.getBool(_prefsKeys['isLoggedIn']!) ?? false;
    if (!logged || _auth.currentUser == null) {
      await logout(); // ensure clean state
    }
  }

  Future<String?> signUp(String name, String email, String password) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final uid = userCredential.user!.uid;

      await _firestore.collection('users').doc(uid).set({
        'name': name,
        'email': email,
        'phone': '',
        'role': '',
        'department': '',
        'image': '',
      });

      await _cacheProfile(name: name, email: email);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  Future<String?> login(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final uid = userCredential.user!.uid;
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        await _cacheProfileMap(doc.data() ?? {});
      }
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  Future<String?> signInWithGoogle() async {
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return 'Google sign-in cancelled.';

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user!;

      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) {
        await _firestore.collection('users').doc(user.uid).set({
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

      return null;
    } catch (e) {
      return 'Google Sign-in error: ${e.toString()}';
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
    await GoogleSignIn().signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  Future<Map<String, String>> getProfile() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'name': prefs.getString(_prefsKeys['name']!) ?? '',
      'email': prefs.getString(_prefsKeys['email']!) ?? '',
      'phone': prefs.getString(_prefsKeys['phone']!) ?? '',
      'role': prefs.getString(_prefsKeys['role']!) ?? '',
      'department': prefs.getString(_prefsKeys['department']!) ?? '',
      'image': prefs.getString(_prefsKeys['image']!) ?? '',
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
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      await _firestore.collection('users').doc(uid).update({
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKeys['name']!, name);
    await prefs.setString(_prefsKeys['email']!, email);
    await prefs.setString(_prefsKeys['phone']!, phone);
    await prefs.setString(_prefsKeys['role']!, role);
    await prefs.setString(_prefsKeys['department']!, department);
    await prefs.setString(_prefsKeys['image']!, imagePath);
    await prefs.setBool(_prefsKeys['isLoggedIn']!, true);
  }

  Future<void> _cacheProfileMap(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKeys['name']!, data['name'] ?? '');
    await prefs.setString(_prefsKeys['email']!, data['email'] ?? '');
    await prefs.setString(_prefsKeys['phone']!, data['phone'] ?? '');
    await prefs.setString(_prefsKeys['role']!, data['role'] ?? '');
    await prefs.setString(_prefsKeys['department']!, data['department'] ?? '');
    await prefs.setString(_prefsKeys['image']!, data['image'] ?? '');
    await prefs.setBool(_prefsKeys['isLoggedIn']!, true);
  }
}
