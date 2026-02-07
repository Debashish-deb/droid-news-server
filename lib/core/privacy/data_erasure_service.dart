import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';


// Handles "Right to be Forgotten" requests
class DataErasureService {
  
  Future<void> wipeUserData() async {
    debugPrint('⚠️ STARTING DATA WIPE: Right to be forgotten');
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      
      await Hive.deleteFromDisk();
      
      
      debugPrint('✅ DATA WIPE COMPLETE');
    } catch (e) {
      debugPrint('❌ DATA WIPE FAILED: $e');
      throw Exception('Failed to wipe data: $e');
    }
  }
}
