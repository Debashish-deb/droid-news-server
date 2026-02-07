import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/publisher_layout_repository.dart';
import 'application/publisher_layout_controller.dart';

/// ------------------------------------------------------------
/// Repository Provider
/// ------------------------------------------------------------
///
/// Single source of truth for layout persistence.
/// Keeps dependency injection clean & testable.
/// Lifecycle-safe + observable.
///
final publisherLayoutRepositoryProvider =
    Provider.autoDispose<PublisherLayoutRepository>((ref) {
  final repo = PublisherLayoutRepository();

  if (kDebugMode) {
    debugPrint('[INIT] PublisherLayoutRepository');
  }

  ref.onDispose(() {
    if (kDebugMode) {
      debugPrint('[DISPOSE] PublisherLayoutRepository');
    }
  });

  return repo;
});

/// ------------------------------------------------------------
/// Layout Controller Provider (Family)
/// ------------------------------------------------------------
///
/// Each layoutKey gets its own isolated controller.
/// Fully lifecycle-safe, scoped, testable.
///
final publisherLayoutProvider = StateNotifierProvider.autoDispose.family<
    PublisherLayoutController, List<String>, String>(
  (ref, layoutKey) {
    assert(layoutKey.isNotEmpty, 'layoutKey must not be empty');

    final repo = ref.watch(publisherLayoutRepositoryProvider);

    if (kDebugMode) {
      debugPrint('[INIT] PublisherLayoutController(layoutKey=$layoutKey)');
    }

    final controller =
        PublisherLayoutController(repo, layoutKey: layoutKey);

    ref.onDispose(() {
      if (kDebugMode) {
        debugPrint(
          '[DISPOSE] PublisherLayoutController(layoutKey=$layoutKey)',
        );
      }
    });

    return controller;
  },
);

/// ------------------------------------------------------------
/// Edit Mode Provider (Scoped UI State)
/// ------------------------------------------------------------
///
/// Controls layout editing mode.
/// Lightweight, ephemeral UI-only state.
///
final editModeProvider = StateProvider.autoDispose<bool>((ref) {
  if (kDebugMode) {
    debugPrint('[INIT] editModeProvider');
  }

  ref.onDispose(() {
    if (kDebugMode) {
      debugPrint('[DISPOSE] editModeProvider');
    }
  });

  return false;
});
