
import 'package:flutter/foundation.dart';
import 'entitlement_model.dart';
import '../../core/premium_service.dart';

abstract class AccessResolver {
  /// Checks if the current user has access to a specific feature
  Future<bool> hasAccess(String featureId);
  
  /// Returns a list of all active features for the user
  Future<Set<String>> getActiveFeatures();
  
  /// Forces a refresh of entitlements from the source of truth
  Future<void> refreshEntitlements();
}

class AccessResolverImpl implements AccessResolver {
  
  // In a real enterprise app, we would have a local db cache of the Entitlement Graph.
  // For Phase 1, we bridge the existing PremiumService to this new interface.
  
  AccessResolverImpl(this._premiumService);
  final PremiumService _premiumService;

  @override
  Future<bool> hasAccess(String featureId) async {
    final features = await getActiveFeatures();
    return features.contains(featureId);
  }

  @override
  Future<Set<String>> getActiveFeatures() async {
    // 1. Fetch source of truth (Subscription Repository / PremiumService)
    final bool isPremium = _premiumService.isPremium;
    
    // 2. Resolve 'Product Tier' to 'Feature Set' (The Entitlement Graph)
    if (isPremium) {
      return {
        FeatureId.noAds,
        FeatureId.magazineAccess,
        FeatureId.advancedSearch,
        FeatureId.audioReading,
        FeatureId.offlineDownloads,
      };
    }
    
    // Default / Free Tier features
    return {
      FeatureId.advancedSearch, // Maybe search is free?
    };
  }

  @override
  Future<void> refreshEntitlements() async {
    // In future: Sync with backend entitlements API
    // For now: Just tell premium service to invalidate cache
    debugPrint("🔄 AccessResolver: Refreshing entitlements...");
  }
}
