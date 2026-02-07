import 'package:shared_preferences/shared_preferences.dart';

/// Manages user consent for data collection (GDPR/CCPA compliance)
class ConsentManager {
  factory ConsentManager() => _instance;
  ConsentManager._();
  static final ConsentManager _instance = ConsentManager._();

  late SharedPreferences _prefs;
  bool _initialized = false;

  static const String _keyAnalyticsConsent = 'consent_analytics';
  static const String _keyPersonalizationConsent = 'consent_personalization';
  static const String _keyCrashReportingConsent = 'consent_crash_reporting';

  Future<void> init(SharedPreferences prefs) async {
    if (_initialized) return;
    _prefs = prefs;
    _initialized = true;
  }

  /// Whether user has consented to analytics tracking
  bool get canTrackAnalytics => _prefs.getBool(_keyAnalyticsConsent) ?? false;

  /// Whether user has consented to personalized content
  bool get canPersonalize => _prefs.getBool(_keyPersonalizationConsent) ?? false;
  
  /// Whether user has consented to crash reporting
  bool get canReportCrashes => _prefs.getBool(_keyCrashReportingConsent) ?? true; // Default true often standard, but check local laws

  /// Update analytics consent
  Future<void> setAnalyticsConsent(bool allowed) async {
    await _prefs.setBool(_keyAnalyticsConsent, allowed);
  }

  /// Update personalization consent
  Future<void> setPersonalizationConsent(bool allowed) async {
    await _prefs.setBool(_keyPersonalizationConsent, allowed);
  }
  
  /// Update crash reporting consent
  Future<void> setCrashReportingConsent(bool allowed) async {
    await _prefs.setBool(_keyCrashReportingConsent, allowed);
  }
}
