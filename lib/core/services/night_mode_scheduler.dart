import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

/// Night mode scheduler service for automatic dark mode based on time
class NightModeScheduler {
  static const String _enabledKey = 'night_mode_schedule_enabled';
  static const String _startTimeKey = 'night_mode_start_time';
  static const String _endTimeKey = 'night_mode_end_time';

  /// Default schedule: 8 PM to 6 AM
  static const TimeOfDay defaultStartTime = TimeOfDay(hour: 20, minute: 0);
  static const TimeOfDay defaultEndTime = TimeOfDay(hour: 6, minute: 0);

  /// Check if night mode schedule is enabled
  static Future<bool> isScheduleEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  /// Enable/disable night mode schedule
  static Future<void> setScheduleEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
  }

  /// Get scheduled start time
  static Future<TimeOfDay> getStartTime() async {
    final prefs = await SharedPreferences.getInstance();
    final hour = prefs.getInt(_startTimeKey) ?? defaultStartTime.hour;
    final minute =
        prefs.getInt('${_startTimeKey}_minute') ?? defaultStartTime.minute;
    return TimeOfDay(hour: hour, minute: minute);
  }

  /// Set scheduled start time
  static Future<void> setStartTime(TimeOfDay time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_startTimeKey, time.hour);
    await prefs.setInt('${_startTimeKey}_minute', time.minute);
  }

  /// Get scheduled end time
  static Future<TimeOfDay> getEndTime() async {
    final prefs = await SharedPreferences.getInstance();
    final hour = prefs.getInt(_endTimeKey) ?? defaultEndTime.hour;
    final minute =
        prefs.getInt('${_endTimeKey}_minute') ?? defaultEndTime.minute;
    return TimeOfDay(hour: hour, minute: minute);
  }

  /// Set scheduled end time
  static Future<void> setEndTime(TimeOfDay time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_endTimeKey, time.hour);
    await prefs.setInt('${_endTimeKey}_minute', time.minute);
  }

  /// Check if current time is within night mode schedule
  static Future<bool> shouldBeNightMode() async {
    final enabled = await isScheduleEnabled();
    if (!enabled) return false;

    final now = TimeOfDay.now();
    final start = await getStartTime();
    final end = await getEndTime();

    return _isTimeInRange(now, start, end);
  }

  /// Check if time is within range (handles overnight ranges)
  static bool _isTimeInRange(
    TimeOfDay current,
    TimeOfDay start,
    TimeOfDay end,
  ) {
    final currentMinutes = current.hour * 60 + current.minute;
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;

    if (startMinutes <= endMinutes) {
      // Normal range (e.g., 8 AM to 6 PM)
      return currentMinutes >= startMinutes && currentMinutes < endMinutes;
    } else {
      // Overnight range (e.g., 8 PM to 6 AM)
      return currentMinutes >= startMinutes || currentMinutes < endMinutes;
    }
  }

  /// Format TimeOfDay to string
  static String formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  /// Get next scheduled time for night mode
  static Future<DateTime> getNextScheduledTime(bool isDarkMode) async {
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

    // If target time has passed today, schedule for tomorrow
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
  TimeOfDay _startTime = NightModeScheduler.defaultStartTime;
  TimeOfDay _endTime = NightModeScheduler.defaultEndTime;
  Timer? _checkTimer;

  bool get isEnabled => _isEnabled;
  TimeOfDay get startTime => _startTime;
  TimeOfDay get endTime => _endTime;

  Future<void> _loadSettings() async {
    _isEnabled = await NightModeScheduler.isScheduleEnabled();
    _startTime = await NightModeScheduler.getStartTime();
    _endTime = await NightModeScheduler.getEndTime();
    notifyListeners();
  }

  /// Start periodic check for theme changes
  void _startPeriodicCheck() {
    // Check every minute
    _checkTimer = Timer.periodic(const Duration(minutes: 1), (_) async {
      if (_isEnabled) {
        final shouldBeDark = await NightModeScheduler.shouldBeNightMode();
        // Notify listeners to trigger theme change if needed
        notifyListeners();
      }
    });
  }

  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    await NightModeScheduler.setScheduleEnabled(enabled);
    notifyListeners();
  }

  Future<void> setStartTime(TimeOfDay time) async {
    _startTime = time;
    await NightModeScheduler.setStartTime(time);
    notifyListeners();
  }

  Future<void> setEndTime(TimeOfDay time) async {
    _endTime = time;
    await NightModeScheduler.setEndTime(time);
    notifyListeners();
  }

  /// Check if night mode should be active right now
  Future<bool> shouldBeNightMode() async {
    return NightModeScheduler.shouldBeNightMode();
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    super.dispose();
  }
}
