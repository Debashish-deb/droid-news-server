import 'package:flutter_test/flutter_test.dart';
import 'package:bdnewsreader/data/models/notification_preferences.dart';

void main() {
  group('NotificationPreferences', () {
    test('TC-UNIT-021: Default preferences created correctly', () {
      final prefs = NotificationPreferences();
      
      // Verify default values
      expect(prefs.enabled, true);
      expect(prefs.breakingNews, true);
      expect(prefs.personalizedAlerts, true);
      expect(prefs.promotional, true);
      expect(prefs.subscribedTopics, isEmpty);
    });

    test('TC-UNIT-022: toJson() serializes all fields', () {
      final prefs = NotificationPreferences(
        personalizedAlerts: false,
        promotional: false,
        subscribedTopics: ['technology', 'sports'],
      );
      
      final json = prefs.toJson();
      
      expect(json, isA<Map<String, dynamic>>());
      expect(json['enabled'], true);
      expect(json['breakingNews'], true);
      expect(json['personalizedAlerts'], false);
      expect(json['promotional'], false);
      expect(json['subscribedTopics'], ['technology', 'sports']);
    });

    test('TC-UNIT-023: fromJson() deserializes correctly', () {
      final json = {
        'enabled': false,
        'breakingNews': true,
        'personalizedAlerts': false,
        'promotional': true,
        'subscribedTopics': ['politics', 'business'],
      };
      
      final prefs = NotificationPreferences.fromJson(json);
      
      expect(prefs.enabled, false);
      expect(prefs.breakingNews, true);
      expect(prefs.personalizedAlerts, false);
      expect(prefs.promotional, true);
      expect(prefs.subscribedTopics, ['politics', 'business']);
    });
  });
}
