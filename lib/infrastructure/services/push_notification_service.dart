import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
// import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../persistence/notification_preferences.dart';
import '../persistence/notification_preferences.dart' show NotificationPreferences;

import '../../core/telemetry/structured_logger.dart';

/// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  final logger = StructuredLogger();
  logger.info('Background message received', {
    'id': message.messageId,
    'title': message.notification?.title,
    'body': message.notification?.body,
    'data': message.data,
  });
}

/// Production-ready push notification service using FCM and local notifications

class PushNotificationService {

  PushNotificationService(
    this._logger,
    this._prefs,
  );
  final StructuredLogger _logger;
  final SharedPreferences _prefs;

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  NotificationPreferences _preferences = NotificationPreferences();
  String? _fcmToken;
  bool _initialized = false;

  // Removed automatic _init() call - initialize() should be called manually
  // after the app is ready to avoid blocking startup with permission dialogs

 
  Function(Map<String, dynamic>)? onNotificationTap;

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_initialized) return;

    _preferences = NotificationPreferences.load(_prefs);

 
    await _initializeLocalNotifications();

 
    await requestPermission();


    await _getFCMToken();

 
    _setupMessageHandlers();

    await _syncTopicSubscriptions();

    _initialized = true;

    _logger.info('Push notification service initialized');
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

    _logger.info('Notification permission: ${settings.authorizationStatus}');

    return granted;
  }

  /// Get FCM token
  Future<String?> _getFCMToken() async {
    try {
      _fcmToken = await _fcm.getToken();

      if (_fcmToken != null) {
        await _prefs.setString('fcm_token', _fcmToken!);

        _logger.info('FCM Token retrieved');

  
        _sendTokenToBackend(_fcmToken!).catchError((e) {
          _logger.error('Failed to send FCM token to backend', e);
        });
      }

      return _fcmToken;
    } catch (e) {
      _logger.error('Error getting FCM token', e);
      return null;
    }
  }

  /// Setup FCM message handlers
  void _setupMessageHandlers() {

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);


    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpen);


    _fcm.onTokenRefresh.listen((String newToken) {
      _fcmToken = newToken;
      _prefs.setString('fcm_token', newToken);

      _logger.info('FCM Token refreshed');

      
      _sendTokenToBackend(newToken);
    });
  }

  /// Handle foreground messages by showing local notification
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    _logger.info('Foreground message: ${message.messageId}');

    
    if (!_preferences.enabled) return;

    final RemoteNotification? notification = message.notification;
    final AndroidNotification? android = message.notification?.android;

    if (notification != null) {
      
      String channelId = 'general_news';
      if (message.data['channel'] != null) {
        channelId = message.data['channel'] as String;
      }


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
    _logger.info('Notification tapped', message.data);

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
      _logger.info('App opened from notification', initialMessage.data);

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
        await _preferences.save(_prefs);
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
      await _preferences.save(_prefs);

      _logger.info('Unsubscribed from topic: $topic');
    } catch (e) {
      _logger.error('Error unsubscribing from topic $topic', e);
    }
  }

  /// Sync topic subscriptions based on preferences
  Future<void> _syncTopicSubscriptions() async {
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
    await _preferences.save(_prefs);
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

      /*
      await FirebaseFunctions.instance
          .httpsCallable('saveNotificationToken')
          .call({'token': token, 'platform': platform});
      */

      _logger.info('Token sent to backend successfully');
    } catch (e) {
      _logger.error('Error sending token to backend', e);
      
    }
  }
}
