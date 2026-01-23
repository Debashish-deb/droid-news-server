// lib/core/sync/sync_delta.dart
// ================================
// SYNC DELTA COMPUTATION
// Extracted from sync_service.dart
// ================================

import 'dart:convert';
import 'sync_utils.dart';

/// Handles delta computation for sync operations
class SyncDelta {
  SyncDelta._();

  /// Compute the delta between two favorites states
  static Map<String, dynamic> computeFavoritesDelta({
    required Map<String, dynamic> previous,
    required Map<String, dynamic> current,
    required int nowMs,
  }) {
    final delta = <String, dynamic>{
      'schemaVersion': 2,
      'clientUpdatedAtMs': nowMs,
      'upserts': <String, dynamic>{
        'articles': <String, dynamic>{},
        'magazines': <String, dynamic>{},
        'newspapers': <String, dynamic>{},
      },
      'deletes': <String, dynamic>{
        'articles': <String, dynamic>{},
        'magazines': <String, dynamic>{},
        'newspapers': <String, dynamic>{},
      },
    };

    // Compare each entity type
    for (final entity in ['articles', 'magazines', 'newspapers']) {
      _diffMaps(
        (previous[entity] as Map<String, dynamic>?) ?? {},
        (current[entity] as Map<String, dynamic>?) ?? {},
        entity,
        delta,
        nowMs,
      );
    }

    return delta;
  }

  static void _diffMaps(
    Map<String, dynamic> prev,
    Map<String, dynamic> cur,
    String entity,
    Map<String, dynamic> delta,
    int nowMs,
  ) {
    final upserts = delta['upserts'] as Map<String, dynamic>;
    final deletes = delta['deletes'] as Map<String, dynamic>;

    // Find new/updated items
    for (final key in cur.keys) {
      if (!prev.containsKey(key) || 
          !SyncUtils.deepEqualsJson(prev[key], cur[key])) {
        (upserts[entity] as Map<String, dynamic>)[key] = cur[key];
      }
    }

    // Find deleted items
    for (final key in prev.keys) {
      if (!cur.containsKey(key)) {
        (deletes[entity] as Map<String, dynamic>)[key] = nowMs;
      }
    }
  }

  /// Merge two deltas together
  static Map<String, dynamic> mergeDeltas(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
  ) {
    final merged = <String, dynamic>{
      'schemaVersion': 2,
      'clientUpdatedAtMs': (b['clientUpdatedAtMs'] as int?) ?? 
                           (a['clientUpdatedAtMs'] as int?) ?? 
                           DateTime.now().millisecondsSinceEpoch,
      'upserts': <String, dynamic>{
        'articles': <String, dynamic>{},
        'magazines': <String, dynamic>{},
        'newspapers': <String, dynamic>{},
      },
      'deletes': <String, dynamic>{
        'articles': <String, dynamic>{},
        'magazines': <String, dynamic>{},
        'newspapers': <String, dynamic>{},
      },
    };

    // Merge each entity type
    for (final entity in ['articles', 'magazines', 'newspapers']) {
      _mergeEntity(entity, a, b, merged);
    }

    return merged;
  }

  static void _mergeEntity(
    String entity,
    Map<String, dynamic> a,
    Map<String, dynamic> b,
    Map<String, dynamic> merged,
  ) {
    final aUpserts = (a['upserts'] as Map<String, dynamic>?)?[entity] as Map<String, dynamic>? ?? {};
    final bUpserts = (b['upserts'] as Map<String, dynamic>?)?[entity] as Map<String, dynamic>? ?? {};
    final aDeletes = (a['deletes'] as Map<String, dynamic>?)?[entity] as Map<String, dynamic>? ?? {};
    final bDeletes = (b['deletes'] as Map<String, dynamic>?)?[entity] as Map<String, dynamic>? ?? {};

    final mergedUpserts = merged['upserts'] as Map<String, dynamic>;
    final mergedDeletes = merged['deletes'] as Map<String, dynamic>;

    // Combine upserts (b takes priority)
    (mergedUpserts[entity] as Map<String, dynamic>).addAll(aUpserts);
    (mergedUpserts[entity] as Map<String, dynamic>).addAll(bUpserts);

    // Combine deletes (b takes priority)
    (mergedDeletes[entity] as Map<String, dynamic>).addAll(aDeletes);
    (mergedDeletes[entity] as Map<String, dynamic>).addAll(bDeletes);
  }
}
