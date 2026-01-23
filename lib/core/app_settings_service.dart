import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'sync_service.dart';
import 'unified_sync_manager.dart';

class AppSettingsService extends ChangeNotifier {
  AppSettingsService(this.syncService);

  final SyncService syncService;
  late final SharedPreferences _prefs;

  bool dataSaver = false;
  bool pushNotif = true;

  Future<void> loadFromPrefs(SharedPreferences prefs) async {
    _prefs = prefs;
    dataSaver = prefs.getBool('data_saver') ?? false;
    pushNotif = prefs.getBool('push_notif') ?? true;
    notifyListeners();

    // Initial sync from cloud handled by UnifiedSyncManager.pullAll()
  }

  Future<void> syncFromCloud() async {
    final Map<String, dynamic>? cloudData = await syncService.pullSettings();
    if (cloudData == null) return;

    bool changed = false;
    if (cloudData.containsKey('dataSaver') &&
        cloudData['dataSaver'] != dataSaver) {
      dataSaver = cloudData['dataSaver'] as bool;
      await _prefs.setBool('data_saver', dataSaver);
      changed = true;
    }

    if (cloudData.containsKey('pushNotif') &&
        cloudData['pushNotif'] != pushNotif) {
      pushNotif = cloudData['pushNotif'] as bool;
      await _prefs.setBool('push_notif', pushNotif);
      changed = true;
    }

    if (changed) notifyListeners();
  }

  void setDataSaver(bool value) {
    dataSaver = value;
    _prefs.setBool('data_saver', value);
    notifyListeners();
    // Sync to cloud via UnifiedSyncManager
    UnifiedSyncManager().pushSettings();
  }

  void setPushNotif(bool value) {
    pushNotif = value;
    _prefs.setBool('push_notif', value);
    notifyListeners();
    // Sync to cloud via UnifiedSyncManager
    UnifiedSyncManager().pushSettings();
  }
}
