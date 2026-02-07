// lib/core/sync/sync_utils.dart
// ================================
// SYNC UTILITY FUNCTIONS
// Extracted from sync_service.dart for better organization
// ================================

import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';

/// Utility functions for sync operations
class SyncUtils {
  SyncUtils._();

  /// Generate a random 32-character ID
  static String generateId() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return List.generate(32, (_) => chars[random.nextInt(chars.length)]).join();
  }

  /// Deep compare two JSON values
  static bool deepEqualsJson(dynamic a, dynamic b) {
    return jsonEncode(a) == jsonEncode(b);
  }

  /// Check if a delta is empty (no changes)
  static bool isEmptyDelta(Map<String, dynamic> delta) {
    bool emptyEntity(Map? m) => m == null || m.isEmpty;

    final upserts = delta['upserts'] as Map<String, dynamic>? ?? {};
    final deletes = delta['deletes'] as Map<String, dynamic>? ?? {};

    return emptyEntity(upserts['articles']) &&
        emptyEntity(upserts['magazines']) &&
        emptyEntity(upserts['newspapers']) &&
        emptyEntity(deletes['articles']) &&
        emptyEntity(deletes['magazines']) &&
        emptyEntity(deletes['newspapers']);
  }

  /// Safely cast a value to List<Map>
  static List<Map<String, dynamic>> asListMap(dynamic v) {
    if (v == null) return [];
    if (v is List) {
      return v.whereType<Map<String, dynamic>>().toList();
    }
    return [];
  }

  /// Safely cast to int
  static int? asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return null;
  }

  /// Ensure a map is JSON-safe (remove undefined types)
  static Map<String, dynamic> jsonSafe(Map<String, dynamic> input) {
    return json.decode(json.encode(input)) as Map<String, dynamic>;
  }

  /// Log sync message (debug only)
  static void log(String msg) {
    if (kDebugMode) {
      debugPrint('[Sync] $msg');
    }
  }
}

/// Extension on Map for sync-related operations
extension SyncMapExtension on Map<String, dynamic> {
  /// Get a string key for an entity (url for articles, name for others)
  String? entityKey(String type) {
    switch (type) {
      case 'articles':
        return this['url'] as String?;
      case 'magazines':
        return this['name'] as String? ?? this['title'] as String?;
      case 'newspapers':
        return this['name'] as String?;
      default:
        return null;
    }
  }
}
