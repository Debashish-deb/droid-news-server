import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/interfaces/subscription_repository.dart';
import '../../core/di/providers.dart' as di;

// ============================================================================
// Premium/Subscription State Management (REFAC)
// ============================================================================

// Providers here are mostly legacy wrappers or convenience re-exports.
// Real logic is now in core/di/providers.dart and premium_providers.dart.

// NOTE: This is a transitional provider setup.

// ============================================================================
// NEW: Subscription Repository Provider
// ============================================================================

/// Provider for SubscriptionRepository
final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  return ref.watch(di.subscriptionRepositoryProvider);
});
