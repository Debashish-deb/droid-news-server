import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/notification_preferences.dart';

/// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) {
    debugPrint('🔔 Background message received: ${message.messageId}');
    debugPrint('   Title: ${message.notification?.title}');
    debugPrint('   Body: ${message.notification?.body}');
    debugPrint('   Data: ${message.data}');
  }
}

/// Production-ready push notification service using FCM and local notifications
class PushNotificationService {
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();
  static final PushNotificationService _instance =
      PushNotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  NotificationPreferences _preferences = NotificationPreferences();
  SharedPreferences? _prefs;
  String? _fcmToken;
  bool _initialized = false;

  // Callback for notification taps
  Function(Map<String, dynamic>)? onNotificationTap;

  /// Initialize the notification service
  Future<void> initialize({SharedPreferences? prefs}) async {
    if (_initialized) return;

    _prefs = prefs ?? await SharedPreferences.getInstance();
    _preferences = NotificationPreferences.load(_prefs!);

    // Initialize local notifications
    await _initializeLocalNotifications();

    // Request permissions
    await requestPermission();

    // Get FCM token
    await _getFCMToken();

    // Setup message handlers
    _setupMessageHandlers();

    // Subscribe to default topics based on preferences
    await _syncTopicSubscriptions();

    _initialized = true;

    if (kDebugMode) {
      debugPrint('✅ Push notification service initialized');
    }
  }

