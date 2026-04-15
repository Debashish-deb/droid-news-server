import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/security/secure_prefs.dart';
import '../../../core/telemetry/structured_logger.dart';
import '../../../tools/firebase_options.dart';
import '../../persistence/notifications/notification_dedup_store.dart';
import '../../persistence/notifications/notification_preferences.dart';

abstract class NotificationPreferenceSync {
  Future<void> setNotificationsEnabled(bool enabled);
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    if (Firebase.apps.isEmpty) {
      await DefaultFirebaseOptions.initializeApp();
    }
  } catch (_) {
    // Background delivery should never crash the isolate because Firebase
    // was already initialized or unavailable in the current environment.
  }

  if (kDebugMode) {
    final logger = StructuredLogger();
    logger.info('Background message received', {
      'id': message.messageId,
      'title': message.notification?.title,
      'body': message.notification?.body,
      'data': message.data,
    });
  }
}

class PushNotificationService implements NotificationPreferenceSync {
  PushNotificationService(this._logger, this._prefs, this._securePrefs)
    : _dedupStore = _prefs != null ? NotificationDedupStore(_prefs) : null;

  static bool _backgroundHandlerRegistered = false;
  static bool _registerTokenFunctionMissingLogged = false;
  static bool _registerTokenBackendSyncUnavailable = false;
  static bool _sessionStoreTokenSyncUnavailable = false;
  static bool _sessionStoreTokenSyncUnavailableLogged = false;
  static const bool _enableBackendTokenSyncInNonRelease = bool.fromEnvironment(
    'ENABLE_PUSH_TOKEN_BACKEND_SYNC_IN_NON_RELEASE',
  );
  static const MethodChannel _securityChannel = MethodChannel(
    'com.bdnews/security',
  );

  static void registerBackgroundHandler() {
    if (_backgroundHandlerRegistered) {
      return;
    }
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    _backgroundHandlerRegistered = true;
  }

  final StructuredLogger _logger;
  final SharedPreferences? _prefs;
  final SecurePrefs _securePrefs;
  final NotificationDedupStore? _dedupStore;

  FirebaseMessaging get _fcm => FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  NotificationPreferences _preferences = NotificationPreferences();
  String? _fcmToken;
  bool _initialized = false;
  bool _remotePipelineInitialized = false;
  bool _remoteRegistrationCompleted = false;
  bool _handlersRegistered = false;
  StreamSubscription<User?>? _authStateSubscription;
  Future<Map<String, dynamic>?>? _initialMessageLoadFuture;
  Future<void>? _pendingRemoteRegistration;
  bool _initialMessageConsumed = false;

  Function(Map<String, dynamic>)? onNotificationTap;

  Future<void> initialize({bool deferRemoteRegistration = false}) async {
    if (!_initialized) {
      await _loadPreferences();

      await _initializeLocalNotifications();

      _initialized = true;
      _logger.info('Push notification local stage initialized');
    }

    if (_preferences.enabled) {
      if (!deferRemoteRegistration) {
        await completeDeferredRegistration();
      }
      return;
    }

    _remoteRegistrationCompleted = false;
  }

