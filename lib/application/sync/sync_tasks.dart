import '../background/background_task_scheduler.dart';
import '../../infrastructure/sync/sync_service.dart';
import 'package:flutter/foundation.dart';

/// Background task to push settings to the cloud
class SyncSettingsTask extends BackgroundTask {

  SyncSettingsTask({
    required this.syncService,
    required this.settingsData,
  });
  final SyncService syncService;
  final Map<String, dynamic> settingsData;

  @override
  String get id => 'sync_settings_${DateTime.now().millisecondsSinceEpoch}';

  @override
  TaskPriority get priority => TaskPriority.medium;

  @override
  NetworkType get networkRequirements => NetworkType.connected;

  @override
  Future<bool> execute() async {
    try {
      await syncService.pushSettings(
        dataSaver: settingsData['dataSaver'],
        pushNotif: settingsData['pushNotif'],
        themeMode: settingsData['themeMode'],
        languageCode: settingsData['languageCode'],
        readerLineHeight: settingsData['readerLineHeight'],
        readerContrast: settingsData['readerContrast'],
      );
      debugPrint('✅ [BackgroundTask] Settings synced successfully');
      return true;
    } catch (e) {
      debugPrint('❌ [BackgroundTask] Settings sync failed: $e');
      return false;
    }
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'type': 'SyncSettingsTask',
      'settingsData': settingsData,
    };
  }
}
