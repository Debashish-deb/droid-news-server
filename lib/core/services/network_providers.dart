// lib/core/services/network_providers.dart
// ========================================
// RIVERPOD PROVIDERS FOR NETWORK SERVICE
// ========================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_network_service.dart';

/// Singleton instance of AppNetworkService
final appNetworkServiceProvider = Provider<AppNetworkService>((ref) {
  final service = AppNetworkService();
  // Dispose when provider is disposed
  ref.onDispose(() => service.dispose());
  return service;
});

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
