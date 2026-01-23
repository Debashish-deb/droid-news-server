import 'package:shared_preferences/shared_preferences.dart';

/// Model for storing user notification preferences
class NotificationPreferences {
  NotificationPreferences({
    this.enabled = true,
    this.breakingNews = true,
    this.personalizedAlerts = true,
    this.promotional = true,
    this.subscribedTopics = const <String>[],
  });

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      enabled: json['enabled'] as bool? ?? true,
      breakingNews: json['breakingNews'] as bool? ?? true,
      personalizedAlerts: json['personalizedAlerts'] as bool? ?? true,
      promotional: json['promotional'] as bool? ?? true,
      subscribedTopics:
          (json['subscribedTopics'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          <String>[],
    );
  }

  bool enabled;
  bool breakingNews;
  bool personalizedAlerts;
  bool promotional;
  List<String> subscribedTopics;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'enabled': enabled,
      'breakingNews': breakingNews,
      'personalizedAlerts': personalizedAlerts,
      'promotional': promotional,
      'subscribedTopics': subscribedTopics,
    };
  }

  /// Save preferences to SharedPreferences
  Future<void> save(SharedPreferences prefs) async {
    await prefs.setBool('notif_enabled', enabled);
    await prefs.setBool('notif_breaking_news', breakingNews);
    await prefs.setBool('notif_personalized', personalizedAlerts);
    await prefs.setBool('notif_promotional', promotional);
    await prefs.setStringList('notif_topics', subscribedTopics);
  }

  /// Load preferences from SharedPreferences
  static NotificationPreferences load(SharedPreferences prefs) {
    return NotificationPreferences(
      enabled: prefs.getBool('notif_enabled') ?? true,
      breakingNews: prefs.getBool('notif_breaking_news') ?? true,
      personalizedAlerts: prefs.getBool('notif_personalized') ?? true,
      promotional: prefs.getBool('notif_promotional') ?? true,
      subscribedTopics: prefs.getStringList('notif_topics') ?? <String>[],
    );
  }
}
