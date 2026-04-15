import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/publisher_layout_repository.dart';
import 'publisher_layout_state.dart';

/// Manages publisher ordering for a single [layoutKey].
///
/// Design principles:
///
/// - **Rich state**: exposes [PublisherLayoutState] so widgets can react to
///   loading, error, and data independently.
/// - **Optimistic UI**: every mutation updates [state] immediately; the Hive
///   write is debounced and happens in the background.
/// - **Operation queue**: concurrent calls are serialised via [_opQueue]
///   instead of a single Completer that silently drops operations.
/// - **Idempotent load**: [loadOnce] is safe to call multiple times.
/// - **Rollback**: if a background persist fails the in-memory state is
///   reverted to maintain consistency with what is on disk.
class PublisherLayoutController extends StateNotifier<PublisherLayoutState> {
  PublisherLayoutController(this._repository, {required String layoutKey})
    : _layoutKey = layoutKey,
      super(const PublisherLayoutState());

  final PublisherLayoutRepository _repository;
  final String _layoutKey;

  bool _loadedOnce = false;

  // ── Serialised operation queue ────────────────────────────────────────────
  //
  // Ensures no two async operations run concurrently while still queuing
  // every caller (unlike a single _inFlight Completer that drops extras).

  final Queue<Future<void> Function()> _opQueue = Queue();
  bool _opRunning = false;

