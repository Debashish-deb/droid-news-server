import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../infrastructure/persistence/services/offline_service.dart';
import '../../infrastructure/persistence/vault/vault_database.dart';
import '../../presentation/features/tts/services/tts_database.dart';

/// Clears locally persisted user data while shutting down open stores first.
class LocalStorageWiper {
  const LocalStorageWiper._();

  static Future<void> wipeLocalAppData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    await _wipeHive();
    await OfflineService.deleteStorage();
    await VaultDatabase.deleteStorage();
    await TtsDatabase.deleteStorage();
  }

  static Future<void> _wipeHive() async {
    try {
      await Hive.close();
    } catch (e) {
      debugPrint('⚠️ Hive close during local wipe failed: $e');
    }

    try {
      await Hive.deleteFromDisk();
    } catch (e) {
      debugPrint('⚠️ Hive delete during local wipe failed: $e');
    }
  }
}
