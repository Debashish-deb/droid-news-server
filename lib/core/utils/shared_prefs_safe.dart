import 'package:shared_preferences/shared_preferences.dart';

extension SharedPrefsSafe on SharedPreferences {
  int? getIntSafe(String key) {
    final value = get(key);
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  double? getDoubleSafe(String key) {
    final value = get(key);
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  bool? getBoolSafe(String key) {
    final value = get(key);
    if (value is bool) return value;
    if (value is String) {
      final normalized = value.toLowerCase();
      if (normalized == 'true') return true;
      if (normalized == 'false') return false;
    }
    return null;
  }
}
