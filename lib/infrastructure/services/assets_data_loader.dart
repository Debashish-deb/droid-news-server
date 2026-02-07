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
  bool _isLoading = false;
  Future<void>? _loadingFuture;

  /// Returns the full data map from assets/data.json
  Future<Map<String, dynamic>> loadData() async {
    if (_cache != null) return _cache!;

    if (_isLoading) {
      return _loadingFuture as Future<Map<String, dynamic>>;
    }

    _isLoading = true;
    _loadingFuture = _loadInternal();
    return await _loadingFuture as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _loadInternal() async {
    try {
      final String jsonStr = await rootBundle.loadString('assets/data.json');
      // Offload parsing to background isolate to avoid UI jank
      _cache = await compute(_parseJson, jsonStr);
      _isLoading = false;
      return _cache!;
    } catch (e) {
      _isLoading = false;
      debugPrint('❌ AssetsDataLoader failed: $e');
      return {};
    }
  }

  static Map<String, dynamic> _parseJson(String jsonStr) {
    return jsonDecode(jsonStr) as Map<String, dynamic>;
  }

  List<dynamic> getNewspapers() => _cache?['newspapers'] ?? [];
  List<dynamic> getMagazines() => _cache?['magazines'] ?? [];
}
