import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Optimized Data Loader for static assets (newspapers, magazines).
/// Features:
/// 1. Singleton Cache (loads once).
/// 2. Background Parsing (compute).
class AssetsDataLoader {
  factory AssetsDataLoader() => _instance;
  AssetsDataLoader._internal();
  static final AssetsDataLoader _instance = AssetsDataLoader._internal();

  Map<String, dynamic>? _cache;
  Future<Map<String, dynamic>>? _loadingFuture;

  /// Returns the full data map from assets/data.json
  Future<Map<String, dynamic>> loadData() async {
    if (_cache != null) return _cache!;

    if (_loadingFuture != null) {
      return _loadingFuture!;
    }

    _loadingFuture = _loadInternal();
    final data = await _loadingFuture!;
    _loadingFuture = null;
    return data;
  }

  Future<Map<String, dynamic>> _loadInternal() async {
    try {
      final String jsonStr = await rootBundle.loadString('assets/data.json');
      // Offload parsing to background isolate to avoid UI jank
      final parsed = await compute(_parseJson, jsonStr);
      _cache = _sanitizePublisherLists(parsed);
      return _cache!;
    } catch (e) {
      debugPrint('❌ AssetsDataLoader failed: $e');
      return {};
    }
  }

  static Map<String, dynamic> _parseJson(String jsonStr) {
    return jsonDecode(jsonStr) as Map<String, dynamic>;
  }

  Map<String, dynamic> _sanitizePublisherLists(Map<String, dynamic> data) {
    final sanitized = Map<String, dynamic>.from(data);
    sanitized['newspapers'] = _dedupeById(
      data['newspapers'],
      listName: 'newspapers',
    );
    sanitized['magazines'] = _dedupeById(
      data['magazines'],
      listName: 'magazines',
    );
    return sanitized;
  }

  List<dynamic> _dedupeById(dynamic rawList, {required String listName}) {
    if (rawList is! List) return const [];

    final seen = <String>{};
    final deduped = <dynamic>[];
    var duplicateCount = 0;
    var missingIdCount = 0;

    for (final raw in rawList) {
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      final id = item['id']?.toString().trim() ?? '';

      if (id.isEmpty) {
        missingIdCount++;
        continue;
      }

      if (seen.add(id)) {
        deduped.add(item);
      } else {
        duplicateCount++;
      }
    }

    if (kDebugMode && (duplicateCount > 0 || missingIdCount > 0)) {
      debugPrint(
        '⚠️ AssetsDataLoader sanitized $listName: '
        'removed duplicates=$duplicateCount, missingId=$missingIdCount',
      );
    }

    return deduped;
  }

  List<dynamic> getNewspapers() => _cache?['newspapers'] ?? [];
  List<dynamic> getMagazines() => _cache?['magazines'] ?? [];
}
