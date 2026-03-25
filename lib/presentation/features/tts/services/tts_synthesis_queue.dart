import 'dart:async';

/// A simple queue to serialize asynchronous synthesis tasks.
class TtsSynthesisQueue {
  Future<void> _queue = Future<void>.value();

  /// Enqueues a task to run after all currently queued tasks complete.
  Future<T> runLocked<T>(Future<T> Function() task) {
    final completer = Completer<T>();
    _queue = _queue.catchError((_) {}).then((_) async {
      try {
        final result = await task();
        if (!completer.isCompleted) {
          completer.complete(result);
        }
      } catch (e, s) {
        if (!completer.isCompleted) {
          completer.completeError(e, s);
        }
      }
    });
    return completer.future;
  }

  /// Cancels pending tasks. This effectively just skips wait for old queue.
  void clear() {
    _queue = Future<void>.value();
  }
}
