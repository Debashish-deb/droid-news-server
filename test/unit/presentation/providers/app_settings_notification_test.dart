import 'package:bdnewsreader/application/sync/sync_orchestrator.dart';
import 'package:bdnewsreader/core/telemetry/observability_service.dart';
import 'package:bdnewsreader/core/telemetry/structured_logger.dart';
import 'package:bdnewsreader/infrastructure/services/notifications/push_notification_service.dart';
import 'package:bdnewsreader/infrastructure/sync/services/sync_service.dart';
import 'package:bdnewsreader/presentation/providers/app_settings_providers.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:workmanager_platform_interface/workmanager_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _MockWorkmanagerPlatform extends WorkmanagerPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<void> initialize(
    Function callbackDispatcher, {
    bool isInDebugMode = false,
  }) async {}

  @override
  Future<void> cancelByTag(String tag) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeNotificationPreferenceSync implements NotificationPreferenceSync {
  final List<bool> calls = <bool>[];

  @override
  Future<void> setNotificationsEnabled(bool enabled) async {
    calls.add(enabled);
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    WorkmanagerPlatform.instance = _MockWorkmanagerPlatform();
  });

  test(
    'push notification toggle syncs prefs and notification service',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final fakeNotifications = _FakeNotificationPreferenceSync();
      final syncService = SyncService.disabled(
        ObservabilityService(),
        StructuredLogger(),
        prefs,
      );
      final orchestrator = SyncOrchestrator.disabled(prefs);
      final notifier = AppSettingsNotifier(
        prefs,
        syncService,
        orchestrator,
        fakeNotifications,
      );

      notifier.setPushNotif(false);
      await Future<void>.delayed(Duration.zero);

      expect(notifier.current.pushNotif, isFalse);
      expect(prefs.getBool('push_notif'), isFalse);
      expect(fakeNotifications.calls, <bool>[false]);
    },
  );
}
