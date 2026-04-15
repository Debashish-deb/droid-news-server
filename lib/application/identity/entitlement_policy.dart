// ignore_for_file: avoid_classes_with_only_static_members

import '../../core/enums/theme_mode.dart';
import '../../domain/entities/subscription.dart';

abstract final class EntitlementPolicy {
  static const int freeTtsDailyArticleLimit = 5;
  static const int freeTtsMonthlyArticleLimit = 150;

  static const String adFree = 'ad_free';
  static const String publisherAdBlocking = 'publisher_ad_blocking';
  static const String offlineReading = 'offline_reading';
  static const String unlimitedArticles = 'unlimited_articles';
  static const String unlimitedTts = 'unlimited_tts';
  static const String readerMode = 'reader_mode';
  static const String allSources = 'all_sources';

  static const List<String> freeFeatures = <String>[
    publisherAdBlocking,
    unlimitedArticles,
    readerMode,
    allSources,
  ];

  static const List<String> premiumFeatures = <String>[
    adFree,
    publisherAdBlocking,
    offlineReading,
    unlimitedArticles,
    unlimitedTts,
    readerMode,
    allSources,
  ];

  static const Set<AppThemeMode> freeThemeModes = <AppThemeMode>{
    AppThemeMode.system,
    AppThemeMode.dark,
    AppThemeMode.bangladesh,
  };

  static const Set<AppThemeMode> premiumThemeModes = <AppThemeMode>{
    AppThemeMode.system,
    AppThemeMode.dark,
    AppThemeMode.bangladesh,
  };

  static bool isPremiumTier(SubscriptionTier tier) {
    return tier == SubscriptionTier.pro;
  }

  static List<String> featuresForTier(SubscriptionTier tier) {
    return isPremiumTier(tier) ? premiumFeatures : freeFeatures;
  }

  static bool hasFeature(SubscriptionTier tier, String featureId) {
    return featuresForTier(tier).contains(featureId);
  }

  static Set<AppThemeMode> themeModesForTier(SubscriptionTier tier) {
    return isPremiumTier(tier) ? premiumThemeModes : freeThemeModes;
  }

  static bool canUseTheme(SubscriptionTier tier, AppThemeMode mode) {
    return themeModesForTier(tier).contains(normalizeThemeMode(mode));
  }
}
