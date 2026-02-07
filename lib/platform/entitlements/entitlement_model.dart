
enum EntitlementStatus {
  active,
  expired,
  gracePeriod,
  revoked,
  trial
}

enum ProductTier {
  free,
  standard,
  premium,
  family
}

class FeatureId {
  static const String noAds = 'feature.no_ads';
  static const String magazineAccess = 'feature.magazine_access';
  static const String advancedSearch = 'feature.advanced_search';
  static const String audioReading = 'feature.audio_reading';
  static const String offlineDownloads = 'feature.offline_downloads';
}

class Entitlement {

  const Entitlement({
    required this.id,
    required this.userId,
    required this.tier,
    required this.status,
    required this.effectiveFrom,
    required this.expiresAt,
  });
  final String id;
  final String userId;
  final ProductTier tier;
  final EntitlementStatus status;
  final DateTime effectiveFrom;
  final DateTime expiresAt;
  
  bool get isActive {
    final now = DateTime.now();
    return (status == EntitlementStatus.active || status == EntitlementStatus.trial || status == EntitlementStatus.gracePeriod) &&
           now.isAfter(effectiveFrom) && 
           now.isBefore(expiresAt);
  }
}
