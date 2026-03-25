import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'consent_manager.dart';

// Handles "Right to be Forgotten" requests
class DataErasureService {
  
  Future<void> wipeUserData() async {
    debugPrint('⚠️ STARTING DATA WIPE: Right to be forgotten');
    
    try {
      // 1. Clear SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      
      // 2. Clear Hive (Offline Cache)
      await Hive.deleteFromDisk();
      
      // 3. Clear Secure Storage (Tokens, Keys)
      const secureStorage = FlutterSecureStorage();
      await secureStorage.deleteAll();
      
      // 4. Reset Privacy Consents
      await ConsentManager().resetAllConsents();
      
      // 5. Firebase Auth - Sign out and try to delete account
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          // Note: delete() may fail if re-authentication is required
          await user.delete();
        } catch (authError) {
          debugPrint('⚠️ Could not delete auth account (re-auth required), signing out instead');
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

