import 'dart:convert' show jsonDecode, jsonEncode;

import '../../core/telemetry/structured_logger.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart' show FirebaseRemoteConfig, RemoteConfigSettings;
import 'package:injectable/injectable.dart';

// Wrapper for Firebase Remote Config
@lazySingleton
class RemoteConfigService {
  factory RemoteConfigService() => _instance;
  RemoteConfigService._internal();
  static final RemoteConfigService _instance = RemoteConfigService._internal();

  final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;
  final _logger = StructuredLogger();
  bool _initialized = false;

  Future<bool> fetchAndActivate() async {
    try {
      return await _remoteConfig.fetchAndActivate();
    } catch (e) {
      _logger.error('Remote Config fetch failed', e);
      return false;
    }
  }

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      await _remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(hours: 1), 
      ));

  
      await _remoteConfig.setDefaults(<String, dynamic>{
        'premium_whitelist': jsonEncode([
          'admin@bdnewsreader.com',
          'support@bdnewsreader.com',
        ]), 
        'enable_special_offers': false,
        'welcome_message': 'Welcome to BD News Reader',
      });


      await fetchAndActivate();
      
      _initialized = true;
      _logger.info('🔥 Remote Config initialized');
    } catch (e) {
      _logger.error('Remote Config init failed', e);
    }
  }

  
  String getString(String key) => _remoteConfig.getString(key);
  bool getBool(String key) => _remoteConfig.getBool(key);
  int getInt(String key) => _remoteConfig.getInt(key);
  double getDouble(String key) => _remoteConfig.getDouble(key);
  
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
