// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'news_article.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class NewsArticleAdapter extends TypeAdapter<NewsArticle> {
  @override
  final int typeId = 0;

  @override
  NewsArticle read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return NewsArticle(
      title: fields[0] as String,
      description: fields[1] as String,
      url: fields[2] as String,
      source: fields[3] as String,
      imageUrl: fields[4] as String?,
      language: fields[5] as String,
      snippet: fields[6] as String,
      fullContent: fields[7] as String,
      publishedAt: fields[8] as DateTime,
      isLive: fields[9] as bool,
      sourceOverride: fields[10] as String?,
      sourceLogo: fields[11] as String?,
      fromCache: fields[12] as bool, // ✅ added fromCache
    );
  }

  @override
  void write(BinaryWriter writer, NewsArticle obj) {
    writer
      ..writeByte(13) // ✅ total number of fields now
      ..writeByte(0)
      ..write(obj.title)
      ..writeByte(1)
      ..write(obj.description)
      ..writeByte(2)
      ..write(obj.url)
      ..writeByte(3)
      ..write(obj.source)
      ..writeByte(4)
      ..write(obj.imageUrl)
      ..writeByte(5)
      ..write(obj.language)
      ..writeByte(6)
      ..write(obj.snippet)
      ..writeByte(7)
      ..write(obj.fullContent)
      ..writeByte(8)
      ..write(obj.publishedAt)
      ..writeByte(9)
      ..write(obj.isLive)
      ..writeByte(10)
      ..write(obj.sourceOverride)
      ..writeByte(11)
      ..write(obj.sourceLogo)
      ..writeByte(12)
      ..write(obj.fromCache); // ✅ write fromCache
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NewsArticleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
