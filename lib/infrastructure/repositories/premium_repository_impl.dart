// lib/infrastructure/repositories/premium_repository_impl.dart
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/repositories/premium_repository.dart';
import '../../core/security/secure_prefs.dart';
import '../../core/telemetry/structured_logger.dart';
import '../services/remote_config_service.dart';

class PremiumRepositoryImpl implements PremiumRepository {
  PremiumRepositoryImpl(
    this._securePrefs,
    this._firestore,
    this._remoteConfigService,
    this._logger,
  ) {
    // Initialize stream with a default value
    _statusController.add(false);
  }

  final SecurePrefs _securePrefs;
  final FirebaseFirestore _firestore;
  final RemoteConfigService _remoteConfigService;
  final StructuredLogger _logger;
  
  static const String _kPremiumKey = 'is_premium';
  
  final _statusController = StreamController<bool>.broadcast();
  bool _lastKnownStatus = false;

  @override
  Stream<bool> get premiumStatusStream => _statusController.stream;

  @override
  bool get isPremium => _lastKnownStatus;

  @override
  bool get shouldShowAds => !_lastKnownStatus;

  @override
  Future<void> refreshStatus() async {
    bool status = false;
    
    // 1. Check Secure Storage for persisted status (offline fallback)
    final secureStatus = await _securePrefs.getString(_kPremiumKey);
    status = secureStatus == 'true';

    // 2. Resolve Current User
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        // Fetch premium status from Firestore
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data();
          final isPremium = data?[_kPremiumKey] == true;
          
          if (isPremium) {
            status = true;
            // Persist status for offline access
            await _securePrefs.setString(_kPremiumKey, 'true');
            _logger.info('👑 Premium granted via Firestore for: ${user.email}');
          } else {
            status = false;
            await _securePrefs.setString(_kPremiumKey, 'false');
          }
        }
      } catch (e) {
        _logger.error('Failed to fetch premium status from Firestore', e);
      }
    }

    _lastKnownStatus = status;
    _statusController.add(status);
  }

  @override
  Future<void> setPremium(bool value) async {
    await _securePrefs.setString(_kPremiumKey, value.toString());
    _lastKnownStatus = value;
    _statusController.add(value);
  }
}
