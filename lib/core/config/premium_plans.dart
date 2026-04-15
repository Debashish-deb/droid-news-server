class PremiumPlanConfig {
  const PremiumPlanConfig._();

  // Primary Play Console product IDs (expected active IDs).
  static const String proLifetimeProductId = 'pro_lifetime_790';
  static const String proYearlyProductId = 'pro_yearly_199';

  // Retired purchase IDs still restored as the same Pro entitlement.
  static const Set<String> retiredPremiumProductIds = <String>{
    'remove_ads',
    'pro_subscription',
    'pro_lifetime_699',
  };

  static const Set<String> primaryProductIds = {
    proLifetimeProductId,
    proYearlyProductId,
  };

  static const Set<String> allKnownProductIds = {
    proLifetimeProductId,
    proYearlyProductId,
    ...retiredPremiumProductIds,
  };

  static const String proLifetimeDisplayPrice = 'EUR/USD 7.90';
  static const String proYearlyDisplayPrice = 'EUR/USD 1.99/year';
}
