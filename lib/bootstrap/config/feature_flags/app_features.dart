// ignore_for_file: constant_identifier_names

/// Enumeration of all available feature flags in the application.
/// 
/// This centralized enum prevents "magic string" errors when accessing
/// remote config values.
enum AppFeatures {
  /// Enables the new AI-powered news threading engine (Phase 3).
  enable_news_threading,

  /// Enables the experimental feed ranking algorithm (Phase 3).
  enable_smart_ranking,

  /// Enables detailed performance monitoring logs.
  enable_perf_monitoring,

  /// Kill switch for the entire ad system.
  enable_ads,
  
  /// Enables the new magazine reader UI.
  enable_new_magazine_ui,
}

/// Extension to get the string key for Remote Config.
extension AppFeaturesExtension on AppFeatures {
  String get key {
    return toString().split('.').last;
  }
}
