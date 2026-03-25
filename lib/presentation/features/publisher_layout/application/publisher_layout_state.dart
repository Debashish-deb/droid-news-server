/// Immutable state for [PublisherLayoutController].
///
/// Separates data, loading and error concerns so UI widgets can
/// react precisely to what changed without re-rendering needlessly.
library;

import 'package:flutter/foundation.dart';

/// Status of the last async operation.
enum PublisherLayoutStatus {
  /// No load has been initiated yet.
  initial,

  /// A load or save is in progress.
  loading,

  /// Data is available and up-to-date.
  loaded,

  /// The last operation completed with an error.
  error,
}

@immutable
class PublisherLayoutState {
  const PublisherLayoutState({
    this.ids = const [],
    this.status = PublisherLayoutStatus.initial,
    this.error,
  });

  /// Ordered publisher IDs (the canonical layout).
  final List<String> ids;

  /// Current lifecycle status.
  final PublisherLayoutStatus status;

  /// Non-null only when [status] == [PublisherLayoutStatus.error].
  final Object? error;

  // ── Convenience accessors ──────────────────────────────────────────────────

  bool get isInitial  => status == PublisherLayoutStatus.initial;
  bool get isLoading  => status == PublisherLayoutStatus.loading;
  bool get isLoaded   => status == PublisherLayoutStatus.loaded;
  bool get hasError   => status == PublisherLayoutStatus.error;

  /// True only after a successful first load (ids may still be empty).
  bool get isReady    => isLoaded || hasError;

  // ── Mutations (returns new instances) ──────────────────────────────────────

  PublisherLayoutState copyWith({
    List<String>? ids,
    PublisherLayoutStatus? status,
    Object? error,
    bool clearError = false,
  }) {
    return PublisherLayoutState(
      ids: ids ?? this.ids,
      status: status ?? this.status,
      error: clearError ? null : (error ?? this.error),
    );
  }

  PublisherLayoutState asLoading() => copyWith(
        status: PublisherLayoutStatus.loading,
        clearError: true,
      );

  PublisherLayoutState asLoaded(List<String> newIds) => PublisherLayoutState(
        ids: newIds,
        status: PublisherLayoutStatus.loaded,
      );

  PublisherLayoutState asError(Object err) => PublisherLayoutState(
        ids: ids, // keep existing data visible
        status: PublisherLayoutStatus.error,
        error: err,
      );

  // ── Equality / debug ───────────────────────────────────────────────────────

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PublisherLayoutState &&
        listEquals(other.ids, ids) &&
        other.status == status &&
        other.error == error;
  }

  @override
  int get hashCode => Object.hash(
        Object.hashAll(ids),
        status,
        error,
      );

  @override
  String toString() =>
      'PublisherLayoutState(status=$status, ids=${ids.length}, '
      'error=$error)';
}
