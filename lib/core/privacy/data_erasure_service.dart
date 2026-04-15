import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'consent_manager.dart';
import 'local_storage_wiper.dart';
import '../security/secure_prefs.dart';

// Handles "Right to be Forgotten" requests
class DataErasureService {
  Future<void> wipeUserData() async {
    debugPrint('⚠️ STARTING DATA WIPE: Right to be forgotten');

    try {
      // 1. Clear local persisted app state and caches safely.
      await LocalStorageWiper.wipeLocalAppData();

      // 2. Clear Secure Storage (Tokens, Keys)
      await SecurePrefs.sharedStorage.deleteAll(
        aOptions: SecurePrefs.androidOptions,
        iOptions: SecurePrefs.iosOptions,
      );

      // 3. Reset Privacy Consents
      await ConsentManager().resetAllConsents();

      // 4. Firebase Auth - Sign out and try to delete account
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          // Note: delete() may fail if re-authentication is required
          await user.delete();
        } catch (authError) {
          debugPrint(
            '⚠️ Could not delete auth account (re-auth required), signing out instead',
          );
          await FirebaseAuth.instance.signOut();
        }
      }

      debugPrint('✅ DATA WIPE COMPLETE');
    } catch (e) {
      debugPrint('❌ DATA WIPE FAILED: $e');
      throw Exception('Failed to wipe data: $e');
    }
  }
}
