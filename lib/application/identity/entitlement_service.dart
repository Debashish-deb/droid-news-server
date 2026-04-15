// lib/application/identity/entitlement_service.dart

import 'entitlement_policy.dart';
import '../../domain/repositories/premium_repository.dart';

/// Enum defining all gated features in the app.
enum AppFeature {
  offlineReading,
  unlimitedTts,
  adFreeExperience,
  advancedAnalytics,
  smartFeed,
}

/// Service to resolve if a user has access to a specific feature.
class EntitlementService {
  EntitlementService({required PremiumRepository premium}) : _premium = premium;
  final PremiumRepository _premium;

  /// Returns true if the current user has access to the specified feature.
  bool hasAccess(AppFeature feature) {
    final tier = _premium.tier;
    switch (feature) {
      case AppFeature.offlineReading:
        return EntitlementPolicy.hasFeature(
          tier,
          EntitlementPolicy.offlineReading,
        );
      case AppFeature.unlimitedTts:
        return EntitlementPolicy.hasFeature(
          tier,
          EntitlementPolicy.unlimitedTts,
        );
      case AppFeature.adFreeExperience:
        return EntitlementPolicy.hasFeature(tier, EntitlementPolicy.adFree);
      case AppFeature.advancedAnalytics:
        return _premium.isPremium;

      case AppFeature.smartFeed:
        return true;
    }
  }

  /// Maps subscription tiers to feature sets (future-proofing)
  List<AppFeature> getEntitlements() {
    if (_premium.isPremium) {
      return AppFeature.values;
    }
    return [AppFeature.smartFeed];
  }
}
