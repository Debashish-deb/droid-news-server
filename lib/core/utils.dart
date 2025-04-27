// File: lib/utils/date_time_utils.dart

import 'package:intl/intl.dart';

class DateTimeUtils {
  /// Returns current date in format like: Monday, April 7, 2025
  static String getCurrentDate() {
    return DateFormat.yMMMMEEEEd().format(DateTime.now());
  }

  /// Returns current time in format like: 5:30 PM
  static String getCurrentTime() {
    return DateFormat.jm().format(DateTime.now());
  }

  /// Formats any DateTime object to a readable string.
  static String formatDateTime(DateTime dateTime, {String pattern = 'yMMMMEEEEd'}) {
    return DateFormat(pattern).format(dateTime);
  }

  /// Returns a human-readable "time ago" or "in time" format.
  static String timeAgo(
    DateTime dateTime, {
    String minute = 'minute',
    String hour = 'hour',
    String day = 'day',
    String week = 'week',
    String month = 'month',
    String year = 'year',
    String ago = 'ago',
    String inPrefix = 'In',
    String justNow = 'Just now',
    String fewSeconds = 'In a few seconds',
  }) {
    final Duration diff = DateTime.now().difference(dateTime);

    if (diff.inSeconds.abs() < 60) return diff.isNegative ? fewSeconds : justNow;
    if (diff.inMinutes.abs() < 60) {
      final int minutes = diff.inMinutes.abs();
      return diff.isNegative
          ? '$inPrefix $minutes $minute${minutes == 1 ? '' : 's'}'
          : '$minutes $minute${minutes == 1 ? '' : 's'} $ago';
    }
    if (diff.inHours.abs() < 24) {
      final int hours = diff.inHours.abs();
      return diff.isNegative
          ? '$inPrefix $hours $hour${hours == 1 ? '' : 's'}'
          : '$hours $hour${hours == 1 ? '' : 's'} $ago';
    }
    if (diff.inDays.abs() < 7) {
      final int days = diff.inDays.abs();
      return diff.isNegative
          ? '$inPrefix $days $day${days == 1 ? '' : 's'}'
          : '$days $day${days == 1 ? '' : 's'} $ago';
    }
    if (diff.inDays.abs() < 30) {
      final int weeks = (diff.inDays.abs() / 7).floor();
      return diff.isNegative
          ? '$inPrefix $weeks $week${weeks == 1 ? '' : 's'}'
          : '$weeks $week${weeks == 1 ? '' : 's'} $ago';
    }
    if (diff.inDays.abs() < 365) {
      final int months = (diff.inDays.abs() / 30).floor();
      return diff.isNegative
          ? '$inPrefix $months $month${months == 1 ? '' : 's'}'
          : '$months $month${months == 1 ? '' : 's'} $ago';
    }
    final int years = (diff.inDays.abs() / 365).floor();
    return diff.isNegative
        ? '$inPrefix $years $year${years == 1 ? '' : 's'}'
        : '$years $year${years == 1 ? '' : 's'} $ago';
  }
}

class StringUtils {
  /// Capitalizes the first letter of a string.
  static String capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
}
