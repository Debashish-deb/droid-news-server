import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Night mode scheduler service for automatic dark mode based on time.
const String _enabledNightModeKey = 'night_mode_schedule_enabled';
const String _startTimeNightModeKey = 'night_mode_start_time';
const String _endTimeNightModeKey = 'night_mode_end_time';

/// Default schedule: 8 PM to 6 AM.
const TimeOfDay defaultNightModeStartTime = TimeOfDay(hour: 20, minute: 0);
const TimeOfDay defaultNightModeEndTime = TimeOfDay(hour: 6, minute: 0);

class _NightModeSettings {
  const _NightModeSettings({
    required this.enabled,
    required this.startTime,
    required this.endTime,
  });

  final bool enabled;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
}

/// Night mode scheduler service backed by an injected SharedPreferences.
class NightModeScheduler {
  const NightModeScheduler(this._prefs);

  final SharedPreferences _prefs;

  Future<bool> isScheduleEnabled() async {
    return _prefs.getBool(_enabledNightModeKey) ?? false;
  }

  Future<void> setScheduleEnabled(bool enabled) async {
    await _prefs.setBool(_enabledNightModeKey, enabled);
  }

  Future<TimeOfDay> getStartTime() async {
    final hour =
        _prefs.getInt(_startTimeNightModeKey) ?? defaultNightModeStartTime.hour;
    final minute =
        _prefs.getInt('${_startTimeNightModeKey}_minute') ??
        defaultNightModeStartTime.minute;
    return TimeOfDay(hour: hour, minute: minute);
  }

  Future<void> setStartTime(TimeOfDay time) async {
    await _prefs.setInt(_startTimeNightModeKey, time.hour);
    await _prefs.setInt('${_startTimeNightModeKey}_minute', time.minute);
  }

  Future<TimeOfDay> getEndTime() async {
    final hour =
        _prefs.getInt(_endTimeNightModeKey) ?? defaultNightModeEndTime.hour;
    final minute =
        _prefs.getInt('${_endTimeNightModeKey}_minute') ??
        defaultNightModeEndTime.minute;
    return TimeOfDay(hour: hour, minute: minute);
  }

  Future<void> setEndTime(TimeOfDay time) async {
    await _prefs.setInt(_endTimeNightModeKey, time.hour);
    await _prefs.setInt('${_endTimeNightModeKey}_minute', time.minute);
  }

  Future<_NightModeSettings> _loadSettings() async {
    return _NightModeSettings(
      enabled: await isScheduleEnabled(),
      startTime: await getStartTime(),
      endTime: await getEndTime(),
    );
  }

  Future<bool> shouldBeNightMode() async {
    final settings = await _loadSettings();
    if (!settings.enabled) return false;
    return isNightModeAt(
      now: TimeOfDay.now(),
      start: settings.startTime,
      end: settings.endTime,
    );
  }

  bool isNightModeAt({
    required TimeOfDay now,
    required TimeOfDay start,
    required TimeOfDay end,
  }) {
    final currentMinutes = now.hour * 60 + now.minute;
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;

    if (startMinutes <= endMinutes) {
      return currentMinutes >= startMinutes && currentMinutes < endMinutes;
    }
    return currentMinutes >= startMinutes || currentMinutes < endMinutes;
  }

  String formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Future<DateTime> getNextScheduledTime(bool isDarkMode) async {
    final now = DateTime.now();
    final settings = await _loadSettings();
    final targetTime = isDarkMode ? settings.endTime : settings.startTime;

    var next = DateTime(
      now.year,
      now.month,
      now.day,
      targetTime.hour,
      targetTime.minute,
    );

    if (!next.isAfter(now)) {
      next = next.add(const Duration(days: 1));
    }

    return next;
  }
}

/// Night mode scheduler notifier with automatic theme switching.
class NightModeSchedulerNotifier extends ChangeNotifier {
  NightModeSchedulerNotifier(this._scheduler) {
    unawaited(_initialize());
  }

  final NightModeScheduler _scheduler;

  bool _isEnabled = false;
  bool _isNightMode = false;
  bool _isDisposed = false;
  TimeOfDay _startTime = defaultNightModeStartTime;
  TimeOfDay _endTime = defaultNightModeEndTime;
  Timer? _checkTimer;

  bool get isEnabled => _isEnabled;
  bool get isNightMode => _isNightMode;
  TimeOfDay get startTime => _startTime;
  TimeOfDay get endTime => _endTime;

  Future<void> _initialize() async {
    await _loadSettings();
    _startPeriodicCheck();
  }

  Future<void> _loadSettings() async {
    final settings = await _scheduler._loadSettings();
    final bool shouldBeNight = settings.enabled
        ? _scheduler.isNightModeAt(
            now: TimeOfDay.now(),
            start: settings.startTime,
            end: settings.endTime,
          )
        : false;

    _notifyIfStateChanged(
      enabled: settings.enabled,
      startTime: settings.startTime,
      endTime: settings.endTime,
      isNightMode: shouldBeNight,
    );
  }

  void _notifyIfStateChanged({
    required bool enabled,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    required bool isNightMode,
  }) {
    final bool changed =
        _isEnabled != enabled ||
        _startTime != startTime ||
        _endTime != endTime ||
        _isNightMode != isNightMode;

    _isEnabled = enabled;
    _startTime = startTime;
    _endTime = endTime;
    _isNightMode = isNightMode;

    if (!_isDisposed && changed) {
      notifyListeners();
    }
  }

  void _startPeriodicCheck() {
    _checkTimer?.cancel();
    if (!_isEnabled) return;
    unawaited(_updateStateAndScheduleNext());
  }

  Future<void> _updateStateAndScheduleNext() async {
    _checkTimer?.cancel();
    final shouldBeNight = await _scheduler.shouldBeNightMode();

    if (_isNightMode != shouldBeNight) {
      _isNightMode = shouldBeNight;
      if (!_isDisposed) {
        notifyListeners();
      }
    }

    final next = await _scheduler.getNextScheduledTime(shouldBeNight);
    var delay = next.difference(DateTime.now());
    if (delay.isNegative) {
      delay = const Duration(seconds: 1);
    }
    _checkTimer = Timer(delay + const Duration(seconds: 1), () {
      if (!_isDisposed) {
        unawaited(_updateStateAndScheduleNext());
      }
    });
  }

  Future<void> setEnabled(bool enabled) async {
    if (_isEnabled == enabled) return;
    _isEnabled = enabled;
    await _scheduler.setScheduleEnabled(enabled);
    if (enabled) {
      _isNightMode = await _scheduler.shouldBeNightMode();
      _startPeriodicCheck();
    } else {
      _checkTimer?.cancel();
      _isNightMode = false;
    }
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  Future<void> setStartTime(TimeOfDay time) async {
    if (_startTime == time) return;
    _startTime = time;
    await _scheduler.setStartTime(time);
    _startPeriodicCheck();
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  Future<void> setEndTime(TimeOfDay time) async {
    if (_endTime == time) return;
    _endTime = time;
    await _scheduler.setEndTime(time);
    _startPeriodicCheck();
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  Future<bool> shouldBeNightMode() async {
    if (!_isEnabled) return false;
    final nowShouldBeNight = await _scheduler.shouldBeNightMode();
    if (nowShouldBeNight != _isNightMode && !_isDisposed) {
      _isNightMode = nowShouldBeNight;
      notifyListeners();
    }
    return _isNightMode;
  }

  @override
  void dispose() {
    _isDisposed = true;
    _checkTimer?.cancel();
    super.dispose();
  }
}
