import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/publisher_layout_repository.dart';
import 'application/publisher_layout_controller.dart';
import 'application/publisher_layout_state.dart';

// ── Repository ─────────────────────────────────────────────────────────────

/// Single repository instance per scope.
///
/// `autoDispose` ensures the Hive box is closed when the last listener
/// detaches (e.g. when the user navigates away from all publisher screens).
final publisherLayoutRepositoryProvider =
    Provider.autoDispose<PublisherLayoutRepository>((ref) {
  final repo = PublisherLayoutRepository();

  if (kDebugMode) debugPrint('[INIT] PublisherLayoutRepository');

  ref.onDispose(() {
    repo.dispose();
    if (kDebugMode) debugPrint('[DISPOSE] PublisherLayoutRepository');
  });

  return repo;
});

// ── Full State (Controller) ────────────────────────────────────────────────

/// Full [PublisherLayoutState] for a given [layoutKey].
///
/// Provides access to ids, loading status, and error in one place.
/// Use the derived providers below for fine-grained widget rebuilds.
///
/// Example:
/// ```dart
/// final state = ref.watch(publisherLayoutProvider('home'));
/// ```
final publisherLayoutProvider = StateNotifierProvider.autoDispose.family<
    PublisherLayoutController, PublisherLayoutState, String>(
  (ref, layoutKey) {
    assert(layoutKey.isNotEmpty, 'layoutKey must not be empty');

    final repo = ref.watch(publisherLayoutRepositoryProvider);

    if (kDebugMode) {
      debugPrint('[INIT] PublisherLayoutController(layoutKey=$layoutKey)');
    }

    final controller = PublisherLayoutController(repo, layoutKey: layoutKey);

    ref.onDispose(() {
      // Flush any pending debounced writes before the controller is GC-ed
      controller.flush();
      if (kDebugMode) {
        debugPrint(
          '[DISPOSE] PublisherLayoutController(layoutKey=$layoutKey)',
        );
      }
    });

    return controller;
  },
);

// ── Derived Selectors ──────────────────────────────────────────────────────
//
// Use these instead of reading the full state when you only need one slice.
// Each selector re-builds its widget only when its specific value changes.

/// Ordered list of publisher IDs for [layoutKey].
///
/// Does NOT rebuild when loading status or error changes — only when the
/// actual list content changes.
///
/// Example:
/// ```dart
/// final ids = ref.watch(publisherIdsProvider('home'));
/// ```
final publisherIdsProvider = Provider.autoDispose.family<List<String>, String>(
  (ref, layoutKey) {
    return ref.watch(
      publisherLayoutProvider(layoutKey).select((s) => s.ids),
    );
  },
);

/// Whether the layout for [layoutKey] is currently loading.
///
/// Example:
/// ```dart
/// final loading = ref.watch(publisherLayoutLoadingProvider('home'));
/// if (loading) return const CircularProgressIndicator();
/// ```
final publisherLayoutLoadingProvider =
    Provider.autoDispose.family<bool, String>(
  (ref, layoutKey) {
    return ref.watch(
      publisherLayoutProvider(layoutKey).select((s) => s.isLoading),
    );
  },
);

/// Whether the layout for [layoutKey] is in an error state.
final publisherLayoutHasErrorProvider =
    Provider.autoDispose.family<bool, String>(
  (ref, layoutKey) {
    return ref.watch(
      publisherLayoutProvider(layoutKey).select((s) => s.hasError),
    );
  },
);

/// The error object for [layoutKey], or null if there is none.
final publisherLayoutErrorProvider =
    Provider.autoDispose.family<Object?, String>(
  (ref, layoutKey) {
    return ref.watch(
      publisherLayoutProvider(layoutKey).select((s) => s.error),
    );
  },
);

/// True once the first load has completed (whether successful or not).
///
/// Useful for showing a one-time skeleton/shimmer and then never again.
///
/// Example:
/// ```dart
/// final ready = ref.watch(publisherLayoutReadyProvider('home'));
/// if (!ready) return const LayoutSkeleton();
/// ```
final publisherLayoutReadyProvider =
    Provider.autoDispose.family<bool, String>(
  (ref, layoutKey) {
    return ref.watch(
      publisherLayoutProvider(layoutKey).select((s) => s.isReady),
    );
  },
);

/// Current [PublisherLayoutStatus] for [layoutKey].
///
/// Use when you need to drive a state machine (e.g. animated transitions
/// between initial → loading → loaded → error).
final publisherLayoutStatusProvider =
    Provider.autoDispose.family<PublisherLayoutStatus, String>(
  (ref, layoutKey) {
    return ref.watch(
      publisherLayoutProvider(layoutKey).select((s) => s.status),
    );
  },
);

// ── Edit Mode ─────────────────────────────────────────────────────────────

/// Controls whether the layout editor UI is active.
///
/// Scoped per-widget tree; automatically resets to false when the last
/// listener detaches.
final editModeProvider = StateProvider.autoDispose<bool>((ref) {
  if (kDebugMode) debugPrint('[INIT] editModeProvider');
  ref.onDispose(() {
    if (kDebugMode) debugPrint('[DISPOSE] editModeProvider');
  });
  return false;
});
