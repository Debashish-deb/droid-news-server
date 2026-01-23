import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/premium_service.dart';
import 'shared_providers.dart';
import '../../domain/repositories/subscription_repository.dart';
import '../../data/repositories/subscription_repository_impl.dart';

// ============================================================================
// Premium/Subscription State Management
// ============================================================================

/// Premium state wrapping PremiumService for Riverpod
class PremiumState {
  const PremiumState({
    this.isPremium = false,
    this.tier = 'free',
    this.unlockedFeatures = const [],
  });
  final bool isPremium;
  final String tier;
  final List<String> unlockedFeatures;

  PremiumState copyWith({
    bool? isPremium,
    String? tier,
    List<String>? unlockedFeatures,
  }) {
    return PremiumState(
      isPremium: isPremium ?? this.isPremium,
      tier: tier ?? this.tier,
      unlockedFeatures: unlockedFeatures ?? this.unlockedFeatures,
    );
  }

  /// Check if a specific feature is unlocked
  bool hasFeature(String featureId) {
    return isPremium || unlockedFeatures.contains(featureId);
  }

  bool get isFree => !isPremium;
}

/// Premium Notifier - wraps PremiumService for now
class PremiumNotifier extends StateNotifier<PremiumState> {
  PremiumNotifier(this._service) : super(const PremiumState()) {
    _loadStatus();
    // Listen to changes in the underlying service
    _service.addListener(_onServiceChanged);
  }
  final PremiumService _service;

  void _loadStatus() {
    state = PremiumState(
      isPremium: _service.isPremium,
      tier: _service.isPremium ? 'pro' : 'free',
    );
  }

  void _onServiceChanged() {
    _loadStatus();
  }

  Future<void> reload() async {
    await _service.reloadStatus();
    _loadStatus();
  }

  Future<void> setPremium(bool value) async {
    await _service.setPremium(value);
    _loadStatus();
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceChanged);
    super.dispose();
  }
}

/// Global premium service instance (from main.dart)
/// This is a temporary provider until we fully migrate PremiumService
final legacyPremiumServiceProvider = Provider<PremiumService>((ref) {
  // Access the global instance from main.dart
  final prefs = ref.watch(sharedPreferencesProvider);

  // Note: In a real migration, we'd refactor PremiumService entirely
  // For now, we'll use the global instance from main.dart
  throw UnimplementedError(
    'Use the global premiumService from main.dart until full migration',
  );
});

// ============================================================================
// Premium State Provider - Watches actual PremiumService
// ============================================================================

/// Premium state provider - bridges to legacy PremiumService until full migration
/// This is a workaround: we watch SharedPreferences and rebuild when it changes
final premiumStatusProvider = Provider<bool>((ref) {
  // Force rebuild when preferences change
  final prefs = ref.watch(sharedPreferencesProvider);
  // Read the local premium status from prefs
  return prefs.getBool('is_premium') ?? false;
});

/// Convenience provider for premium status
final isPremiumProvider = Provider<bool>((ref) {
  return ref.watch(premiumStatusProvider);
});

/// Provides just the tier name
final tierNameProvider = Provider<String>((ref) {
  final isPremium = ref.watch(isPremiumProvider);
  return isPremium ? 'pro' : 'free';
});

/// Provider family to check if a specific feature is available
final hasFeatureProvider = Provider.family<bool, String>((ref, featureId) {
  // All features available if premium
  final isPremium = ref.watch(isPremiumProvider);
  return isPremium;
});

// NOTE: This is a transitional provider setup.
// For full clean architecture, we should:
// 1. Create SubscriptionRepository implementation ✅ DONE
// 2. Create CheckSubscriptionStatusUseCase
// 3. Create proper SubscriptionNotifier with Either<Failure, Subscription>
// 4. Remove dependency on global PremiumService

// For now, this provides a Riverpod interface to the existing service

// ============================================================================
// NEW: Subscription Repository Provider
// ============================================================================

/// Provider for SubscriptionRepository
final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SubscriptionRepositoryImpl(prefs: prefs);
});
