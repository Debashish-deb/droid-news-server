import 'package:bdnewsreader/infrastructure/persistence/auth/device_session.dart';
import 'package:flutter_test/flutter_test.dart';

DeviceSession _session({
  required String deviceId,
  required String platform,
  DeviceStatus status = DeviceStatus.active,
  DateTime? lastActive,
}) {
  return DeviceSession(
    deviceId: deviceId,
    deviceName: 'Device $deviceId',
    platform: platform,
    appVersion: '1.0.0',
    firstSeen: DateTime(2026),
    lastActive: lastActive ?? DateTime.now(),
    loginCount: 1,
    status: status,
  );
}

void main() {
  test('existing registered device stays allowed at the device limit', () {
    final result = DeviceSessionPolicy.evaluateDeviceLimit(
      isPremium: false,
      currentPlatform: 'android',
      currentDeviceId: 'device-a',
      activeDevices: [_session(deviceId: 'device-a', platform: 'android')],
      freeAndroidLimit: 1,
      freeIosLimit: 1,
      premiumAndroidLimit: 2,
      premiumIosLimit: 1,
    );

    expect(result.allowed, isTrue);
    expect(result.currentCount, 1);
  });

  test('new device is denied when the per-platform limit is reached', () {
    final result = DeviceSessionPolicy.evaluateDeviceLimit(
      isPremium: false,
      currentPlatform: 'android',
      currentDeviceId: 'device-b',
      activeDevices: [_session(deviceId: 'device-a', platform: 'android')],
      freeAndroidLimit: 1,
      freeIosLimit: 1,
      premiumAndroidLimit: 2,
      premiumIosLimit: 1,
    );

    expect(result.allowed, isFalse);
    expect(result.currentCount, 1);
  });

  test('missing, revoked, and expired sessions are invalid', () {
    expect(DeviceSessionPolicy.validateStoredSession(null).isValid, isFalse);
    expect(
      DeviceSessionPolicy.validateStoredSession(
        _session(
          deviceId: 'device-a',
          platform: 'android',
          status: DeviceStatus.revoked,
        ),
      ).isValid,
      isFalse,
    );
    expect(
      DeviceSessionPolicy.validateStoredSession(
        _session(
          deviceId: 'device-a',
          platform: 'android',
          lastActive: DateTime.now().subtract(const Duration(days: 31)),
        ),
      ).isValid,
      isFalse,
    );
  });

  test('session-store grace window is enforced at 24 hours', () {
    final withinGrace = DeviceSessionPolicy.canUseValidationGraceWindow(
      DateTime.now().subtract(const Duration(hours: 23)),
    );
    final outsideGrace = DeviceSessionPolicy.canUseValidationGraceWindow(
      DateTime.now().subtract(const Duration(hours: 25)),
    );

    expect(withinGrace, isTrue);
    expect(outsideGrace, isFalse);
  });
}
