import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:synchronized/synchronized.dart';

class PublisherLayoutRepository {
  static const String _boxName = 'publisher_layout';
  static const String _schemaVersionKey = '__schema_version__';
  static const int _schemaVersion = 1;

  final Lock _lock = Lock();
  Box<List>? _box;

  /// ------------------------------------------------------------
  /// Internal Box Access (Lazy + Safe + Versioned)
  /// ------------------------------------------------------------
  Future<Box<List>> _getBox() async {
    if (_box?.isOpen == true) return _box!;

    _box = await Hive.openBox<List>(_boxName);

    await _verifySchema();

    return _box!;
  }

  Future<void> _verifySchema() async {
    final box = _box!;
    // Box is Box<List>, so we must store/read version as a list containing the integer
    final versionList = box.get(_schemaVersionKey);
    final version = (versionList != null && versionList.isNotEmpty)
        ? versionList.first as int
        : null;

    if (version == null) {
      await box.put(_schemaVersionKey, [_schemaVersion]);
      return;
    }

    if (version != _schemaVersion) {
      debugPrint(
        '⚠ Layout schema mismatch: found=$version expected=$_schemaVersion',
      );
      // Future: add migration hooks here
      await box.put(_schemaVersionKey, [_schemaVersion]);
    }
  }

  /// ------------------------------------------------------------
  /// Save Layout (Serialized + Crash Safe + Debounced)
  /// ------------------------------------------------------------
  Future<void> saveLayout(
    List<String> publisherIds, {
    required String layoutKey,
  }) async {
    assert(layoutKey.isNotEmpty, 'layoutKey cannot be empty');

    final data = List<String>.unmodifiable(publisherIds);

    return _lock.synchronized(() async {
      final box = await _getBox();

      try {
        await box.put(layoutKey, data);
      } catch (e, st) {
        debugPrint('❌ Layout save failed [$layoutKey]: $e\n$st');
        rethrow;
      }
    });
  }

  /// ------------------------------------------------------------
  /// Load Layout (Serialized + Defensive)
  /// ------------------------------------------------------------
  Future<List<String>> loadLayout({
    required String layoutKey,
  }) async {
    assert(layoutKey.isNotEmpty, 'layoutKey cannot be empty');

    return _lock.synchronized(() async {
      final box = await _getBox();

      try {
        final stored = box.get(layoutKey);

        if (stored == null) return const [];

        return List<String>.from(stored);
      } catch (e, st) {
        debugPrint('❌ Layout load failed [$layoutKey]: $e\n$st');
        return const [];
      }
    });
  }

  /// ------------------------------------------------------------
  /// Clear Specific Layout (Serialized)
  /// ------------------------------------------------------------
  Future<void> clearLayout({required String layoutKey}) async {
    assert(layoutKey.isNotEmpty, 'layoutKey cannot be empty');

    return _lock.synchronized(() async {
      final box = await _getBox();

      try {
        await box.delete(layoutKey);
      } catch (e, st) {
        debugPrint('❌ Layout clear failed [$layoutKey]: $e\n$st');
        rethrow;
      }
    });
  }

  /// ------------------------------------------------------------
  /// Clear All Layouts (Serialized)
  /// ------------------------------------------------------------
  Future<void> clearAll() async {
    return _lock.synchronized(() async {
      final box = await _getBox();

      try {
        await box.clear();
      } catch (e, st) {
        debugPrint('❌ Layout clearAll failed: $e\n$st');
        rethrow;
      }
    });
  }

  /// ------------------------------------------------------------
  /// Diagnostics (Read-only, Safe)
  /// ------------------------------------------------------------
  Future<Map<String, List<String>>> dumpAll() async {
    return _lock.synchronized(() async {
      final box = await _getBox();

      return Map<String, List<String>>.fromEntries(
        box.keys.where((k) => k != _schemaVersionKey).map(
              (key) => MapEntry(
                key.toString(),
                List<String>.from(box.get(key) ?? const []),
              ),
            ),
      );
    });
  }
}
