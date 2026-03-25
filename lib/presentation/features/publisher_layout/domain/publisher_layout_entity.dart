import 'package:flutter/foundation.dart';

@immutable
class PublisherLayoutEntity {

  const PublisherLayoutEntity({
    required this.publisherId,
    required this.position,
  }) : assert(publisherId.length > 0, 'publisherId cannot be empty'),
       assert(position >= 0, 'position must be >= 0');

  /// ------------------------------------------------------------
  /// JSON Serialization (Network / API)
  /// ------------------------------------------------------------

  factory PublisherLayoutEntity.fromJson(Map<String, dynamic> json) {
    return PublisherLayoutEntity(
      publisherId: _readString(json, 'publisherId'),
      position: _readInt(json, 'position'),
    );
  }

  /// ------------------------------------------------------------
  /// DB Serialization (Local Persistence)
  /// ------------------------------------------------------------

  factory PublisherLayoutEntity.fromMap(Map<String, dynamic> map) {
    return PublisherLayoutEntity(
      publisherId: _readString(map, 'publisher_id'),
      position: _readInt(map, 'position'),
    );
  }
  final String publisherId;
  final int position;

  PublisherLayoutEntity copyWith({
    String? publisherId,
    int? position,
  }) {
    return PublisherLayoutEntity(
      publisherId: publisherId ?? this.publisherId,
      position: position ?? this.position,
    );
  }

  Map<String, dynamic> toJson() => {
        'publisherId': publisherId,
        'position': position,
      };

  Map<String, dynamic> toMap() => {
        'publisher_id': publisherId,
        'position': position,
      };

  /// ------------------------------------------------------------
  /// Domain Helpers
  /// ------------------------------------------------------------

  /// Stable identity key
  String get key => publisherId;

  /// Sorting helper
  static int sortByPosition(
    PublisherLayoutEntity a,
    PublisherLayoutEntity b,
  ) =>
      a.position.compareTo(b.position);

  /// Bulk conversion helpers
  static List<PublisherLayoutEntity> listFromJson(
    List<dynamic> data,
  ) =>
      data
          .map((e) => PublisherLayoutEntity.fromJson(
                Map<String, dynamic>.from(e),
              ))
          .toList(growable: false);

  static List<PublisherLayoutEntity> listFromMap(
    List<Map<String, dynamic>> data,
  ) =>
      data
          .map(PublisherLayoutEntity.fromMap)
          .toList(growable: false);

  static List<Map<String, dynamic>> listToJson(
    List<PublisherLayoutEntity> list,
  ) =>
      list.map((e) => e.toJson()).toList(growable: false);

  static List<Map<String, dynamic>> listToMap(
    List<PublisherLayoutEntity> list,
  ) =>
      list.map((e) => e.toMap()).toList(growable: false);

  /// ------------------------------------------------------------
  /// Equality
  /// ------------------------------------------------------------

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PublisherLayoutEntity &&
          runtimeType == other.runtimeType &&
          publisherId == other.publisherId &&
          position == other.position;

  @override
  int get hashCode => Object.hash(publisherId, position);

  @override
  String toString() =>
      'PublisherLayoutEntity(publisherId: $publisherId, position: $position)';

  /// ------------------------------------------------------------
  /// Defensive Parsing Helpers
  /// ------------------------------------------------------------

  static String _readString(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is String && value.isNotEmpty) return value;

    throw FormatException(
      'Invalid or missing "$key" in PublisherLayoutEntity: $map',
    );
  }

  static int _readInt(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is int && value >= 0) return value;

    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null && parsed >= 0) return parsed;
    }

    throw FormatException(
      'Invalid or missing "$key" in PublisherLayoutEntity: $map',
    );
  }
}
