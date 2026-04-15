import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:synchronized/synchronized.dart';

/// Persistence layer for publisher ordering layouts.
///
/// Design principles:
/// - **Lazy open**: box is opened on first use, not at construction.
/// - **Lock-serialised**: all Hive operations run inside a [Lock] to prevent
///   concurrent write corruption.
/// - **Debounced saves**: rapid successive [saveLayout] calls are coalesced
///   into a single write after [saveDebounceMs] of silence.
/// - **Migration hooks**: [_migrations] map lets future schema upgrades run
///   specific code paths without a full wipe.
/// - **Disposable**: call [dispose] when the repository is no longer needed
///   so the Hive box is properly closed and streams are cleaned up.
/// - **Reactive**: [watchLayout] emits the latest list whenever the stored
///   value changes, useful for cross-tab synchronisation.
class PublisherLayoutRepository {
  PublisherLayoutRepository({int saveDebounceMs = 400})
    : _saveDebounceMs = saveDebounceMs;

  // ── Constants ──────────────────────────────────────────────────────────────

  static const String _boxName = 'publisher_layout';
  static const String _schemaVersionKey = '__schema_version__';
  static const int _currentSchema = 2;

  // ── Internal state ─────────────────────────────────────────────────────────

  final int _saveDebounceMs;
  final Lock _lock = Lock();
  Box<List>? _box;
  bool _disposed = false;
  bool _storageDisabled = false;
  static bool _hiveRecoveryCompleted = false;

  /// Pending debounced writes keyed by layoutKey.
  final Map<String, Timer> _debounceTimers = {};
  final Map<String, List<String>> _pendingWrites = {};

  // ── Box lifecycle ──────────────────────────────────────────────────────────

  Future<Box<List>?> _getBox() async {
    _assertNotDisposed();
    if (_storageDisabled) return null;
    if (_box?.isOpen == true) return _box!;

    try {
      _box = await Hive.openBox<List>(_boxName);
    } on HiveError catch (error, stackTrace) {
      final message = error.toString();
      final needsInitialization =
          message.contains('initialize Hive') ||
          message.contains('initialize Hive or provide a path');
      if (!needsInitialization || _hiveRecoveryCompleted) {
        _disableStorage(
          error,
          stackTrace,
          context: 'open failed for $_boxName',
        );
        return null;
      }

      debugPrint(
        '[PublisherLayoutRepository] Hive was not initialized; attempting '
        'lazy recovery before opening $_boxName.',
      );
      try {
        await Hive.initFlutter();
        _box = await Hive.openBox<List>(_boxName);
        _hiveRecoveryCompleted = true;
      } catch (recoveryError, recoveryStack) {
        _disableStorage(
          recoveryError,
          recoveryStack,
          context: 'lazy recovery failed for $_boxName',
        );
        return null;
      }
    } catch (error, stackTrace) {
      _disableStorage(
        error,
        stackTrace,
        context: 'unexpected open failure for $_boxName',
      );
      return null;
    }

    final box = _box;
    if (box == null) return null;
    try {
      await _runMigrations(box);
    } catch (error, stackTrace) {
      debugPrint(
        '[PublisherLayoutRepository] migration failed for $_boxName: '
        '$error\n$stackTrace',
      );
    }
    return box;
  }

  void _disableStorage(
    Object error,
    StackTrace stackTrace, {
    required String context,
  }) {
    if (_storageDisabled) return;
    _storageDisabled = true;
    debugPrint(
      '[PublisherLayoutRepository] $context. '
      'Falling back to in-memory defaults for this session: '
      '$error\n$stackTrace',
    );
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    // Flush any pending debounced writes before closing
    await _flushAllPending();

    for (final t in _debounceTimers.values) {
      t.cancel();
    }
    _debounceTimers.clear();

    if (_box?.isOpen == true) {
      await _box!.close();
    }
    _box = null;

    debugPrint('[PublisherLayoutRepository] disposed');
  }

  void _assertNotDisposed() {
    assert(!_disposed, 'PublisherLayoutRepository has been disposed');
  }

