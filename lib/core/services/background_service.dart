import 'package:workmanager/workmanager.dart';
import 'package:flutter/foundation.dart';

/// Background service using WorkManager
class BackgroundService {
  static const String simpleTaskKey = 'simpleTask';
  static const String syncTaskKey = 'syncTask';

  /// Initialize WorkManager
  static Future<void> initialize() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: kDebugMode,
    );
  }

  /// Register a periodic sync task
  static Future<void> registerPeriodicSync() async {
    await Workmanager().registerPeriodicTask(
      syncTaskKey,
      simpleTaskKey,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true,
      ),
    );
  }

  /// Cancel all tasks
  static Future<void> cancelAll() async {
    await Workmanager().cancelAll();
  }
}

/// Top-level function for background execution
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) {
    switch (task) {
      case BackgroundService.simpleTaskKey:
        if (kDebugMode) {
          print("Background Task Executed: $task");
        }
        // TODO: Implement actual sync logic here
        // We'll leave this empty for now as the goal is infrastructure
        break;
    }
    return Future.value(true);
  });
}
