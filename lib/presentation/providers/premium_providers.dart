import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/providers.dart';

/// Reactive stream of premium status. Use this in Widgets via ref.watch()
final isPremiumProvider = StreamProvider<bool>((ref) {
  return ref.watch(premiumRepositoryProvider).premiumStatusStream;
});

/// Convenience provider for standard logic checks (uses last known state)
final isPremiumStateProvider = Provider<bool>((ref) {
  return ref.watch(premiumRepositoryProvider).isPremium;
});

/// Provides the current premium tier name
final tierNameProvider = Provider<String>((ref) {
  final isPremium = ref.watch(isPremiumStateProvider);
  return isPremium ? 'pro' : 'free';
});

/// Provider family to check if a specific feature is available
final hasFeatureProvider = Provider.family<bool, String>((ref, featureId) {
  final isPremium = ref.watch(isPremiumStateProvider);
  return isPremium;
});