  // ── Schema migrations ──────────────────────────────────────────────────────
  //
  // Add an entry here for every schema bump.
  // Each function receives the open box and must be idempotent.

  static const Map<int, Future<void> Function(Box<List>)> _migrations = {
    // v1 → v2 example: no structural change needed, just version stamp.
    2: _migrateToV2,
  };

  static Future<void> _migrateToV2(Box<List> box) async {
    // Example: strip any null-containing lists left by an older bug.
    for (final key in box.keys) {
      if (key == _schemaVersionKey) continue;
      final raw = box.get(key);
      if (raw == null) continue;
      final cleaned = raw.whereType<String>().toList();
      if (cleaned.length != raw.length) {
        await box.put(key, cleaned);
        debugPrint('[PublisherLayoutRepository] migration v2: cleaned $key');
      }
    }
  }

  Future<void> _runMigrations(Box<List> box) async {
    final storedVersion = _readVersion(box);

    if (storedVersion == _currentSchema) return;

    if (kDebugMode) {
      debugPrint(
        '[PublisherLayoutRepository] schema $storedVersion → $_currentSchema',
      );
    }

    // Run every migration step above the stored version in order
    for (final entry in _migrations.entries) {
      if (entry.key > storedVersion) {
        try {
          await entry.value(box);
        } catch (e, st) {
          debugPrint(
            '[PublisherLayoutRepository] migration ${entry.key} '
            'failed: $e\n$st',
          );
          // Continue running remaining migrations
        }
      }
    }

    await box.put(_schemaVersionKey, [_currentSchema]);
  }

  int _readVersion(Box<List> box) {
    final raw = box.get(_schemaVersionKey);
    if (raw == null || raw.isEmpty) return 0;
    final v = raw.first;
    return v is int ? v : 0;
  }

  // ── Save (debounced) ───────────────────────────────────────────────────────

  /// Schedules a debounced write.
  ///
  /// The UI can call this on every drag step; the actual Hive write only
  /// happens once dragging has been idle for [_saveDebounceMs].
  Future<void> saveLayout(
    List<String> publisherIds, {
    required String layoutKey,
  }) async {
    assert(layoutKey.isNotEmpty, 'layoutKey cannot be empty');
    _assertNotDisposed();

    final data = List<String>.unmodifiable(publisherIds);

    // Update pending and (re-)arm the debounce timer
    _pendingWrites[layoutKey] = data;
    _debounceTimers[layoutKey]?.cancel();
    _debounceTimers[layoutKey] = Timer(
      Duration(milliseconds: _saveDebounceMs),
      () => _flushPending(layoutKey),
    );
  }

  /// Immediately writes any pending debounced data for [layoutKey].
  Future<void> flushPending(String layoutKey) => _flushPending(layoutKey);

  Future<void> _flushPending(String layoutKey) async {
    final data = _pendingWrites.remove(layoutKey);
    _debounceTimers.remove(layoutKey)?.cancel();

    if (data == null) return;

    return _lock.synchronized(() async {
      try {
        final box = await _getBox();
        if (box == null) return;
        await box.put(layoutKey, List<String>.from(data));
        if (kDebugMode) {
          debugPrint(
            '[PublisherLayoutRepository] saved $layoutKey '
            '(${data.length} items)',
          );
        }
      } catch (e, st) {
        debugPrint(
          '[PublisherLayoutRepository] save failed [$layoutKey]: $e\n$st',
        );
        rethrow;
      }
    });
  }

  Future<void> _flushAllPending() async {
    final keys = List<String>.from(_pendingWrites.keys);
    for (final key in keys) {
      await _flushPending(key);
    }
  }

  // ── Load ───────────────────────────────────────────────────────────────────

  Future<List<String>> loadLayout({required String layoutKey}) async {
    assert(layoutKey.isNotEmpty, 'layoutKey cannot be empty');
    _assertNotDisposed();

    // If there is pending (unsaved) data, return that immediately —
    // it is more recent than what's on disk.
    if (_pendingWrites.containsKey(layoutKey)) {
      return List<String>.from(_pendingWrites[layoutKey]!);
    }

    return _lock.synchronized(() async {
      try {
        final box = await _getBox();
        if (box == null) return const <String>[];
        final stored = box.get(layoutKey);
        if (stored == null) return const <String>[];
        return List<String>.from(stored.whereType<String>());
      } catch (e, st) {
        debugPrint(
          '[PublisherLayoutRepository] load failed [$layoutKey]: $e\n$st',
        );
        return const <String>[];
      }
    });
  }

