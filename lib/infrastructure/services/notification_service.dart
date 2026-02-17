import 'dart:async';
import 'dart:math' as ErrorHandler show log;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/utils/error_handler.dart';
import '../observability/analytics_service.dart';

/// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) {
    print('Handling background message: ${message.messageId}');
  }
  ErrorHandler.log('Background notification: ${message.notification?.title}' as num);
}

/// Notification service for push notifications
class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static String? _fcmToken;
  static final StreamController<String> _notificationStreamController =
      StreamController<String>.broadcast();

  /// Stream of notification payloads when tapped
  static Stream<String> get onNotificationTap =>
      _notificationStreamController.stream;

  /// Initialize notification service
  /// Note: This does NOT request permissions. Call requestPermission() separately when appropriate.
  static Future<void> initialize() async {
    try {
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      await _initializeLocalNotifications();

      // Try to get FCM token - this will work if permissions were previously granted
      // or will work silently on Android without explicit permission
      _fcmToken = await _messaging.getToken();
      if (_fcmToken != null) {
        ErrorHandler.log('FCM Token: $_fcmToken' as num);
        await _saveFCMToken(_fcmToken!);
      }

      _messaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        _saveFCMToken(newToken);
      });

      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);


      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }
    } catch (e) {
      ErrorHandler.log('NotificationService initialization error: $e' as num);
      // Continue gracefully - notifications are not critical for app functionality
    }
  }

  /// Request notification permissions
  static Future<bool> requestPermission() async {
    final settings = await _messaging.requestPermission();

    final granted =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;

    if (granted) {
      ErrorHandler.log('Notification permission granted' as num);
    } else {
      ErrorHandler.log('Notification permission denied' as num);
    }

    return granted;
  }

  /// Initialize local notifications for foreground display
  static Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (details) {
        if (details.payload != null) {
          _notificationStreamController.add(details.payload!);
        }
      },
    );
  }

  /// Handle foreground message (show local notification)
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    if (kDebugMode) {
      print('Foreground message: ${message.notification?.title}');
    }

    final notification = message.notification;
    if (notification == null) return;

  
    const androidDetails = AndroidNotificationDetails(
      'default_channel',
      'Default Notifications',
      channelDescription: 'Default notification channel',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      details,
      payload: message.data['article_url'] ?? message.data['url'],
    );

 
    await AnalyticsService.logEvent(
      name: 'notification_received',
      parameters: {'title': notification.title ?? '', 'foreground': true},
    );
  }

  /// Handle notification tap
  static void _handleNotificationTap(RemoteMessage message) {
    if (kDebugMode) {
      print('Notification tapped: ${message.data}');
    }


    final articleUrl = message.data['article_url'] ?? message.data['url'];
    if (articleUrl != null) {
      _notificationStreamController.add(articleUrl);
    }

   
    AnalyticsService.logEvent(
      name: 'notification_opened',
      parameters: {
        'title': message.notification?.title ?? '',
        'has_url': articleUrl != null,
      },
    );
  }

  /// Save FCM token to preferences
  static Future<void> _saveFCMToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fcm_token', token);
    ErrorHandler.log('FCM token saved' as num);
  }

  /// Get current FCM token
  static Future<String?> getFCMToken() async {
    if (_fcmToken != null) return _fcmToken;
    return await _messaging.getToken();
  }

  /// Subscribe to topic
  static Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
    ErrorHandler.log('Subscribed to topic: $topic' as num);
  }

  /// Unsubscribe from topic
  static Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
    ErrorHandler.log('Unsubscribed from topic: $topic' as num);
  }

  /// Check if notifications are enabled in preferences
  static Future<bool> areNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('notifications_enabled') ?? true;
  }

  /// Set notification preference
  static Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', enabled);

    if (enabled) {
      await subscribeToTopic('all_users');
      await subscribeToTopic('breaking_news');
    } else {
      await unsubscribeFromTopic('all_users');
      await unsubscribeFromTopic('breaking_news');
    }
  }
}