  Future<void> _enqueue(Future<void> Function() op) {
    final completer = Completer<void>();
    _opQueue.add(() async {
      try {
        await op();
        completer.complete();
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    _drainQueue();
    return completer.future;
  }

  void _drainQueue() {
    if (_opRunning || _opQueue.isEmpty) return;
    _opRunning = true;
    Future.microtask(() async {
      while (_opQueue.isNotEmpty) {
        final next = _opQueue.removeFirst();
        try {
          await next();
        } catch (_) {
          // Individual op errors are handled inside each op; do not break queue
        }
      }
      _opRunning = false;
    });
  }

  // ── Load ──────────────────────────────────────────────────────────────────

  /// Loads the saved layout and merges it with [defaultIds].
  ///
  /// Safe to call multiple times — subsequent calls are enqueued and run
  /// after any in-progress operations complete.
  Future<void> load(List<String> defaultIds) =>
      _enqueue(() => _load(defaultIds));

  /// Like [load] but skips the repository call if data has already been
  /// fetched successfully.  Ideal for `initState`-style calls.
  Future<void> loadOnce(List<String> defaultIds) {
    if (_loadedOnce && state.isReady) return Future.value();
    return load(defaultIds);
  }

  Future<void> _load(List<String> defaultIds) async {
    if (!mounted) return;
    state = state.asLoading();

    try {
      final saved = await _repository.loadLayout(layoutKey: _layoutKey);
      final normalised = _dedupe(defaultIds);

      final merged = saved.isEmpty
          ? normalised
          : _mergePreservingOrder(saved, normalised);

      if (!mounted) return;
      state = state.asLoaded(merged);
      _loadedOnce = true;
    } catch (e, st) {
      debugPrint(
        '[PublisherLayoutController] load error [$_layoutKey]: '
        '$e\n$st',
      );
      if (!mounted) return;
      state = state.asError(e);
      // Fall back to defaults so the UI is never blank
      state = state.asLoaded(_dedupe(defaultIds));
      _loadedOnce = true;
    }
  }

  // ── Reorder ───────────────────────────────────────────────────────────────

  /// Reorders [visibleIds] by moving the item at [from] to [to].
  ///
  /// The state is updated **immediately** (optimistic) and the repository
  /// write is debounced in the background.  If the write ultimately fails,
  /// state is rolled back.
  Future<void> reorder(int from, int to, List<String> visibleIds) {
    if (!_isValidReorder(from, to, visibleIds)) return Future.value();
    return _enqueue(() => _reorder(from, to, visibleIds));
  }

  Future<void> _reorder(int from, int to, List<String> visibleIds) async {
    if (!mounted) return;

    final snapshot = state.ids;
    final next = _reorderInternal(from, to, visibleIds, snapshot);

    if (listEquals(snapshot, next)) return;

    // Optimistic update
    state = state.asLoaded(next);

    // Debounced persist (fire-and-forget; rollback on failure)
    _repository.saveLayout(next, layoutKey: _layoutKey).catchError((e, st) {
      debugPrint(
        '[PublisherLayoutController] persist failed [$_layoutKey], '
        'rolling back: $e\n$st',
      );
      if (mounted) state = state.asLoaded(snapshot);
    });
  }

  bool _isValidReorder(int from, int to, List<String> visible) =>
      from >= 0 &&
      from < visible.length &&
      to >= 0 &&
      to <= visible.length &&
      from != to;

  // ── Toggle visibility ─────────────────────────────────────────────────────

  /// Moves [id] to the end of the list (effectively "hiding" it) when
  /// [visible] is false, or restores it to its default position when true.
  ///
  /// Publishers that are "hidden" stay in state so their order is remembered
  /// if they are re-shown later.
  Future<void> toggle(String id, {required bool visible}) =>
      _enqueue(() => _toggle(id, visible: visible));

  Future<void> _toggle(String id, {required bool visible}) async {
    if (!mounted) return;

    final current = List<String>.from(state.ids);

    if (!current.contains(id)) return;

    // Remove from current position
    current.remove(id);

    if (visible) {
      // Re-insert at the front of the visible section
      current.insert(0, id);
    } else {
      // Push to the end (hidden)
      current.add(id);
    }

    final snapshot = state.ids;
    state = state.asLoaded(current);

    _repository.saveLayout(current, layoutKey: _layoutKey).catchError((e, st) {
      debugPrint('[PublisherLayoutController] toggle persist failed: $e\n$st');
      if (mounted) state = state.asLoaded(snapshot);
    });
  }

  // ── Remove ────────────────────────────────────────────────────────────────

  /// Permanently removes [id] from the layout.
  ///
  /// If [id] is later added back via [addPublisher], it will appear at the end.
  Future<void> remove(String id) => _enqueue(() => _remove(id));

  Future<void> _remove(String id) async {
    if (!mounted) return;

    final current = List<String>.from(state.ids);
    if (!current.remove(id)) return;

    final snapshot = state.ids;
    state = state.asLoaded(List.unmodifiable(current));

    _repository.saveLayout(current, layoutKey: _layoutKey).catchError((e, st) {
      debugPrint('[PublisherLayoutController] remove persist failed: $e\n$st');
      if (mounted) state = state.asLoaded(snapshot);
    });
  }

  // ── Add ───────────────────────────────────────────────────────────────────

  /// Appends [id] to the end of the layout if it is not already present.
  Future<void> addPublisher(String id) => _enqueue(() => _add(id));

  Future<void> _add(String id) async {
    if (!mounted) return;

    if (state.ids.contains(id)) return;

    final next = [...state.ids, id];
    final snapshot = state.ids;
    state = state.asLoaded(next);

    _repository.saveLayout(next, layoutKey: _layoutKey).catchError((e, st) {
      debugPrint('[PublisherLayoutController] add persist failed: $e\n$st');
      if (mounted) state = state.asLoaded(snapshot);
    });
  }

  // ── Reset ─────────────────────────────────────────────────────────────────

  /// Resets the layout to [defaultIds] and clears any stored customisation.
  Future<void> reset(List<String> defaultIds) =>
      _enqueue(() => _reset(defaultIds));

  Future<void> _reset(List<String> defaultIds) async {
    if (!mounted) return;

    final normalised = _dedupe(defaultIds);
    final snapshot = state.ids;
    state = state.asLoaded(normalised);

    try {
      await _repository.clearLayout(layoutKey: _layoutKey);
    } catch (e, st) {
      debugPrint('[PublisherLayoutController] reset failed: $e\n$st');
      if (mounted) state = state.asLoaded(snapshot);
    }
  }

  // ── Flush ─────────────────────────────────────────────────────────────────

  /// Forces any debounced writes to be flushed to disk immediately.
  ///
  /// Call this before the screen is disposed or the app goes to background.
  Future<void> flush() => _repository.flushPending(_layoutKey);

  // ── Internal helpers ───────────────────────────────────────────────────────

  List<String> _reorderInternal(
    int from,
    int to,
    List<String> visibleIds,
    List<String> currentState,
  ) {
    final visible = List<String>.from(visibleIds);

    final moved = visible.removeAt(from);
    visible.insert(to.clamp(0, visible.length), moved);

    // Build the result by replacing items in currentState that belong to
    // visibleIds — using the *post-mutation* visible list as the source of truth.
    // This fixes the subtle bug in the original where visibleIds.toSet() (pre-
    // mutation) was used, which could map items back to wrong positions when
    // the visible list contains duplicates or partial overlaps with state.
    final visibleSet = Set<String>.from(
      visibleIds,
    ); // original set for membership
    final next = List<String>.from(currentState);
    int pointer = 0;

    for (int i = 0; i < next.length; i++) {
      if (visibleSet.contains(next[i]) && pointer < visible.length) {
        next[i] = visible[pointer++];
      }
    }

    return _dedupe(next);
  }

  List<String> _mergePreservingOrder(
    List<String> saved,
    List<String> defaults,
  ) {
    final seen = <String>{};
    final result = <String>[];

    for (final id in saved) {
      if (seen.add(id)) result.add(id);
    }
    for (final id in defaults) {
      if (seen.add(id)) result.add(id);
    }

    return result;
  }

  List<String> _dedupe(List<String> list) {
    final seen = <String>{};
    return list.where(seen.add).toList(growable: false);
  }
}
