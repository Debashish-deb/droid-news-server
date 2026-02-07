import 'package:injectable/injectable.dart';
import 'dart:async';
import 'package:uuid/uuid.dart';
import '../../bootstrap/di/injection_container.dart' show sl;
import 'device_registry.dart';
import 'trust_engine.dart';

class Session {

  Session({
    required this.sessionId,
    required this.userId,
    required this.deviceId,
    required this.createdAt,
    required this.expiresAt,
    required this.initialTrustLevel,
  });
  final String sessionId;
  final String userId;
  final String deviceId;
  final DateTime createdAt;
  final DateTime expiresAt;
  final TrustLevel initialTrustLevel;
  
  bool get isValid => DateTime.now().isBefore(expiresAt);
}

abstract class IdentitySessionManager {
  Future<Session> startSession(String userId);
  Future<void> endSession();
  Future<Session?> getCurrentSession();
  Stream<Session?> get sessionStream;
}

@LazySingleton(as: IdentitySessionManager)
class IdentitySessionManagerImpl implements IdentitySessionManager {

  IdentitySessionManagerImpl(this._deviceRegistry, this._trustEngine);
  final DeviceRegistry _deviceRegistry;
  final TrustEngine _trustEngine;
  
  Session? _currentSession;
  final _sessionController = StreamController<Session?>.broadcast();

  @override
  Future<Session> startSession(String userId) async {
    final deviceId = await _deviceRegistry.getDeviceId();
    final integrity = await _deviceRegistry.bindDevice(userId);
    final trustLevel = await _trustEngine.evaluateTrust(deviceId);
    
    
    if (trustLevel == TrustLevel.blocked) {
      throw Exception('Device is blocked due to low trust score.');
    }

    final session = Session(
      sessionId: const Uuid().v4(),
      userId: userId,
      deviceId: deviceId,
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(days: 7)), // 7 day session
      initialTrustLevel: trustLevel,
    );

    _currentSession = session;
    _sessionController.add(session);
    return session;
  }

  @override
  Future<void> endSession() async {
    _currentSession = null;
    _sessionController.add(null);
  }

  @override
  Future<Session?> getCurrentSession() async {
    return _currentSession;
  }

  @override
  Stream<Session?> get sessionStream => _sessionController.stream;
  
  void dispose() {
    _sessionController.close();
  }
}
