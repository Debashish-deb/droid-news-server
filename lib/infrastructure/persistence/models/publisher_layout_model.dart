import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../../../presentation/features/publisher_layout/domain/publisher_layout_entity.dart';

part 'publisher_layout_model.g.dart';

@HiveType(typeId: 1)
@immutable
class PublisherLayoutModel extends HiveObject {

  PublisherLayoutModel({
    required this.publisherId,
    required this.position,
  });
  @HiveField(0)
  final String publisherId;

  @HiveField(1)
  final int position;


  PublisherLayoutEntity toEntity() {
    return PublisherLayoutEntity(
      publisherId: publisherId,
      position: position,
    );
  }

  static PublisherLayoutModel fromEntity(
    PublisherLayoutEntity entity,
  ) {
    return PublisherLayoutModel(
      publisherId: entity.publisherId,
      position: entity.position,
    );
  }


  PublisherLayoutModel copyWith({
    String? publisherId,
    int? position,
  }) {
    return PublisherLayoutModel(
      publisherId: publisherId ?? this.publisherId,
      position: position ?? this.position,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PublisherLayoutModel &&
          runtimeType == other.runtimeType &&
          publisherId == other.publisherId &&
          position == other.position;

  @override
  int get hashCode => Object.hash(publisherId, position);


  @override
  String toString() {
    return 'PublisherLayoutModel(publisherId: $publisherId, position: $position)';
  }
}