  Future<void> completeDeferredRegistration({
    bool requestSystemPermission = true,
  }) async {
    if (!_initialized ||
        !_preferences.enabled ||
        _remoteRegistrationCompleted) {
      return;
    }

    final pending = _pendingRemoteRegistration;
    if (pending != null) {
      await pending;
      return;
    }

    final future = () async {
      await _initializeRemotePipelineIfNeeded();
      final enabled = await _enableNotificationsInternally(
        requestSystemPermission: requestSystemPermission,
      );
      _remoteRegistrationCompleted = enabled;
    }();
    _pendingRemoteRegistration = future;

    try {
      await future;
    } finally {
      if (identical(_pendingRemoteRegistration, future)) {
        _pendingRemoteRegistration = null;
      }
    }
  }

  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    if (!kIsWeb) {
      await _createNotificationChannels();
    }
  }

  Future<void> _configureForegroundPresentation() async {
    if (kIsWeb) {
      return;
    }

    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> _createNotificationChannels() async {
    const generalChannel = AndroidNotificationChannel(
      'general_news',
      'General News',
      description: 'Breaking news and general updates',
      importance: Importance.high,
    );
    const personalizedChannel = AndroidNotificationChannel(
      'personalized',
      'Personalized Alerts',
      description: 'Notifications based on your preferences',
      importance: Importance.high,
    );
    const promotionalChannel = AndroidNotificationChannel(
      'promotional',
      'Promotional',
      description: 'Special offers and promotions',
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidPlugin?.createNotificationChannel(generalChannel);
    await androidPlugin?.createNotificationChannel(personalizedChannel);
    await androidPlugin?.createNotificationChannel(promotionalChannel);
  }

  Future<void> _initializeRemotePipelineIfNeeded() async {
    if (_remotePipelineInitialized) {
      return;
    }

    registerBackgroundHandler();
    await _configureForegroundPresentation();
    _setupMessageHandlers();
    _listenForAuthChanges();

    _remotePipelineInitialized = true;
    _logger.info('Push notification remote stage initialized');
  }

  Future<bool> requestPermission() async {
    final settings = await _fcm.requestPermission();
    final granted =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;

    _logger.info('Notification permission', {
      'status': settings.authorizationStatus.name,
      'granted': granted,
    });
    return granted;
  }

  void _setupMessageHandlers() {
    if (_handlersRegistered) {
      return;
    }
    _handlersRegistered = true;

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpen);
    _fcm.onTokenRefresh.listen((newToken) {
      unawaited(_storeFreshToken(newToken));
    });
  }

  void _listenForAuthChanges() {
    _authStateSubscription ??= FirebaseAuth.instance.authStateChanges().listen((
      user,
    ) {
      if (user == null || _fcmToken == null || _fcmToken!.isEmpty) {
        return;
      }
      unawaited(_persistTokenForCurrentDevice(_fcmToken!));
    });
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    _logger.info('Foreground message received', {'id': message.messageId});

    if (!_preferences.enabled) {
      return;
    }

    final notification = message.notification;
    final android = message.notification?.android;
    if (notification == null) {
      return;
    }

    // ── Deduplication: skip if this article was already notified ─────────
    final articleKey = _extractArticleKey(message.data);
    if (articleKey != null && _dedupStore != null) {
      if (!_dedupStore.shouldShow(articleKey)) {
        _logger.info('Skipping duplicate notification', {
          'articleKey': articleKey,
        });
        return;
      }
    }

    final payload = _payloadForMessage(message);
    final channelId = message.data['channel'] as String? ?? 'general_news';

    // Use a stable notification ID based on article key so the same article
    // always overwrites its previous notification instead of stacking.
    final notifId = articleKey?.hashCode ?? notification.hashCode;

    await _localNotifications.show(
      id: notifId,
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
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
      payload: jsonEncode(payload),
    );

    // Mark as shown so future pushes for the same article are suppressed.
    if (articleKey != null && _dedupStore != null) {
      await _dedupStore.markShown(articleKey);
    }
  }

  /// Extracts a stable article identifier from the FCM data payload.
  String? _extractArticleKey(Map<String, dynamic> data) {
    final articleId = data['article_id'] as String?;
    if (articleId != null && articleId.isNotEmpty) return articleId;

    final articleUrl = data['article_url'] as String?;
    if (articleUrl != null && articleUrl.isNotEmpty) return articleUrl;

    final url = data['url'] as String?;
    if (url != null && url.isNotEmpty) return url;

    return null;
  }

  Future<void> _handleNotificationOpen(RemoteMessage message) async {
    _logger.info('Notification tapped', {'id': message.messageId});
    final payload = _payloadForMessage(message);
    if (onNotificationTap != null) {
      onNotificationTap!(payload);
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    if (response.payload == null || onNotificationTap == null) {
      return;
    }
    final data = jsonDecode(response.payload!) as Map<String, dynamic>;
    onNotificationTap!(data);
  }

  Future<Map<String, dynamic>?> consumeInitialMessagePayload() async {
    if (_initialMessageConsumed) {
      return null;
    }

    final payload = await _loadInitialMessagePayload();
    if (payload == null) {
      return null;
    }

    _initialMessageConsumed = true;
    return Map<String, dynamic>.from(payload);
  }

  Future<void> checkInitialMessage() async {
    if (!_preferences.enabled) {
      return;
    }

    final payload = await consumeInitialMessagePayload();
    if (payload == null) {
      return;
    }

    if (onNotificationTap != null) {
      onNotificationTap!(payload);
    }
  }

  Future<Map<String, dynamic>?> _loadInitialMessagePayload() {
    final existing = _initialMessageLoadFuture;
    if (existing != null) {
      return existing;
    }

    final future = () async {
      final initialMessage = await _fcm.getInitialMessage();
      if (initialMessage == null) {
        return null;
      }

      final payload = _payloadForMessage(initialMessage);
      _logger.info('App opened from notification', payload);
      return payload;
    }();

    _initialMessageLoadFuture = future;
    return future;
  }

  Future<void> subscribeToTopic(String topic) async {
    try {
      await _fcm.subscribeToTopic(topic);
      if (!_preferences.subscribedTopics.contains(topic)) {
        _preferences.subscribedTopics = <String>[
          ..._preferences.subscribedTopics,
          topic,
        ];
      }
      await _preferences.save(_prefs);
      _logger.info('Subscribed to topic', {'topic': topic});
    } catch (e, stack) {
      _logger.error('Error subscribing to topic $topic', e, stack);
    }
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _fcm.unsubscribeFromTopic(topic);
      _preferences.subscribedTopics.remove(topic);
      await _preferences.save(_prefs);
      _logger.info('Unsubscribed from topic', {'topic': topic});
    } catch (e, stack) {
      _logger.error('Error unsubscribing from topic $topic', e, stack);
    }
  }

  Future<void> _unsubscribeFromAllTopics() async {
    for (final topic in <String>{
      'breaking_news',
      'personalized',
      'promotional',
      ..._preferences.subscribedTopics,
    }) {
      await unsubscribeFromTopic(topic);
    }
  }

  Future<void> _syncTopicSubscriptions() async {
    if (!_preferences.enabled) {
      await _unsubscribeFromAllTopics();
      return;
    }

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

  Future<void> updatePreferences(NotificationPreferences newPreferences) async {
    _preferences = newPreferences;
    if (_prefs != null) {
      await _preferences.save(_prefs);
      await _prefs.setBool('push_notif', _preferences.enabled);
    }

    if (_preferences.enabled) {
      _remoteRegistrationCompleted = false;
      await completeDeferredRegistration(requestSystemPermission: false);
    } else {
      await _disableNotificationsInternally(deleteToken: true);
    }
  }

  @override
  Future<void> setNotificationsEnabled(bool enabled) async {
    await _loadPreferences();
    _preferences.enabled = enabled;
    if (_prefs != null) {
      await _preferences.save(_prefs);
      await _prefs.setBool('push_notif', enabled);
    }

    if (enabled) {
      _remoteRegistrationCompleted = false;
      await completeDeferredRegistration();
    } else {
      await _disableNotificationsInternally(deleteToken: true);
    }
  }

  Future<bool> _enableNotificationsInternally({
    required bool requestSystemPermission,
  }) async {
    await _fcm.setAutoInitEnabled(true);

    if (requestSystemPermission) {
      final granted = await requestPermission();
      if (!granted) {
        _logger.warn('Notification permission not granted');
        return false;
      }
    }

    await _getFCMToken();
    await _syncTopicSubscriptions();
    return true;
  }

  Future<void> _disableNotificationsInternally({
    required bool deleteToken,
  }) async {
    await _unsubscribeFromAllTopics();
    await _fcm.setAutoInitEnabled(false);

    if (deleteToken) {
      try {
        await _fcm.deleteToken();
        _logger.info('FCM token deleted after opt-out');
      } catch (e, stack) {
        _logger.error('Failed to delete FCM token during opt-out', e, stack);
      }
    }

    _fcmToken = null;
    _remoteRegistrationCompleted = false;
    if (_prefs != null) {
      await _prefs.remove('fcm_token');
    }
  }

  Future<String?> _getFCMToken() async {
    try {
      await _waitForApplePushRegistration();
      final token = await _fcm.getToken();
      if (token == null || token.isEmpty) {
        return null;
      }
      await _storeFreshToken(token);
      return token;
    } catch (e, stack) {
      _logger.error('Error getting FCM token', e, stack);
      return null;
    }
  }

  Future<void> _storeFreshToken(String token) async {
    _fcmToken = token;
    if (_prefs != null) {
      await _prefs.setString('fcm_token', token);
    }
    _logger.info('FCM token available');
    await _persistTokenForCurrentDevice(token);
    await _sendTokenToBackend(token);
  }

  Future<void> _persistTokenForCurrentDevice(String token) async {
    if (_sessionStoreTokenSyncUnavailable) {
      return;
    }
    try {
      if (Firebase.apps.isEmpty) {
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return;
      }

      final deviceId = await _securePrefs.getRegisteredDeviceId();
      if (deviceId == null || deviceId.isEmpty) {
        return;
      }

      await FirebaseFirestore.instance
          .collection('user_sessions')
          .doc(user.uid)
          .collection('devices')
          .doc(deviceId)
          .set(<String, dynamic>{
            'fcmToken': token,
            'lastActive': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied' || e.code == 'failed-precondition') {
        _sessionStoreTokenSyncUnavailable = true;
        if (!_sessionStoreTokenSyncUnavailableLogged) {
          _sessionStoreTokenSyncUnavailableLogged = true;
          _logger.warn('FCM token session-store persistence unavailable', {
            'code': e.code,
          });
        }
        return;
      }
      _logger.error('Failed to persist FCM token to session store', e);
    } catch (e, stack) {
      _logger.error('Failed to persist FCM token to session store', e, stack);
    }
  }

  Future<void> _waitForApplePushRegistration() async {
    if (kIsWeb || !(Platform.isIOS || Platform.isMacOS)) {
      return;
    }

    for (var attempt = 0; attempt < 8; attempt++) {
      final apnsToken = await _fcm.getAPNSToken();
      if (apnsToken != null && apnsToken.isNotEmpty) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }

    _logger.warn('APNs token not yet available; FCM token may be delayed');
  }

  Map<String, dynamic> _payloadForMessage(RemoteMessage message) {
    final title = message.notification?.title;
    final body = message.notification?.body;
    return <String, dynamic>{
      ...message.data,
      if (title != null &&
          (message.data['title'] == null || message.data['title'] == ''))
        'title': title,
      if (body != null &&
          (message.data['body'] == null || message.data['body'] == ''))
        'body': body,
    };
  }

  NotificationPreferences get preferences => _preferences;
  String? get token => _fcmToken;
  bool get isEnabled => _preferences.enabled;

  static Future<void> openNotificationSettings() async {
    try {
      await _securityChannel.invokeMethod<bool>('openNotificationSettings');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to open system notification settings: $e');
      }
    }
  }

  /// Show a local notification - useful for background tasks.
  ///
  /// [notificationId] Optional stable ID.  If provided, repeated calls with
  /// the same ID *replace* the existing notification instead of stacking.
  /// Defaults to a hash of title+body if not specified.
  Future<void> showLocalNotification({
    required String title,
    required String body,
    String channelId = 'general_news',
    Map<String, dynamic>? payload,
    int? notificationId,
  }) async {
    final details = NotificationDetails(
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
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _localNotifications.show(
      id: notificationId ?? (title.hashCode ^ body.hashCode),
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload != null ? jsonEncode(payload) : null,
    );
  }

  Future<void> _sendTokenToBackend(String token) async {
    if (!kReleaseMode && !_enableBackendTokenSyncInNonRelease) {
      return;
    }

    if (_registerTokenBackendSyncUnavailable) {
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return;
      }

      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('register_fcm_token');

      await callable.call(<String, dynamic>{
        'token': token,
        'platform': kIsWeb ? 'web' : (Platform.isIOS ? 'ios' : 'android'),
      });

      _logger.info('FCM token synced to backend via Cloud Function', {
        'has_user': true,
        'token_length': token.length,
      });
    } on FirebaseFunctionsException catch (e) {
      // Gracefully ignore missing Cloud Function (NOT_FOUND) or permissions.
      // Avoid flooding startup logs when backend token sync is intentionally
      // not deployed in a given environment.
      if (e.code == 'not-found') {
        _registerTokenBackendSyncUnavailable = true;
        if (!_registerTokenFunctionMissingLogged) {
          _registerTokenFunctionMissingLogged = true;
          _logger.info('FCM token backend sync unavailable for this session', {
            'code': e.code,
            'message': e.message,
            'details': e.details,
          });
        }
        return;
      }

      if (e.code == 'permission-denied' || e.code == 'failed-precondition') {
        _registerTokenBackendSyncUnavailable = true;
      }

      if (!_registerTokenBackendSyncUnavailable ||
          !_registerTokenFunctionMissingLogged) {
        _registerTokenFunctionMissingLogged = true;
        _logger.warn('FCM token Cloud Function unavailable', {
          'code': e.code,
          'message': e.message,
          'details': e.details,
        });
      }
    } catch (e, stack) {
      _logger.error('Error syncing FCM token to backend', e, stack);
    }
  }

  Future<void> _loadPreferences() async {
    _preferences = NotificationPreferences.load(_prefs);
    final appToggle = _prefs?.getBool('push_notif');
    if (appToggle != null && appToggle != _preferences.enabled) {
      _preferences.enabled = appToggle;
      if (_prefs != null) {
        await _preferences.save(_prefs);
      }
    }
  }

  Future<void> dispose() async {
    await _authStateSubscription?.cancel();
    _authStateSubscription = null;
  }
}
