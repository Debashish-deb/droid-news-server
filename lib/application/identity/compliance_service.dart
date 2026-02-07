// lib/application/identity/compliance_service.dart

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../domain/facades/auth_facade.dart';

// Service to handle GDPR compliance (Right to Access & Right to Erasure).
class ComplianceService {

  ComplianceService({required AuthFacade authService})
      : _authService = authService;
  final AuthFacade _authService;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> exportUserData() async {
    final user = _authService.currentUser;
    if (user == null) return '{}';

    final userId = user.uid;

    final profileDoc = await _firestore.collection('users').doc(userId).get();
    
    final settingsDoc = await _firestore.collection('users').doc(userId).collection('data').doc('settings').get();
    final favoritesDoc = await _firestore.collection('users').doc(userId).collection('data').doc('favorites').get();

    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> localPrefs = {};
    for (String key in prefs.getKeys()) {
       localPrefs[key] = prefs.get(key);
    }

    final Map<String, dynamic> export = {
      'user_id': userId,
      'profile': profileDoc.data(),
      'sync_settings': settingsDoc.data(),
      'sync_favorites': favoritesDoc.data(),
      'local_preferences': localPrefs,
      'export_date': DateTime.now().toIso8601String(),
    };

    return jsonEncode(export);
  }

  Future<void> requestDataDeletion() async {
    final user = _authService.currentUser;
    if (user == null) return;

    final userId = user.uid;

    await _firestore.collection('users').doc(userId).collection('data').doc('settings').delete();
    await _firestore.collection('users').doc(userId).collection('data').doc('favorites').delete();
    await _firestore.collection('users').doc(userId).delete();

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await Hive.deleteFromDisk();

    await user.delete();
    
    await _authService.logout();
  }
}
