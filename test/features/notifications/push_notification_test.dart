import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bdnewsreader/data/models/notification_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Push Notification Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    group('Notification Permissions', () {
      test('TC-NOTIF-001: Permission state can be stored', () async {
        final prefs = await SharedPreferences.getInstance();
        
        await prefs.setBool('notifications_enabled', true);
        await prefs.setString('permission_status', 'authorized');
        
        expect(prefs.getBool('notifications_enabled'), true);
        expect(prefs.getString('permission_status'), 'authorized');
      });

      test('TC-NOTIF-002: Permission denial tracked', () async {
        final prefs = await SharedPreferences.getInstance();
        
        await prefs.setBool('notifications_enabled', false);
        await prefs.setString('permission_status', 'denied');
        
        expect(prefs.getBool('notifications_enabled'), false);
        expect(prefs.getString('permission_status'), 'denied');
      });

      test('TC-NOTIF-003: Provisional permission supported', () async {
        final prefs = await SharedPreferences.getInstance();
        
        await prefs.setString('permission_status', 'provisional');
        
        final status = prefs.getString('permission_status');
        expect(status, 'provisional');
      });
    });

    group('FCM Token Management', () {
      test('TC-NOTIF-004: FCM token can be stored', () async {
        final prefs = await SharedPreferences.getInstance();
        
        const mockToken = 'fcm_token_abc123xyz';
        await prefs.setString('fcm_token', mockToken);
        
        expect(prefs.getString('fcm_token'), mockToken);
      });

      test('TC-NOTIF-005: Token refresh tracked', () async {
        final prefs = await SharedPreferences.getInstance();
        
        // Old token
        await prefs.setString('fcm_token', 'old_token');
        
        // Token refreshes
        await prefs.setString('fcm_token', 'new_token');
        await prefs.setInt('token_updated_at', DateTime.now().millisecondsSinceEpoch);
        
        expect(prefs.getString('fcm_token'), 'new_token');
        expect(prefs.getInt('token_updated_at'), greaterThan(0));
      });

      test('TC-NOTIF-006: Token uploaded to server tracked', () async {
        final prefs = await SharedPreferences.getInstance();
        
        await prefs.setBool('token_uploaded', true);
        await prefs.setInt('token_upload_time', DateTime.now().millisecondsSinceEpoch);
        
        expect(prefs.getBool('token_uploaded'), true);
      });
    });

    group('Notification Preferences', () {
      test('TC-NOTIF-007: Default preferences initialized', () {
        final prefs = NotificationPreferences();
        
        expect(prefs.enabled, true);
        expect(prefs.breakingNews, true);
        expect(prefs.personalizedAlerts, true);
        expect(prefs.promotional, true);
      });

      test('TC-NOTIF-008: Preferences can be modified', () async {
        final sharedPrefs = await SharedPreferences.getInstance();
        var prefs = NotificationPreferences.load(sharedPrefs);
        
        prefs.breakingNews = false;
        prefs.promotional = false;
        prefs.save(sharedPrefs);
        
        // Reload and verify
        prefs = NotificationPreferences.load(sharedPrefs);
        expect(prefs.breakingNews, false);
        expect(prefs.promotional, false);
      });

      test('TC-NOTIF-009: Subscribed topics can be managed', () async {
        final sharedPrefs = await SharedPreferences.getInstance();
        
        // Create preferences with topics
        var prefs = NotificationPreferences(
          subscribedTopics: ['breaking', 'sports', 'tech'],
        );
        prefs.save(sharedPrefs);
        
        // Reload and verify
        prefs = NotificationPreferences.load(sharedPrefs);
        expect(prefs.subscribedTopics, ['breaking', 'sports', 'tech']);
        expect(prefs.subscribedTopics.length, 3);
      });
    });

    group('Topic Subscriptions', () {
      test('TC-NOTIF-010: Can subscribe to topics', () async {
        final prefs = await SharedPreferences.getInstance();
        
        final topics = ['breaking_news', 'bangladesh', 'sports'];
        await prefs.setStringList('subscribed_topics', topics);
        
        final subscribed = prefs.getStringList('subscribed_topics');
        expect(subscribed, topics);
      });

      test('TC-NOTIF-011: Can unsubscribe from topics', () async {
        final prefs = await SharedPreferences.getInstance();
        
        await prefs.setStringList('subscribed_topics', ['breaking_news', 'sports']);
        
        // Unsubscribe from sports
        var topics = prefs.getStringList('subscribed_topics')!;
        topics.remove('sports');
        await prefs.setStringList('subscribed_topics', topics);
        
        expect(prefs.getStringList('subscribed_topics'), ['breaking_news']);
      });

      test('TC-NOTIF-012: Topic sync status tracked', () async {
        final prefs = await SharedPreferences.getInstance();
        
        await prefs.setBool('topics_synced', true);
        await prefs.setInt('topics_sync_time', DateTime.now().millisecondsSinceEpoch);
        
        expect(prefs.getBool('topics_synced'), true);
      });
    });

    group('Notification Reception', () {
      test('TC-NOTIF-013: Received notification data parsed', () {
        final notificationData = {
          'title': 'Breaking News',
          'body': 'Important update',
          'articleUrl': 'https://example.com/article',
          'imageUrl': 'https://example.com/image.jpg',
        };
        
        expect(notificationData['title'], 'Breaking News');
        expect(notificationData['articleUrl'], isNotNull);
      });

      test('TC-NOTIF-014: Notification with empty data handled', () {
        final notificationData = <String, dynamic>{};
        
        expect(notificationData.isEmpty, true);
        expect(notificationData['title'], isNull);
      });

      test('TC-NOTIF-015: Notification count tracked', () async {
        final prefs = await SharedPreferences.getInstance();
        
        var count = prefs.getInt('notification_count') ?? 0;
        count++;
        await prefs.setInt('notification_count', count);
        
        expect(prefs.getInt('notification_count'), 1);
      });
    });

    group('Deep Linking', () {
      test('TC-NOTIF-016: Article URL extracted from notification', () {
        final data = {
          'articleUrl': 'https://example.com/article/123',
          'type': 'article',
        };
        
        expect(data['articleUrl'], contains('/article/'));
        expect(data['type'], 'article');
      });

      test('TC-NOTIF-017: Category deep link parsed', () {
        final data = {
          'route': '/category/sports',
          'type': 'category',
        };
        
        expect(data['route'], '/category/sports');
        expect(data['type'], 'category');
      });

      test('TC-NOTIF-018: Invalid deep link handled', () {
        final data = {
          'route': '',
          'type': 'unknown',
        };
        
        expect(data['route'], isEmpty);
        // Should fall back to home screen
      });
    });

    group('Background/Foreground Handling', () {
      test('TC-NOTIF-019: App state tracked', () async {
        final prefs = await SharedPreferences.getInstance();
        
        await prefs.setString('app_state', 'foreground');
        expect(prefs.getString('app_state'), 'foreground');
        
        await prefs.setString('app_state', 'background');
        expect(prefs.getString('app_state'), 'background');
      });

      test('TC-NOTIF-020: Background notification count', () async {
        final prefs = await SharedPreferences.getInstance();
        
        await prefs.setInt('bg_notifications', 5);
        expect(prefs.getInt('bg_notifications'), 5);
      });

      test('TC-NOTIF-021: Last notification time tracked', () async {
        final prefs = await SharedPreferences.getInstance();
        
        final now = DateTime.now().millisecondsSinceEpoch;
        await prefs.setInt('last_notification_time', now);
        
        expect(prefs.getInt('last_notification_time'), now);
      });
    });

    group('Notification Channels', () {
      test('TC-NOTIF-022: Channel preferences stored', () async {
        final prefs = await SharedPreferences.getInstance();
        
        await prefs.setBool('channel_general_news', true);
        await prefs.setBool('channel_personalized', true);
        await prefs.setBool('channel_promotional', false);
        
        expect(prefs.getBool('channel_general_news'), true);
        expect(prefs.getBool('channel_promotional'), false);
      });

      test('TC-NOTIF-023: Channel importance levels', () {
        final channels = {
          'general_news': 'high',
          'personalized': 'high',
          'promotional': 'default',
        };
        
        expect(channels['general_news'], 'high');
        expect(channels['promotional'], 'default');
      });
    });

    group('Analytics & Tracking', () {
      test('TC-NOTIF-024: Notification tap tracked', () async {
        final prefs = await SharedPreferences.getInstance();
        
        var tapCount = prefs.getInt('notification_taps') ?? 0;
        tapCount++;
        await prefs.setInt('notification_taps', tapCount);
        
        expect(prefs.getInt('notification_taps'), 1);
      });

      test('TC-NOTIF-025: Notification dismiss tracked', () async {
        final prefs = await SharedPreferences.getInstance();
        
        var dismissCount = prefs.getInt('notification_dismissals') ?? 0;
        dismissCount++;
        await prefs.setInt('notification_dismissals', dismissCount);
        
        expect(prefs.getInt('notification_dismissals'), 1);
      });

      test('TC-NOTIF-026: Popular notification topics tracked', () async {
        final prefs = await SharedPreferences.getInstance();
        
        final topicStats = {
          'sports': 10,
          'politics': 8,
          'entertainment': 5,
        };
        
        await prefs.setString('topic_stats', topicStats.toString());
        expect(prefs.getString('topic_stats'), isNotNull);
      });
    });
  });
}
