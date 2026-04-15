import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:synchronized/synchronized.dart' as synchronized;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../application/identity/entitlement_policy.dart';
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
/// Free users should always be ad-eligible; Pro remains strictly ad-free.
final shouldShowAdsProvider = Provider<bool>((ref) {
  final snapshot = ref.watch(entitlementSnapshotProvider);
  return !snapshot.isPremium;
});

/// Publisher/webview ad blocking is allowed for every tier.
///
/// This is separate from app-owned AdMob surfaces:
/// free users may still see AdMob placements, while Pro sees none.
final publisherAdBlockingEnabledProvider = Provider<bool>((ref) {
  final tier = ref.watch(currentTierProvider);
  return EntitlementPolicy.hasFeature(
    tier,
    EntitlementPolicy.publisherAdBlocking,
  );
});

/// Provides the current premium tier enum
final currentTierProvider = Provider<SubscriptionTier>((ref) {
  return ref.watch(entitlementSnapshotProvider).tier;
});

/// Provider family to check if a specific feature is available.
/// This prevents "tier leak" where a lower tier user gets higher tier features.
final hasFeatureProvider = Provider.family<bool, String>((ref, featureId) {
  final tier = ref.watch(currentTierProvider);
  return EntitlementPolicy.hasFeature(tier, featureId);
});

/// Shared counter for free article views, persisted to SharedPreferences and backend
class FreeViewsNotifier extends AsyncNotifier<int> {
  static final synchronized.Lock _consumeLock = synchronized.Lock();

  @override
  Future<int> build() async {
    final prefs = ref.watch(sharedPreferencesProvider);
    return _readCurrentFreeViews(prefs);
  }

  Future<int> _readCurrentFreeViews(SharedPreferences? prefs) async {
    int localViews = prefs?.getInt('free_views_used') ?? 0;

    final user = FirebaseAuth.instance.currentUser;
    if (user != null && !user.isAnonymous) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('user_usage')
            .doc(user.uid)
            .get(const GetOptions());

        if (doc.exists) {
          final backendViews = doc.data()?['free_views_used'] as int? ?? 0;
          if (backendViews > localViews) {
            localViews = backendViews;
            prefs?.setInt('free_views_used', backendViews);
          }
        }
      } catch (e) {
        debugPrint('Error fetching backend free views: $e');
      }
    }
    return localViews;
  }

  Future<void> increment() async {
    final prefs = ref.read(sharedPreferencesProvider);
    final current = state.valueOrNull ?? 0;
    final newValue = current + 1;

    state = AsyncData(newValue);
    prefs?.setInt('free_views_used', newValue);

    final user = FirebaseAuth.instance.currentUser;
    if (user != null && !user.isAnonymous) {
      try {
        final docRef = FirebaseFirestore.instance
            .collection('user_usage')
            .doc(user.uid);

        await docRef.set({
          'free_views_used': newValue,
          'last_free_view_date': DateTime.now().toIso8601String(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Error syncing free views to backend: $e');
      }
    }
  }

  Future<bool> tryConsumeIfAvailable({required int maxFreeViews}) async {
    return _consumeLock.synchronized(() async {
      final prefs = ref.read(sharedPreferencesProvider);
      final current = state.valueOrNull ?? await _readCurrentFreeViews(prefs);

      state = AsyncData(current);
      if (current >= maxFreeViews) {
        return false;
      }

      final newValue = current + 1;
      state = AsyncData(newValue);
      if (prefs != null) {
        await prefs.setInt('free_views_used', newValue);
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user != null && !user.isAnonymous) {
        try {
          final docRef = FirebaseFirestore.instance
              .collection('user_usage')
              .doc(user.uid);

          await docRef.set({
            'free_views_used': newValue,
            'last_free_view_date': DateTime.now().toIso8601String(),
          }, SetOptions(merge: true));
        } catch (e) {
          debugPrint('Error syncing free views to backend: $e');
        }
      }

      return true;
    });
  }
}

final freeViewsProvider = AsyncNotifierProvider<FreeViewsNotifier, int>(() {
  return FreeViewsNotifier();
});
