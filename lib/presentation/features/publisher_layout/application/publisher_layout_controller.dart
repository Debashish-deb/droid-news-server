import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/publisher_layout_repository.dart';

class PublisherLayoutController extends StateNotifier<List<String>> {

  PublisherLayoutController(
    this._repository, {
    required String layoutKey,
  })  : _layoutKey = layoutKey,
        super(const []);
  final PublisherLayoutRepository _repository;
  final String _layoutKey;

  Completer<void>? _inFlight;

  /// ------------------------------------------------------------
  /// Load Layout (Idempotent + Merge Safe)
  /// ------------------------------------------------------------
  Future<void> load(List<String> defaultIds) async {
    if (_inFlight != null) return _inFlight!.future;

    final completer = Completer<void>();
    _inFlight = completer;

    try {
      final saved =
          await _repository.loadLayout(layoutKey: _layoutKey);

      final List<String> normalizedDefaults =
          _dedupe(defaultIds);

      if (saved.isEmpty) {
        state = normalizedDefaults;
      } else {
        final merged =
            _mergePreservingOrder(saved, normalizedDefaults);

        if (!listEquals(state, merged)) {
          state = merged;
        }
      }
    } catch (e, st) {
      debugPrint('❌ Layout load error [$_layoutKey]: $e\n$st');
      state = _dedupe(defaultIds);
    } finally {
      completer.complete();
      _inFlight = null;
    }
  }

  /// ------------------------------------------------------------
  /// Reorder Layout (Transactional + Concurrency Safe)
  /// ------------------------------------------------------------
  Future<void> reorder(
    int from,
    int to,
    List<String> visibleIds,
  ) async {
    if (from < 0 ||
        from >= visibleIds.length ||
        to < 0 ||
        from == to) {
      return;
    }

    if (_inFlight != null) return _inFlight!.future;

    final completer = Completer<void>();
    _inFlight = completer;

    final List<String> prevState = List.from(state);

    try {
      final nextState =
          _reorderInternal(from, to, visibleIds, prevState);

      if (listEquals(prevState, nextState)) return;

      state = nextState;

      await _repository.saveLayout(
        nextState,
        layoutKey: _layoutKey,
      );
    } catch (e, st) {
      debugPrint(
        '❌ Layout reorder failed [$_layoutKey]: $e\n$st',
      );
      state = prevState; // rollback
    } finally {
      completer.complete();
      _inFlight = null;
    }
  }

  /// ------------------------------------------------------------
  /// Internal Helpers
  /// ------------------------------------------------------------

  List<String> _reorderInternal(
    int from,
    int to,
    List<String> visibleIds,
    List<String> currentState,
  ) {
    final visible = List<String>.from(visibleIds);

    // Adjust target index if dragging downwards
    // This is required because removing the item at 'from' shifts subsequent indices
    if (from < to) {
      to -= 1;
    }

    final moved = visible.removeAt(from);

    final target = to.clamp(0, visible.length);
    visible.insert(target, moved);

    final visibleSet = visibleIds.toSet();
    final next = List<String>.from(currentState);

    int pointer = 0;
    for (int i = 0; i < next.length; i++) {
      if (visibleSet.contains(next[i])) {
        if (pointer < visible.length) {
          next[i] = visible[pointer++];
        }
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
