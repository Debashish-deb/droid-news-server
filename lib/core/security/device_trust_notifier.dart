import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../enums/device_trust_state.dart';
import '../../application/identity/device_trust_service.dart';

class DeviceTrustNotifier extends StateNotifier<DeviceTrustState> {
  DeviceTrustNotifier(this._trustService) : super(DeviceTrustState.unknown);

  final DeviceTrustService _trustService;

  Future<void> initialize() async {
    state = DeviceTrustState.verifying;
    try {
      final score = await _trustService.calculateTrustScore();
      
      // In debug mode, be more lenient for development
      if (kDebugMode) {
        if (score >= 0.6) {
          state = DeviceTrustState.trusted;
        } else if (score >= 0.3) {
          state = DeviceTrustState.restricted;
        } else {
          state = DeviceTrustState.blocked;
        }
      } else {
        // Production: strict requirements
        if (score >= 0.9) {
          state = DeviceTrustState.trusted;
        } else if (score >= 0.5) {
          state = DeviceTrustState.restricted;
        } else {
          state = DeviceTrustState.blocked;
        }
      }
    } catch (e) {
      // Debug mode: allow restricted access on errors
      state = kDebugMode ? DeviceTrustState.restricted : DeviceTrustState.blocked;
    }
  }
}
