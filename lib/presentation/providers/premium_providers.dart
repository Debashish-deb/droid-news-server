import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/providers.dart';
import '../../domain/entities/subscription.dart' show SubscriptionTier;
import '../../domain/repositories/premium_repository.dart'
    show EntitlementSnapshot;

/// Reactive stream of full entitlement state.
///
/// This is the single source of truth for ad gating and premium UI, and it
/// must remain stream-driven so runtime entitlement refreshes propagate
/// immediately (without requiring app restart/provider recreation).
final entitlementSnapshotStreamProvider = StreamProvider<EntitlementSnapshot>((
  ref,
) async* {
  final repo = ref.watch(premiumRepositoryProvider);
  yield repo.entitlementSnapshot;
  yield* repo.entitlementSnapshotStream;
});

/// Reactive stream of premium status. Use this in Widgets via ref.watch()
final isPremiumProvider = StreamProvider<bool>((ref) async* {
  yield* ref
      .watch(entitlementSnapshotStreamProvider.stream)
      .map((snapshot) => snapshot.isPremium);
});

/// Reactive snapshot with synchronous fallback.
///
/// Why fallback:
/// During first frame / async handoff, some surfaces need an immediate value.
/// We use the repository's current snapshot, then seamlessly update from stream.
final entitlementSnapshotProvider = Provider<EntitlementSnapshot>((ref) {
  final streamed = ref.watch(entitlementSnapshotStreamProvider).asData?.value;
  if (streamed != null) return streamed;
  final repo = ref.watch(premiumRepositoryProvider);
  return repo.entitlementSnapshot;
});

/// Convenience provider for standard logic checks (uses last known state)
final isPremiumStateProvider = Provider<bool>((ref) {
  return ref.watch(entitlementSnapshotProvider).isPremium;
});

/// Whether ad surfaces are allowed to render.
/// Fail-safe: while premium status is unresolved/loading, ads stay hidden.
final shouldShowAdsProvider = Provider<bool>((ref) {
  final snapshot = ref.watch(entitlementSnapshotProvider);
  return snapshot.resolved && !snapshot.isPremium;
});

/// Shared counter for free article views, persisted to SharedPreferences
final freeViewsProvider = StateProvider<int>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs?.getInt('free_views_used') ?? 0;
});

/// Provides the current premium tier enum
final currentTierProvider = Provider<SubscriptionTier>((ref) {
  return ref.watch(entitlementSnapshotProvider).tier;
});

/// Provider family to check if a specific feature is available.
/// This prevents "tier leak" where a lower tier user gets higher tier features.
final hasFeatureProvider = Provider.family<bool, String>((ref, featureId) {
  final tier = ref.watch(currentTierProvider);

  if (tier == SubscriptionTier.free) return false;

  // Basic premium features available to all paid tiers
  const basicPremium = {'ad_free', 'offline_reading', 'unlimited_articles'};

  if (basicPremium.contains(featureId)) return true;

  // Advanced features (Pro and ProPlus)
  if (tier == SubscriptionTier.pro || tier == SubscriptionTier.proPlus) {
    const advancedFeatures = {'unlimited_tts', 'premium_sources'};
    if (advancedFeatures.contains(featureId)) return true;
  }

  // Exclusive "Second Tier" (ProPlus) features
  if (tier == SubscriptionTier.proPlus) {
    const enterpriseFeatures = {'ai_summaries', 'bulk_export'};
    if (enterpriseFeatures.contains(featureId)) return true;
  }

  return false;
});

/// Extension to conveniently increment and persist free views
extension FreeViewsController on WidgetRef {
  void incrementFreeViews() {
    final prefs = read(sharedPreferencesProvider);
    final current = read(freeViewsProvider);
    final newValue = current + 1;
    read(freeViewsProvider.notifier).state = newValue;
    prefs?.setInt('free_views_used', newValue);
  }
}
