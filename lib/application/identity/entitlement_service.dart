// lib/application/identity/entitlement_service.dart

import '../../core/premium_service.dart';

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

  EntitlementService({required PremiumService premium}) : _premium = premium;
  final PremiumService _premium;

  /// Returns true if the current user has access to the specified feature.
  bool hasAccess(AppFeature feature) {
    switch (feature) {
      case AppFeature.offlineReading:
      case AppFeature.unlimitedTts:
      case AppFeature.adFreeExperience:
      case AppFeature.advancedAnalytics:
        return _premium.isPremium;

      case AppFeature.smartFeed:
        return true;
        
      default:
        return false;
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
