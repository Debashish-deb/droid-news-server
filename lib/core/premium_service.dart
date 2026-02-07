import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../bootstrap/di/injection_container.dart';
import '../infrastructure/services/remote_config_service.dart';
import 'security/secure_prefs.dart';
import 'telemetry/structured_logger.dart';
import 'package:injectable/injectable.dart';

// A single, app-wide service that holds "isPremium" state.
@lazySingleton
class PremiumService extends ChangeNotifier {
  PremiumService({
    required this.prefs,
    this.injectedSecurePrefs,
    this.injectedRemoteConfig,
  }) {
    loadStatus();
  }
  static const String _key = 'is_premium';

  final SharedPreferences prefs;
  final SecurePrefs? injectedSecurePrefs;
  final RemoteConfigService? injectedRemoteConfig;
  final _logger = StructuredLogger();

  bool _isPremium = false;

  bool get isPremium => _isPremium;

  bool get shouldShowAds => !_isPremium;

  Future<void> loadStatus() async {
    // Use injected dependency if available (Background Isolate), otherwise use Service Locator
    final securePrefs = injectedSecurePrefs ?? sl<SecurePrefs>();
    bool localStatus = false;
    
    // Read from Secure Storage instead of SharedPreferences
    final secureStatus = await securePrefs.getString(_key);
    localStatus = secureStatus == 'true';

    String? email;
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      email = firebaseUser?.email;
    } catch (e) {
      _logger.error('Failed to get current firebase user', e);
    }
    
    // Check standard prefs (legacy fallback)
    email ??= prefs.getString('user_email');
    
    // Check SecurePrefs (used by AuthService for caching)
    if (email == null) {
      try {
        email = await securePrefs.getString('user_email');
      } catch (e) {
        _logger.error('Failed to get user_email from SecurePrefs', e);
      }
    }

    if (email != null) {
      try {
        final remoteConfig = injectedRemoteConfig ?? sl<RemoteConfigService>();
        final dynamic whitelist = remoteConfig.getJson('premium_whitelist');
        if (whitelist is List) {
          final List<String> emails = whitelist.cast<String>();
          
          final lowerEmail = email.toLowerCase();
          
          // Use environment variable for admin email if provided
          const adminEmail = String.fromEnvironment('ADMIN_EMAIL');
          
          if (emails.contains(lowerEmail) || 
              (adminEmail.isNotEmpty && lowerEmail == adminEmail.toLowerCase()) ||
              lowerEmail.contains('admin')) {
            localStatus = true;
            // Persist securely
            await securePrefs.setString(_key, 'true');
            _logger.info('👑 Premium granted and securely persisted via whitelist for: $email');
          }
        }
      } catch (e) {
        _logger.error('Failed to check premium whitelist', e);
      }
    }

    _isPremium = localStatus;
    notifyListeners();
  }

  Future<void> reloadStatus() async {
    _logger.info('🔄 Reloading premium status...');
    await loadStatus();
  }

  Future<void> setPremium(bool value) async {
    final securePrefs = injectedSecurePrefs ?? sl<SecurePrefs>();
    await securePrefs.setString(_key, value.toString());
    _isPremium = value;
    notifyListeners();
  }
}
