// lib/domain/repositories/premium_repository.dart
import 'dart:async';
import '../entities/subscription.dart' show SubscriptionTier;

class EntitlementSnapshot {
  const EntitlementSnapshot({
    required this.isPremium,
    required this.tier,
    required this.resolved,
    required this.source,
    required this.updatedAt,
  });

  final bool isPremium;
  final SubscriptionTier tier;
  final bool resolved;
  final String source;
  final DateTime updatedAt;

  EntitlementSnapshot copyWith({
    bool? isPremium,
    SubscriptionTier? tier,
    bool? resolved,
    String? source,
    DateTime? updatedAt,
  }) {
    return EntitlementSnapshot(
      isPremium: isPremium ?? this.isPremium,
      tier: tier ?? this.tier,
      resolved: resolved ?? this.resolved,
      source: source ?? this.source,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is EntitlementSnapshot &&
        other.isPremium == isPremium &&
        other.tier == tier &&
        other.resolved == resolved &&
        other.source == source &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(isPremium, tier, resolved, source, updatedAt);
}

abstract class PremiumRepository {
  /// Stream of premium status for real-time UI updates
  Stream<bool> get premiumStatusStream;

  /// Stream of full entitlement snapshot for tier-safe UI decisions.
  Stream<EntitlementSnapshot> get entitlementSnapshotStream;

  /// Synchronous check of the last known status
  bool get isPremium;

  /// Current tier of the user (free, pro, proPlus)
  SubscriptionTier get tier;

  /// Last known full entitlement state.
  EntitlementSnapshot get entitlementSnapshot;

  /// Whether premium status has been fully resolved for this app session.
  bool get isStatusResolved;

  /// Whether the app should show ads (inverse of isPremium)
  bool get shouldShowAds;

  /// Refreshes the status from local storage and Remote Config whitelists
  Future<void> refreshStatus();

  /// Manually set the premium status (e.g., after a successful purchase)
  Future<void> setPremium(bool value);
}
