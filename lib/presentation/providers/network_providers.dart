// lib/presentation/providers/network_providers.dart
// ========================================
// RIVERPOD PROVIDERS FOR NETWORK SERVICE
// ========================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../infrastructure/network/app_network_service.dart';
import '../../core/di/providers.dart';

/// Current connection status
final isConnectedProvider = Provider<bool>((ref) {
  return ref.watch(appNetworkServiceProvider).isConnected;
});

/// Current network quality
final networkQualityProvider = Provider<NetworkQuality>((ref) {
  return ref.watch(appNetworkServiceProvider).currentQuality;
});

/// Human-readable quality description
final networkQualityDescriptionProvider = Provider<String>((ref) {
  return ref.watch(appNetworkServiceProvider).qualityDescription;
});
