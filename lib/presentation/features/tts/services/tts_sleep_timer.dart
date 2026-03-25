import 'dart:async';
import 'package:flutter/foundation.dart';

class TtsSleepTimer {
  TtsSleepTimer({required this.onSleepTimerExpired});

  final VoidCallback onSleepTimerExpired;

  Timer? _sleepTimer;
  DateTime? _sleepEndTime;
  final _sleepTimerController = StreamController<Duration?>.broadcast();

  /// Remaining sleep time; null when no timer is active.
  Stream<Duration?> get sleepTimerRemaining => _sleepTimerController.stream;

  /// Start a sleep timer that stops playback after [duration].
  void setSleepTimer(Duration duration) {
    cancelSleepTimer();
    if (duration == Duration.zero) {
      _sleepTimerController.add(null);
      return;
    }

    _sleepEndTime = DateTime.now().add(duration);

    // Tick every second to update the UI countdown
    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      final remaining = _sleepEndTime!.difference(DateTime.now());
      if (remaining.isNegative) {
        _sleepTimerController.add(Duration.zero);
        t.cancel();
        onSleepTimerExpired();
      } else {
        _sleepTimerController.add(remaining);
      }
    });

    _sleepTimerController.add(duration);
    debugPrint('[TtsSleepTimer] Sleep timer set: ${duration.inMinutes}min');
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepEndTime = null;
    if (!_sleepTimerController.isClosed) {
      _sleepTimerController.add(null);
    }
  }

  Duration? get sleepTimerRemainingValue {
    if (_sleepEndTime == null) return null;
    final remaining = _sleepEndTime!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  void dispose() {
    cancelSleepTimer();
    _sleepTimerController.close();
  }
}
