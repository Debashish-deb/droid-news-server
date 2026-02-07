import 'dart:convert';

/// Mixin providing common model functionality
mixin ModelMixin {
  /// Convert model to JSON string
  String toJsonString() => json.encode(toJson());
  
  /// Must be implemented by model
  Map<String, dynamic> toJson();
}

/// Extension on Map for safer JSON parsing
extension JsonMapExtension on Map<String, dynamic> {
  /// Get string or null
  String? getString(String key) => this[key] as String?;
  
  /// Get string or default
  String getStringOr(String key, String defaultValue) => 
      (this[key] as String?) ?? defaultValue;
  
  /// Get int or null
  int? getInt(String key) => this[key] as int?;
  
  /// Get int or default
  int getIntOr(String key, int defaultValue) => 
      (this[key] as int?) ?? defaultValue;
  
  /// Get double or null
  double? getDouble(String key) {
    final value = this[key];
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return null;
  }
  
  /// Get double or default
  double getDoubleOr(String key, double defaultValue) => 
      getDouble(key) ?? defaultValue;
  
  /// Get bool or null
  bool? getBool(String key) => this[key] as bool?;
  
  /// Get bool or default
  bool getBoolOr(String key, bool defaultValue) => 
      (this[key] as bool?) ?? defaultValue;
  
  /// Get DateTime from ISO string
  DateTime? getDateTime(String key) {
    final value = this[key];
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
  
  /// Get DateTime or default
  DateTime getDateTimeOr(String key, DateTime defaultValue) => 
      getDateTime(key) ?? defaultValue;
  
  /// Get list or empty list
  List<T> getList<T>(String key) => 
      (this[key] as List?)?.cast<T>() ?? <T>[];
  
  /// Get nested map or empty map
  Map<String, dynamic> getMap(String key) => 
      (this[key] as Map<String, dynamic>?) ?? <String, dynamic>{};
}

/// Extension for DateTime JSON serialization
extension DateTimeJsonExtension on DateTime {
  /// Convert to ISO string for JSON
  String toJsonValue() => toIso8601String();
}
