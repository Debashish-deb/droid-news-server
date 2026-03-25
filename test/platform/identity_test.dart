
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:bdnewsreader/platform/identity/device_registry.dart';
import 'package:bdnewsreader/platform/identity/trust_engine.dart';
import 'package:bdnewsreader/platform/identity/session_manager.dart';

// Manual Mocks
class MockDeviceRegistry extends Mock implements DeviceRegistry {
  @override
  Future<String> getDeviceId() => super.noSuchMethod(Invocation.method(#getDeviceId, []), returnValue: Future.value('mock-id'));

  @override
  Future<DeviceIntegrity> bindDevice(String? userId) => super.noSuchMethod(
        Invocation.method(#bindDevice, [userId]),
        returnValue: Future.value(DeviceIntegrity.unknown('mock-id')),
      );

  @override
  Future<bool> verifyDevice(String? deviceId) => super.noSuchMethod(Invocation.method(#verifyDevice, [deviceId]), returnValue: Future.value(true));
}

class MockTrustEngine extends Mock implements TrustEngine {
  @override
  Future<double> calculateTrustScore(String? deviceId) => 
      super.noSuchMethod(Invocation.method(#calculateTrustScore, [deviceId]), returnValue: Future.value(1.0));

  @override
  Future<TrustLevel> evaluateTrust(String? deviceId) => 
      super.noSuchMethod(Invocation.method(#evaluateTrust, [deviceId]), returnValue: Future.value(TrustLevel.high));
}

void main() {
  group('Identity Platform Tests', () {
    late MockDeviceRegistry mockRegistry;
    late MockTrustEngine mockTrustEngine;
    late IdentitySessionManagerImpl sessionManager;

    setUp(() {
      mockRegistry = MockDeviceRegistry();
      mockTrustEngine = MockTrustEngine();
      sessionManager = IdentitySessionManagerImpl(mockRegistry, mockTrustEngine);
    });

    test('startSession should create a valid session when device is trusted', () async {
      // Arrange
      when(mockRegistry.getDeviceId()).thenAnswer((_) async => 'device-123');
      when(mockRegistry.bindDevice(any)).thenAnswer((_) async => DeviceIntegrity.unknown('device-123'));
      when(mockTrustEngine.evaluateTrust(any)).thenAnswer((_) async => TrustLevel.high);

      // Act
      final session = await sessionManager.startSession('user-abc');

      // Assert
      expect(session.userId, equals('user-abc'));
      expect(session.deviceId, equals('device-123'));
      expect(session.initialTrustLevel, equals(TrustLevel.high));
      expect(session.isValid, isTrue);
      
      verify(mockRegistry.bindDevice('user-abc')).called(1);
    });

    test('startSession should throw if device is blocked', () async {
      // Arrange
      when(mockRegistry.getDeviceId()).thenAnswer((_) async => 'bad-device');
      when(mockRegistry.bindDevice(any)).thenAnswer((_) async => DeviceIntegrity.unknown('bad-device'));
      when(mockTrustEngine.evaluateTrust(any)).thenAnswer((_) async => TrustLevel.blocked);

      // Act & Assert
      expect(() => sessionManager.startSession('user-abc'), throwsException);
    });
  });
}