  // ── Watch (reactive) ──────────────────────────────────────────────────────

  /// Returns a stream that emits the latest layout whenever it changes on disk.
  ///
  /// The first event is emitted immediately with the current value.
  Stream<List<String>> watchLayout({required String layoutKey}) async* {
    assert(layoutKey.isNotEmpty, 'layoutKey cannot be empty');
    _assertNotDisposed();

    // Emit current value immediately
    yield await loadLayout(layoutKey: layoutKey);

    Box<List>? box;
    try {
      box = await _getBox();
    } catch (e, st) {
      debugPrint(
        '[PublisherLayoutRepository] watch failed [$layoutKey]: $e\n$st',
      );
      return;
    }
    if (box == null) return;

    yield* box.watch(key: layoutKey).map((event) {
      if (event.deleted) return const <String>[];
      final raw = event.value;
      if (raw is! List) return const <String>[];
      return List<String>.from(raw.whereType<String>());
    });
  }

  // ── Delete ─────────────────────────────────────────────────────────────────

  Future<void> clearLayout({required String layoutKey}) async {
    assert(layoutKey.isNotEmpty, 'layoutKey cannot be empty');
    _assertNotDisposed();

    // Cancel any pending debounced write for this key
    _debounceTimers.remove(layoutKey)?.cancel();
    _pendingWrites.remove(layoutKey);

    return _lock.synchronized(() async {
      try {
        final box = await _getBox();
        if (box == null) return;
        await box.delete(layoutKey);
      } catch (e, st) {
        debugPrint(
          '[PublisherLayoutRepository] clear failed [$layoutKey]: $e\n$st',
        );
        rethrow;
      }
    });
  }

  Future<void> clearAll() async {
    _assertNotDisposed();

    // Discard all pending writes
    for (final t in _debounceTimers.values) {
      t.cancel();
    }
    _debounceTimers.clear();
    _pendingWrites.clear();

    return _lock.synchronized(() async {
      try {
        final box = await _getBox();
        if (box == null) return;
        await box.clear();
      } catch (e, st) {
        debugPrint('[PublisherLayoutRepository] clearAll failed: $e\n$st');
        rethrow;
      }
    });
  }

  // ── Diagnostics ───────────────────────────────────────────────────────────

  Future<bool> existsLayout({required String layoutKey}) async {
    assert(layoutKey.isNotEmpty, 'layoutKey cannot be empty');
    _assertNotDisposed();
    if (_pendingWrites.containsKey(layoutKey)) return true;

    return _lock.synchronized(() async {
      try {
        final box = await _getBox();
        if (box == null) return false;
        return box.containsKey(layoutKey);
      } catch (e, st) {
        debugPrint(
          '[PublisherLayoutRepository] exists failed [$layoutKey]: $e\n$st',
        );
        return false;
      }
    });
  }

  Future<Map<String, List<String>>> dumpAll() async {
    _assertNotDisposed();
    // Flush pending first so dump reflects latest state
    await _flushAllPending();

    return _lock.synchronized(() async {
      final box = await _getBox();
      if (box == null) return const <String, List<String>>{};
      return Map<String, List<String>>.fromEntries(
        box.keys
            .where((k) => k != _schemaVersionKey)
            .map(
              (key) => MapEntry(
                key.toString(),
                List<String>.from(
                  (box.get(key) ?? const []).whereType<String>(),
                ),
              ),
            ),
      );
    });
  }

  /// Schema version currently stored on disk (0 if unset).
  Future<int> get storedSchemaVersion async {
    _assertNotDisposed();
    return _lock.synchronized(() async {
      final box = await _getBox();
      if (box == null) return 0;
      return _readVersion(box);
    });
  }
}
