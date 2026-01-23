/// Subscription tier levels available in the application.
enum SubscriptionTier {
  free,
  pro,
  proPlus;

  /// Returns the display name for this tier.
  String get displayName {
    switch (this) {
      case SubscriptionTier.free:
        return 'Free';
      case SubscriptionTier.pro:
        return 'Pro';
      case SubscriptionTier.proPlus:
        return 'Pro Plus';
    }
  }

  /// Returns true if this tier includes premium features.
  bool get isPremium => this != SubscriptionTier.free;
}

/// Status of a subscription.
enum SubscriptionStatus { active, expired, cancelled, pending }

/// Domain entity representing a user's subscription.
class Subscription {
  const Subscription({
    required this.id,
    required this.userId,
    required this.tier,
    required this.status,
    required this.startDate,
    this.endDate,
    this.autoRenew = false,
    this.features = const [],
  });
  final String id;
  final String userId;
  final SubscriptionTier tier;
  final SubscriptionStatus status;
  final DateTime startDate;
  final DateTime? endDate;
  final bool autoRenew;
  final List<String> features;

  /// Returns true if the subscription is currently active.
  bool get isActive => status == SubscriptionStatus.active;

  /// Returns true if the subscription has expired.
  bool get isExpired {
    if (endDate == null) return false;
    return DateTime.now().isAfter(endDate!) &&
        status != SubscriptionStatus.active;
  }

  /// Returns true if the user can access the given feature.
  bool canAccessFeature(String featureId) {
    return isActive && features.contains(featureId);
  }

  /// Returns the number of days until expiration.
  /// Returns null if there's no end date or already expired.
  int? get daysUntilExpiration {
    if (endDate == null) return null;
    if (isExpired) return 0;
    return endDate!.difference(DateTime.now()).inDays;
  }

  Subscription copyWith({
    String? id,
    String? userId,
    SubscriptionTier? tier,
    SubscriptionStatus? status,
    DateTime? startDate,
    DateTime? endDate,
    bool? autoRenew,
    List<String>? features,
  }) {
    return Subscription(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      tier: tier ?? this.tier,
      status: status ?? this.status,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      autoRenew: autoRenew ?? this.autoRenew,
      features: features ?? this.features,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Subscription &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Subscription(id: $id, tier: ${tier.displayName}, status: $status)';
}
