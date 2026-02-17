
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import '../../bootstrap/di/injection_container.dart'; // Deleted during Riverpod migration
import '../persistence/app_database.dart';

enum DataClassification {
  public,     
  internal,  
  confidential, 
  restricted 
}

enum ConsentStatus {
  granted,
  denied,
  partial,
  unknown
}

class GovernanceEngine {

  GovernanceEngine({
    required FlutterSecureStorage secureStorage,
    required SharedPreferences prefs,
    required AppDatabase db,
  })  : _secureStorage = secureStorage,
        _prefs = prefs,
        _db = db;
  final FlutterSecureStorage _secureStorage;
  final SharedPreferences _prefs;
  final AppDatabase _db;

  // Enforce Data Policies before logging/syncing
  bool isActionPermitted(String action, DataClassification classification, ConsentStatus userConsent) {
    if (classification == DataClassification.public) return true;
    
    if (userConsent == ConsentStatus.denied || userConsent == ConsentStatus.unknown) {
      // Strict privacy mode
      return false;
    }
    
    if (classification == DataClassification.restricted) {
      // Restricted data needs specific explicit consent check, not just general opt-in
      // For now, blocking by default unless specifically handled
      return false;
    }

    return true;
  }
  
  /// Execute Right-to-Forget: Completely wipe user data from device.
  Future<void> requestRightToForget(String userId) async {
    debugPrint('⚖️ GOVERNANCE: Initiating Right-to-Forget for $userId');
    
    try {
      // 1. Wipe Indentity & Secure Storage
      await _secureStorage.deleteAll();
      debugPrint('   ✅ Secure Storage wiped.');

      // 2. Wipe App Settings
      await _prefs.clear();
      debugPrint('   ✅ SharedPreferences wiped.');

      // 3. Wipe User Database (Drift)
      // We delete all records. In a multi-user db we'd filter by userId, 
      // but this is a local-first app, usually single user active.
      // For strictness, we wipe the known tables.
      await _db.delete(_db.articles).go();
      await _db.delete(_db.bookmarks).go();
      await _db.delete(_db.readingHistory).go();
      await _db.delete(_db.syncJournal).go();
      debugPrint('   ✅ Database tables truncated.');
      
    
      debugPrint('🏁 Right-to-Forget COMPLETED. App is clean.');
    } catch (e) {
      debugPrint('⚠️ GOVERNANCE FAILURE: Failed to wipe data: $e');
      throw Exception('Right-to-Forget failed: $e'); // Escalation
    }
  }
}
