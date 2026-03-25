class PremiumPlanConfig {
  const PremiumPlanConfig._();

  // Primary Play Console product IDs (expected active IDs).
  static const String proLifetimeProductId = 'pro_lifetime_699';
  static const String proYearlyProductId = 'pro_yearly_199';

  // Legacy IDs kept only for restore/backward compatibility.
  static const String legacyRemoveAdsProductId = 'remove_ads';
  static const String legacyProProductId = 'pro_subscription';
  static const String legacyProPlusProductId = 'pro_plus_subscription';

  static const Set<String> primaryProductIds = {
    proLifetimeProductId,
    proYearlyProductId,
  };

  static const Set<String> allKnownProductIds = {
    proLifetimeProductId,
    proYearlyProductId,
    legacyRemoveAdsProductId,
    legacyProProductId,
    legacyProPlusProductId,
  };

  static const String proLifetimeDisplayPrice = 'EUR 6.99';
  static const String proYearlyDisplayPrice = 'EUR 1.99/year';
}
