/// abstract definition of Premium Access Rules.
/// 
/// This policy determines if a specific feature or content is accessible
/// based on the user's subscription tier.
/// 
/// It belongs in the Domain layer and must remain pure Dart.
abstract class PremiumAccessPolicy {
  /// Determines if the user can access a specific feature.
  bool canAccessFeature(String featureId, bool isPremiumUser);

  /// Determines if the user can read a specific article.
  /// 
  /// [contentTier] might be 'free', 'registered', or 'premium'.
  bool canReadContent({
    required bool isPremiumUser,
    required String contentTier,
    required int freeArticlesReadCount,
  });
}
