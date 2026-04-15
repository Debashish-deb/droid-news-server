import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/publisher_layout_repository.dart';
import 'application/publisher_layout_controller.dart';
import 'application/publisher_layout_state.dart';

// ── Repository ─────────────────────────────────────────────────────────────

final publisherLayoutRepositoryProvider = Provider<PublisherLayoutRepository>((
  ref,
) {
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

final publisherLayoutProvider =
    StateNotifierProvider.family<
      PublisherLayoutController,
      PublisherLayoutState,
      String
    >((ref, layoutKey) {
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
    });

// ── Derived Selectors ──────────────────────────────────────────────────────

/// Ordered list of publisher IDs for [layoutKey].

final publisherIdsProvider = Provider.autoDispose.family<List<String>, String>((
  ref,
  layoutKey,
) {
  return ref.watch(publisherLayoutProvider(layoutKey).select((s) => s.ids));
});

/// Whether the layout for [layoutKey] is currently loading.

final publisherLayoutLoadingProvider = Provider.autoDispose
    .family<bool, String>((ref, layoutKey) {
      return ref.watch(
        publisherLayoutProvider(layoutKey).select((s) => s.isLoading),
      );
    });

/// Whether the layout for [layoutKey] is in an error state.
final publisherLayoutHasErrorProvider = Provider.autoDispose
    .family<bool, String>((ref, layoutKey) {
      return ref.watch(
        publisherLayoutProvider(layoutKey).select((s) => s.hasError),
      );
    });

/// The error object for [layoutKey], or null if there is none.
final publisherLayoutErrorProvider = Provider.autoDispose
    .family<Object?, String>((ref, layoutKey) {
      return ref.watch(
        publisherLayoutProvider(layoutKey).select((s) => s.error),
      );
    });

/// True once the first load has completed (whether successful or not).
///

final publisherLayoutReadyProvider = Provider.autoDispose.family<bool, String>((
  ref,
  layoutKey,
) {
  return ref.watch(publisherLayoutProvider(layoutKey).select((s) => s.isReady));
});

/// Current [PublisherLayoutStatus] for [layoutKey].
///
/// Use when you need to drive a state machine (e.g. animated transitions
/// between initial → loading → loaded → error).
final publisherLayoutStatusProvider = Provider.autoDispose
    .family<PublisherLayoutStatus, String>((ref, layoutKey) {
      return ref.watch(
        publisherLayoutProvider(layoutKey).select((s) => s.status),
      );
    });

// ── Edit Mode ─────────────────────────────────────────────────────────────

/// Controls whether the layout editor UI is active for a given [layoutKey].
///
/// Keeping this state scoped per layout avoids edit-mode bleed between
/// newspapers and magazines while still letting each screen dispose cleanly
/// when it leaves the tree.
final editModeProvider = StateProvider.autoDispose.family<bool, String>((
  ref,
  layoutKey,
) {
  assert(layoutKey.isNotEmpty, 'layoutKey must not be empty');
  if (kDebugMode) debugPrint('[INIT] editModeProvider(layoutKey=$layoutKey)');
  ref.onDispose(() {
    if (kDebugMode) {
      debugPrint('[DISPOSE] editModeProvider(layoutKey=$layoutKey)');
    }
  });
  return false;
});