  /// Initialize Flutter Local Notifications
  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings();

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create Android notification channels
    if (!kIsWeb) {
      await _createNotificationChannels();
    }
  }

  /// Create Android notification channels
  Future<void> _createNotificationChannels() async {
    const AndroidNotificationChannel generalChannel =
        AndroidNotificationChannel(
          'general_news',
          'General News',
          description: 'Breaking news and general updates',
          importance: Importance.high,
        );

    const AndroidNotificationChannel personalizedChannel =
        AndroidNotificationChannel(
          'personalized',
          'Personalized Alerts',
          description: 'Notifications based on your preferences',
          importance: Importance.high,
        );

    const AndroidNotificationChannel promotionalChannel =
        AndroidNotificationChannel(
          'promotional',
          'Promotional',
          description: 'Special offers and promotions',
        );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(generalChannel);

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(personalizedChannel);

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(promotionalChannel);
  }

  /// Request notification permissions
  Future<bool> requestPermission() async {
    final NotificationSettings settings = await _fcm.requestPermission();

    final bool granted =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;

    if (kDebugMode) {
      debugPrint('📱 Notification permission: ${settings.authorizationStatus}');
    }

    return granted;
  }

  /// Get FCM token
  Future<String?> _getFCMToken() async {
    try {
      _fcmToken = await _fcm.getToken();

      if (_fcmToken != null) {
        await _prefs?.setString('fcm_token', _fcmToken!);

        if (kDebugMode) {
          debugPrint('🔑 FCM Token: $_fcmToken');
        }

        // Send token to backend server
        await _sendTokenToBackend(_fcmToken!);
      }

      return _fcmToken;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error getting FCM token: $e');
      }
      return null;
    }
  }

  /// Setup FCM message handlers
  void _setupMessageHandlers() {
    // Foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Background/terminated tap handler
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpen);

    // Token refresh
    _fcm.onTokenRefresh.listen((String newToken) {
      _fcmToken = newToken;
      _prefs?.setString('fcm_token', newToken);

      if (kDebugMode) {
        debugPrint('🔄 FCM Token refreshed: $newToken');
      }

      // Send updated token to backend
      _sendTokenToBackend(newToken);
    });
  }

  /// Handle foreground messages by showing local notification
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    if (kDebugMode) {
      debugPrint('🔔 Foreground message: ${message.messageId}');
    }

    // Check if notifications are enabled
    if (!_preferences.enabled) return;

    final RemoteNotification? notification = message.notification;
    final AndroidNotification? android = message.notification?.android;

    if (notification != null) {
      // Determine channel based on message data
      String channelId = 'general_news';
      if (message.data['channel'] != null) {
        channelId = message.data['channel'] as String;
      }

      // Show local notification
      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelId == 'general_news'
                ? 'General News'
                : channelId == 'personalized'
                ? 'Personalized Alerts'
                : 'Promotional',
            channelDescription: 'App notifications',
            importance: Importance.high,
            priority: Priority.high,
            icon: android?.smallIcon ?? '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: jsonEncode(message.data),
      );
    }
  }

  /// Handle notification tap when app is in background/terminated
  Future<void> _handleNotificationOpen(RemoteMessage message) async {
    if (kDebugMode) {
      debugPrint('🎯 Notification tapped: ${message.data}');
    }

    if (onNotificationTap != null) {
      onNotificationTap!(message.data);
    }
  }

  /// Handle local notification tap
  void _onNotificationTapped(NotificationResponse response) async {
    if (response.payload != null && onNotificationTap != null) {
      final Map<String, dynamic> data =
          jsonDecode(response.payload!) as Map<String, dynamic>;
      onNotificationTap!(data);
    }
  }

  /// Check if notification opened the app initially
  Future<void> checkInitialMessage() async {
    final RemoteMessage? initialMessage = await _fcm.getInitialMessage();

    if (initialMessage != null) {
      if (kDebugMode) {
        debugPrint('🚀 App opened from notification: ${initialMessage.data}');
      }

      // Delay to ensure app is fully initialized
      Future<void>.delayed(const Duration(seconds: 1), () {
        if (onNotificationTap != null) {
          onNotificationTap!(initialMessage.data);
        }
      });
    }
  }

  /// Subscribe to a topic
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _fcm.subscribeToTopic(topic);

      if (!_preferences.subscribedTopics.contains(topic)) {
        _preferences.subscribedTopics.add(topic);
        await _preferences.save(_prefs!);
      }

      if (kDebugMode) {
        debugPrint('✅ Subscribed to topic: $topic');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error subscribing to topic $topic: $e');
      }
    }
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _fcm.unsubscribeFromTopic(topic);

      _preferences.subscribedTopics.remove(topic);
      await _preferences.save(_prefs!);

      if (kDebugMode) {
        debugPrint('✅ Unsubscribed from topic: $topic');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error unsubscribing from topic $topic: $e');
      }
    }
  }

  /// Sync topic subscriptions based on preferences
  Future<void> _syncTopicSubscriptions() async {
    // Subscribe to enabled topics
    if (_preferences.breakingNews) {
      await subscribeToTopic('breaking_news');
    } else {
      await unsubscribeFromTopic('breaking_news');
    }

    if (_preferences.personalizedAlerts) {
      await subscribeToTopic('personalized');
    } else {
      await unsubscribeFromTopic('personalized');
    }

    if (_preferences.promotional) {
      await subscribeToTopic('promotional');
    } else {
      await unsubscribeFromTopic('promotional');
    }
  }

  /// Update notification preferences
  Future<void> updatePreferences(NotificationPreferences newPreferences) async {
    _preferences = newPreferences;
    await _preferences.save(_prefs!);
    await _syncTopicSubscriptions();
  }

  /// Get current preferences
  NotificationPreferences get preferences => _preferences;

  /// Get FCM token
  String? get token => _fcmToken;

  /// Check if notifications are enabled
  bool get isEnabled => _preferences.enabled;

  /// Open system notification settings
  static Future<void> openNotificationSettings() async {
    // This would open the app's notification settings in system settings
    // Implementation varies by platform
    if (kDebugMode) {
      debugPrint('📱 Opening system notification settings...');
    }
  }

  /// Send FCM token to backend server
  Future<void> _sendTokenToBackend(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final platform = Platform.isAndroid ? 'android' : 'ios';

      await FirebaseFunctions.instance
          .httpsCallable('saveNotificationToken')
          .call({'token': token, 'platform': platform});

      if (kDebugMode) {
        debugPrint('✅ Token sent to backend successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error sending token to backend: $e');
      }
      // Don't throw - token storage is not critical
    }
  }
}
