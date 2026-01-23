import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';

/// Wrapper for Firebase Remote Config
class RemoteConfigService {
  factory RemoteConfigService() => _instance;
  RemoteConfigService._internal();
  static final RemoteConfigService _instance = RemoteConfigService._internal();

  final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;
  bool _initialized = false;

  /// Initialize Remote Config with default values and fetch settings
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      await _remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(hours: 1), // 1 hour cache in prod
      ));

      // Set defaults
      await _remoteConfig.setDefaults(<String, dynamic>{
        'premium_whitelist': jsonEncode([]), // Empty list default
        'enable_special_offers': false,
        'welcome_message': 'Welcome to BD News Reader',
      });

      // Fetch and activate
      await fetchAndActivate();
      
      _initialized = true;
      if (kDebugMode) {
        debugPrint('🔥 Remote Config initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Remote Config init failed: $e');
      }
      // Don't rethrow, app should function with defaults
    }
  }

  /// Fetch latest config from cloud
  Future<bool> fetchAndActivate() async {
    try {
      return await _remoteConfig.fetchAndActivate();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Remote Config fetch failed: $e');
      }
      return false;
    }
  }

  // Type-safe getters
  
  String getString(String key) => _remoteConfig.getString(key);
  bool getBool(String key) => _remoteConfig.getBool(key);
  int getInt(String key) => _remoteConfig.getInt(key);
  double getDouble(String key) => _remoteConfig.getDouble(key);
  
  /// Parse JSON string to List/Map
  dynamic getJson(String key) {
    try {
      final String value = _remoteConfig.getString(key);
      if (value.isEmpty) return null;
      return jsonDecode(value);
    } catch (e) {
      return null;
    }
  }
}
