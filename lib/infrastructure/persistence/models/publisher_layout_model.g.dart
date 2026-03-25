// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'publisher_layout_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PublisherLayoutModelAdapter extends TypeAdapter<PublisherLayoutModel> {
  @override
  final int typeId = 1;

  @override
  PublisherLayoutModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PublisherLayoutModel(
      publisherId: fields[0] as String,
      position: fields[1] as int,
    );
  }

  @override
  void write(BinaryWriter writer, PublisherLayoutModel obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.publisherId)
      ..writeByte(1)
      ..write(obj.position);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PublisherLayoutModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
