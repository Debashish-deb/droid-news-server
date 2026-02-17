import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

/// Night mode scheduler service for automatic dark mode based on time
const String _enabledNightModeKey = 'night_mode_schedule_enabled';
const String _startTimeNightModeKey = 'night_mode_start_time';
const String _endTimeNightModeKey = 'night_mode_end_time';

/// Default schedule: 8 PM to 6 AM
const TimeOfDay defaultNightModeStartTime = TimeOfDay(hour: 20, minute: 0);
const TimeOfDay defaultNightModeEndTime = TimeOfDay(hour: 6, minute: 0);

/// Night mode scheduler service for automatic dark mode based on time
class NightModeScheduler {
  NightModeScheduler._();
  static final NightModeScheduler instance = NightModeScheduler._();

  /// Check if night mode schedule is enabled
  Future<bool> isScheduleEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledNightModeKey) ?? false;
  }

  /// Enable/disable night mode schedule
  Future<void> setScheduleEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledNightModeKey, enabled);
  }

  /// Get scheduled start time
  Future<TimeOfDay> getStartTime() async {
    final prefs = await SharedPreferences.getInstance();
    final hour = prefs.getInt(_startTimeNightModeKey) ?? defaultNightModeStartTime.hour;
    final minute =
        prefs.getInt('${_startTimeNightModeKey}_minute') ?? defaultNightModeStartTime.minute;
    return TimeOfDay(hour: hour, minute: minute);
  }

  /// Set scheduled start time
  Future<void> setStartTime(TimeOfDay time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_startTimeNightModeKey, time.hour);
    await prefs.setInt('${_startTimeNightModeKey}_minute', time.minute);
  }

  /// Get scheduled end time
  Future<TimeOfDay> getEndTime() async {
    final prefs = await SharedPreferences.getInstance();
    final hour = prefs.getInt(_endTimeNightModeKey) ?? defaultNightModeEndTime.hour;
    final minute =
        prefs.getInt('${_endTimeNightModeKey}_minute') ?? defaultNightModeEndTime.minute;
    return TimeOfDay(hour: hour, minute: minute);
  }

  /// Set scheduled end time
  Future<void> setEndTime(TimeOfDay time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_endTimeNightModeKey, time.hour);
    await prefs.setInt('${_endTimeNightModeKey}_minute', time.minute);
  }

  /// Check if current time is within night mode schedule
  Future<bool> shouldBeNightMode() async {
    final enabled = await isScheduleEnabled();
    if (!enabled) return false;

    final now = TimeOfDay.now();
    final start = await getStartTime();
    final end = await getEndTime();

    return _isTimeInRange(now, start, end);
  }

  /// Check if time is within range (handles overnight ranges)
  bool _isTimeInRange(
    TimeOfDay current,
    TimeOfDay start,
    TimeOfDay end,
  ) {
    final currentMinutes = current.hour * 60 + current.minute;
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;

    if (startMinutes <= endMinutes) {
      return currentMinutes >= startMinutes && currentMinutes < endMinutes;
    } else {
      return currentMinutes >= startMinutes || currentMinutes < endMinutes;
    }
  }

  /// Format TimeOfDay to string
  String formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  /// Get next scheduled time for night mode
  Future<DateTime> getNextScheduledTime(bool isDarkMode) async {
    final now = DateTime.now();
    final start = await getStartTime();
    final end = await getEndTime();

    final targetTime = isDarkMode ? end : start;
    var next = DateTime(
      now.year,
      now.month,
      now.day,
      targetTime.hour,
      targetTime.minute,
    );

    if (next.isBefore(now)) {
      next = next.add(const Duration(days: 1));
    }

    return next;
  }
}

/// Night mode scheduler notifier with automatic theme switching
class NightModeSchedulerNotifier extends ChangeNotifier {

  NightModeSchedulerNotifier() {
    _loadSettings();
    _startPeriodicCheck();
  }
  bool _isEnabled = false;
  TimeOfDay _startTime = defaultNightModeStartTime;
  TimeOfDay _endTime = defaultNightModeEndTime;
  Timer? _checkTimer;

  bool get isEnabled => _isEnabled;
  TimeOfDay get startTime => _startTime;
  TimeOfDay get endTime => _endTime;

  Future<void> _loadSettings() async {
    _isEnabled = await NightModeScheduler.instance.isScheduleEnabled();
    _startTime = await NightModeScheduler.instance.getStartTime();
    _endTime = await NightModeScheduler.instance.getEndTime();
    notifyListeners();
  }

  /// Start periodic check for theme changes
  void _startPeriodicCheck() {
    // Optimized from 1 minute to 5 minutes to reduce battery drain
    // Night mode transitions are not time-critical enough to warrant frequent checks
    _checkTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
      if (_isEnabled) {
        await NightModeScheduler.instance.shouldBeNightMode();
        notifyListeners();
      }
    });
  }

  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    await NightModeScheduler.instance.setScheduleEnabled(enabled);
    notifyListeners();
  }

  Future<void> setStartTime(TimeOfDay time) async {
    _startTime = time;
    await NightModeScheduler.instance.setStartTime(time);
    notifyListeners();
  }

  Future<void> setEndTime(TimeOfDay time) async {
    _endTime = time;
    await NightModeScheduler.instance.setEndTime(time);
    notifyListeners();
  }

  /// Check if night mode should be active right now
  Future<bool> shouldBeNightMode() async {
    return NightModeScheduler.instance.shouldBeNightMode();
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    super.dispose();
  }
}
