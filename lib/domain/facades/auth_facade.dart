import 'package:firebase_auth/firebase_auth.dart';

/// Authentication facade interface
/// Decouples authentication logic from presentation layer
abstract class AuthFacade {
  /// Current authenticated user
  User? get currentUser;
  
  /// Whether a user is currently logged in
  bool get isLoggedIn;

  /// Initialize the auth service
  Future<void> init();

  /// Sign up a new user
  /// Returns error message on failure, null on success
  Future<String?> signUp(String name, String email, String password);

  /// Login with email and password
  /// Returns error message on failure, null on success
  Future<String?> login(String email, String password);

  /// Sign in with Google
  /// Returns error message on failure, null on success
  Future<String?> signInWithGoogle();

  /// Sign out the current user
  Future<void> logout();

  /// Reset password for the given email
  Future<String?> resetPassword(String email);

  /// Check if user has used trial
  Future<bool> hasUsedTrial();

  /// Mark trial as used
  Future<void> markTrialUsed();

  /// Get user profile
  Future<Map<String, String>> getProfile();

  /// Update user profile
  Future<void> updateProfile({
    required String name,
    required String email,
    String phone = '',
    String role = '',
    String department = '',
    String imagePath = '',
  });
}
