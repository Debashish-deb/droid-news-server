// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ArticlesTable extends Articles with TableInfo<$ArticlesTable, Article> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ArticlesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
      'url', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _contentMeta =
      const VerificationMeta('content');
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
      'content', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _imageUrlMeta =
      const VerificationMeta('imageUrl');
  @override
  late final GeneratedColumn<String> imageUrl = GeneratedColumn<String>(
      'image_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
      'source', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _languageMeta =
      const VerificationMeta('language');
  @override
  late final GeneratedColumn<String> language = GeneratedColumn<String>(
      'language', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('en'));
  static const VerificationMeta _publishedAtMeta =
      const VerificationMeta('publishedAt');
  @override
  late final GeneratedColumn<DateTime> publishedAt = GeneratedColumn<DateTime>(
      'published_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _categoryMeta =
      const VerificationMeta('category');
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
      'category', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _embeddingMeta =
      const VerificationMeta('embedding');
  @override
  late final GeneratedColumn<Uint8List> embedding = GeneratedColumn<Uint8List>(
      'embedding', aliasedName, true,
      type: DriftSqlType.blob, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        title,
        description,
        url,
        content,
        imageUrl,
        source,
        language,
        publishedAt,
        category,
        embedding
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'articles';
  @override
  VerificationContext validateIntegrity(Insertable<Article> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    if (data.containsKey('url')) {
      context.handle(
          _urlMeta, url.isAcceptableOrUnknown(data['url']!, _urlMeta));
    } else if (isInserting) {
      context.missing(_urlMeta);
    }
    if (data.containsKey('content')) {
      context.handle(_contentMeta,
          content.isAcceptableOrUnknown(data['content']!, _contentMeta));
    }
    if (data.containsKey('image_url')) {
      context.handle(_imageUrlMeta,
          imageUrl.isAcceptableOrUnknown(data['image_url']!, _imageUrlMeta));
    }
    if (data.containsKey('source')) {
      context.handle(_sourceMeta,
          source.isAcceptableOrUnknown(data['source']!, _sourceMeta));
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('language')) {
      context.handle(_languageMeta,
          language.isAcceptableOrUnknown(data['language']!, _languageMeta));
    }
    if (data.containsKey('published_at')) {
      context.handle(
          _publishedAtMeta,
          publishedAt.isAcceptableOrUnknown(
              data['published_at']!, _publishedAtMeta));
    } else if (isInserting) {
      context.missing(_publishedAtMeta);
    }
    if (data.containsKey('category')) {
      context.handle(_categoryMeta,
          category.isAcceptableOrUnknown(data['category']!, _categoryMeta));
    }
    if (data.containsKey('embedding')) {
      context.handle(_embeddingMeta,
          embedding.isAcceptableOrUnknown(data['embedding']!, _embeddingMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Article map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Article(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description'])!,
      url: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}url'])!,
      content: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}content']),
      imageUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}image_url']),
      source: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source'])!,
      language: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}language'])!,
      publishedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}published_at'])!,
      category: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category']),
      embedding: attachedDatabase.typeMapping
          .read(DriftSqlType.blob, data['${effectivePrefix}embedding']),
    );
  }

  @override
  $ArticlesTable createAlias(String alias) {
    return $ArticlesTable(attachedDatabase, alias);
  }
}

class Article extends DataClass implements Insertable<Article> {
  final String id;
  final String title;
  final String description;
  final String url;
  final String? content;
  final String? imageUrl;
  final String source;
  final String language;
  final DateTime publishedAt;
  final String? category;
  final Uint8List? embedding;
  const Article(
      {required this.id,
      required this.title,
      required this.description,
      required this.url,
      this.content,
      this.imageUrl,
      required this.source,
      required this.language,
      required this.publishedAt,
      this.category,
      this.embedding});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['description'] = Variable<String>(description);
    map['url'] = Variable<String>(url);
    if (!nullToAbsent || content != null) {
      map['content'] = Variable<String>(content);
    }
    if (!nullToAbsent || imageUrl != null) {
      map['image_url'] = Variable<String>(imageUrl);
    }
    map['source'] = Variable<String>(source);
    map['language'] = Variable<String>(language);
    map['published_at'] = Variable<DateTime>(publishedAt);
    if (!nullToAbsent || category != null) {
      map['category'] = Variable<String>(category);
    }
    if (!nullToAbsent || embedding != null) {
      map['embedding'] = Variable<Uint8List>(embedding);
    }
    return map;
  }

  ArticlesCompanion toCompanion(bool nullToAbsent) {
    return ArticlesCompanion(
      id: Value(id),
      title: Value(title),
      description: Value(description),
      url: Value(url),
      content: content == null && nullToAbsent
          ? const Value.absent()
          : Value(content),
      imageUrl: imageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(imageUrl),
      source: Value(source),
      language: Value(language),
      publishedAt: Value(publishedAt),
      category: category == null && nullToAbsent
          ? const Value.absent()
          : Value(category),
      embedding: embedding == null && nullToAbsent
          ? const Value.absent()
          : Value(embedding),
    );
  }

  factory Article.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Article(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String>(json['description']),
      url: serializer.fromJson<String>(json['url']),
      content: serializer.fromJson<String?>(json['content']),
      imageUrl: serializer.fromJson<String?>(json['imageUrl']),
      source: serializer.fromJson<String>(json['source']),
      language: serializer.fromJson<String>(json['language']),
      publishedAt: serializer.fromJson<DateTime>(json['publishedAt']),
      category: serializer.fromJson<String?>(json['category']),
      embedding: serializer.fromJson<Uint8List?>(json['embedding']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String>(description),
      'url': serializer.toJson<String>(url),
      'content': serializer.toJson<String?>(content),
      'imageUrl': serializer.toJson<String?>(imageUrl),
      'source': serializer.toJson<String>(source),
      'language': serializer.toJson<String>(language),
      'publishedAt': serializer.toJson<DateTime>(publishedAt),
      'category': serializer.toJson<String?>(category),
      'embedding': serializer.toJson<Uint8List?>(embedding),
    };
  }

  Article copyWith(
          {String? id,
          String? title,
          String? description,
          String? url,
          Value<String?> content = const Value.absent(),
          Value<String?> imageUrl = const Value.absent(),
          String? source,
          String? language,
          DateTime? publishedAt,
          Value<String?> category = const Value.absent(),
          Value<Uint8List?> embedding = const Value.absent()}) =>
      Article(
        id: id ?? this.id,
        title: title ?? this.title,
        description: description ?? this.description,
        url: url ?? this.url,
        content: content.present ? content.value : this.content,
        imageUrl: imageUrl.present ? imageUrl.value : this.imageUrl,
        source: source ?? this.source,
        language: language ?? this.language,
        publishedAt: publishedAt ?? this.publishedAt,
        category: category.present ? category.value : this.category,
        embedding: embedding.present ? embedding.value : this.embedding,
      );
  Article copyWithCompanion(ArticlesCompanion data) {
    return Article(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      description:
          data.description.present ? data.description.value : this.description,
      url: data.url.present ? data.url.value : this.url,
      content: data.content.present ? data.content.value : this.content,
      imageUrl: data.imageUrl.present ? data.imageUrl.value : this.imageUrl,
      source: data.source.present ? data.source.value : this.source,
      language: data.language.present ? data.language.value : this.language,
      publishedAt:
          data.publishedAt.present ? data.publishedAt.value : this.publishedAt,
      category: data.category.present ? data.category.value : this.category,
      embedding: data.embedding.present ? data.embedding.value : this.embedding,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Article(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('url: $url, ')
          ..write('content: $content, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('source: $source, ')
          ..write('language: $language, ')
          ..write('publishedAt: $publishedAt, ')
          ..write('category: $category, ')
          ..write('embedding: $embedding')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      title,
      description,
      url,
      content,
      imageUrl,
      source,
      language,
      publishedAt,
      category,
      $driftBlobEquality.hash(embedding));
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Article &&
          other.id == this.id &&
          other.title == this.title &&
          other.description == this.description &&
          other.url == this.url &&
          other.content == this.content &&
          other.imageUrl == this.imageUrl &&
          other.source == this.source &&
          other.language == this.language &&
          other.publishedAt == this.publishedAt &&
          other.category == this.category &&
          $driftBlobEquality.equals(other.embedding, this.embedding));
}

class ArticlesCompanion extends UpdateCompanion<Article> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> description;
  final Value<String> url;
  final Value<String?> content;
  final Value<String?> imageUrl;
  final Value<String> source;
  final Value<String> language;
  final Value<DateTime> publishedAt;
  final Value<String?> category;
  final Value<Uint8List?> embedding;
  final Value<int> rowid;
  const ArticlesCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.url = const Value.absent(),
    this.content = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.source = const Value.absent(),
    this.language = const Value.absent(),
    this.publishedAt = const Value.absent(),
    this.category = const Value.absent(),
    this.embedding = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ArticlesCompanion.insert({
    required String id,
    required String title,
    this.description = const Value.absent(),
    required String url,
    this.content = const Value.absent(),
    this.imageUrl = const Value.absent(),
    required String source,
    this.language = const Value.absent(),
    required DateTime publishedAt,
    this.category = const Value.absent(),
    this.embedding = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        title = Value(title),
        url = Value(url),
        source = Value(source),
        publishedAt = Value(publishedAt);
  static Insertable<Article> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? description,
    Expression<String>? url,
    Expression<String>? content,
    Expression<String>? imageUrl,
    Expression<String>? source,
    Expression<String>? language,
    Expression<DateTime>? publishedAt,
    Expression<String>? category,
    Expression<Uint8List>? embedding,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (url != null) 'url': url,
      if (content != null) 'content': content,
      if (imageUrl != null) 'image_url': imageUrl,
      if (source != null) 'source': source,
      if (language != null) 'language': language,
      if (publishedAt != null) 'published_at': publishedAt,
      if (category != null) 'category': category,
      if (embedding != null) 'embedding': embedding,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ArticlesCompanion copyWith(
      {Value<String>? id,
      Value<String>? title,
      Value<String>? description,
      Value<String>? url,
      Value<String?>? content,
      Value<String?>? imageUrl,
      Value<String>? source,
      Value<String>? language,
      Value<DateTime>? publishedAt,
      Value<String?>? category,
      Value<Uint8List?>? embedding,
      Value<int>? rowid}) {
    return ArticlesCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      url: url ?? this.url,
      content: content ?? this.content,
      imageUrl: imageUrl ?? this.imageUrl,
      source: source ?? this.source,
      language: language ?? this.language,
      publishedAt: publishedAt ?? this.publishedAt,
      category: category ?? this.category,
      embedding: embedding ?? this.embedding,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (imageUrl.present) {
      map['image_url'] = Variable<String>(imageUrl.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (language.present) {
      map['language'] = Variable<String>(language.value);
    }
    if (publishedAt.present) {
      map['published_at'] = Variable<DateTime>(publishedAt.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (embedding.present) {
      map['embedding'] = Variable<Uint8List>(embedding.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ArticlesCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('url: $url, ')
          ..write('content: $content, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('source: $source, ')
          ..write('language: $language, ')
          ..write('publishedAt: $publishedAt, ')
          ..write('category: $category, ')
          ..write('embedding: $embedding, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReadingHistoryTable extends ReadingHistory
    with TableInfo<$ReadingHistoryTable, ReadingHistoryData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReadingHistoryTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _articleIdMeta =
      const VerificationMeta('articleId');
  @override
  late final GeneratedColumn<String> articleId = GeneratedColumn<String>(
      'article_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES articles (id)'));
  static const VerificationMeta _readAtMeta = const VerificationMeta('readAt');
  @override
  late final GeneratedColumn<DateTime> readAt = GeneratedColumn<DateTime>(
      'read_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _timeSpentSecondsMeta =
      const VerificationMeta('timeSpentSeconds');
  @override
  late final GeneratedColumn<int> timeSpentSeconds = GeneratedColumn<int>(
      'time_spent_seconds', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _scrollPercentageMeta =
      const VerificationMeta('scrollPercentage');
  @override
  late final GeneratedColumn<double> scrollPercentage = GeneratedColumn<double>(
      'scroll_percentage', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0.0));
  @override
  List<GeneratedColumn> get $columns =>
      [articleId, readAt, timeSpentSeconds, scrollPercentage];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reading_history';
  @override
  VerificationContext validateIntegrity(Insertable<ReadingHistoryData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('article_id')) {
      context.handle(_articleIdMeta,
          articleId.isAcceptableOrUnknown(data['article_id']!, _articleIdMeta));
    } else if (isInserting) {
      context.missing(_articleIdMeta);
    }
    if (data.containsKey('read_at')) {
      context.handle(_readAtMeta,
          readAt.isAcceptableOrUnknown(data['read_at']!, _readAtMeta));
    } else if (isInserting) {
      context.missing(_readAtMeta);
    }
    if (data.containsKey('time_spent_seconds')) {
      context.handle(
          _timeSpentSecondsMeta,
          timeSpentSeconds.isAcceptableOrUnknown(
              data['time_spent_seconds']!, _timeSpentSecondsMeta));
    }
    if (data.containsKey('scroll_percentage')) {
      context.handle(
          _scrollPercentageMeta,
          scrollPercentage.isAcceptableOrUnknown(
              data['scroll_percentage']!, _scrollPercentageMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {articleId};
  @override
  ReadingHistoryData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReadingHistoryData(
      articleId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}article_id'])!,
      readAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}read_at'])!,
      timeSpentSeconds: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}time_spent_seconds'])!,
      scrollPercentage: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}scroll_percentage'])!,
    );
  }

  @override
  $ReadingHistoryTable createAlias(String alias) {
    return $ReadingHistoryTable(attachedDatabase, alias);
  }
}

class ReadingHistoryData extends DataClass
    implements Insertable<ReadingHistoryData> {
  final String articleId;
  final DateTime readAt;
  final int timeSpentSeconds;
  final double scrollPercentage;
  const ReadingHistoryData(
      {required this.articleId,
      required this.readAt,
      required this.timeSpentSeconds,
      required this.scrollPercentage});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['article_id'] = Variable<String>(articleId);
    map['read_at'] = Variable<DateTime>(readAt);
    map['time_spent_seconds'] = Variable<int>(timeSpentSeconds);
    map['scroll_percentage'] = Variable<double>(scrollPercentage);
    return map;
  }

  ReadingHistoryCompanion toCompanion(bool nullToAbsent) {
    return ReadingHistoryCompanion(
      articleId: Value(articleId),
      readAt: Value(readAt),
      timeSpentSeconds: Value(timeSpentSeconds),
      scrollPercentage: Value(scrollPercentage),
    );
  }

  factory ReadingHistoryData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReadingHistoryData(
      articleId: serializer.fromJson<String>(json['articleId']),
      readAt: serializer.fromJson<DateTime>(json['readAt']),
      timeSpentSeconds: serializer.fromJson<int>(json['timeSpentSeconds']),
      scrollPercentage: serializer.fromJson<double>(json['scrollPercentage']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'articleId': serializer.toJson<String>(articleId),
      'readAt': serializer.toJson<DateTime>(readAt),
      'timeSpentSeconds': serializer.toJson<int>(timeSpentSeconds),
      'scrollPercentage': serializer.toJson<double>(scrollPercentage),
    };
  }

  ReadingHistoryData copyWith(
          {String? articleId,
          DateTime? readAt,
          int? timeSpentSeconds,
          double? scrollPercentage}) =>
      ReadingHistoryData(
        articleId: articleId ?? this.articleId,
        readAt: readAt ?? this.readAt,
        timeSpentSeconds: timeSpentSeconds ?? this.timeSpentSeconds,
        scrollPercentage: scrollPercentage ?? this.scrollPercentage,
      );
  ReadingHistoryData copyWithCompanion(ReadingHistoryCompanion data) {
    return ReadingHistoryData(
      articleId: data.articleId.present ? data.articleId.value : this.articleId,
      readAt: data.readAt.present ? data.readAt.value : this.readAt,
      timeSpentSeconds: data.timeSpentSeconds.present
          ? data.timeSpentSeconds.value
          : this.timeSpentSeconds,
      scrollPercentage: data.scrollPercentage.present
          ? data.scrollPercentage.value
          : this.scrollPercentage,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReadingHistoryData(')
          ..write('articleId: $articleId, ')
          ..write('readAt: $readAt, ')
          ..write('timeSpentSeconds: $timeSpentSeconds, ')
          ..write('scrollPercentage: $scrollPercentage')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(articleId, readAt, timeSpentSeconds, scrollPercentage);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReadingHistoryData &&
          other.articleId == this.articleId &&
          other.readAt == this.readAt &&
          other.timeSpentSeconds == this.timeSpentSeconds &&
          other.scrollPercentage == this.scrollPercentage);
}

class ReadingHistoryCompanion extends UpdateCompanion<ReadingHistoryData> {
  final Value<String> articleId;
  final Value<DateTime> readAt;
  final Value<int> timeSpentSeconds;
  final Value<double> scrollPercentage;
  final Value<int> rowid;
  const ReadingHistoryCompanion({
    this.articleId = const Value.absent(),
    this.readAt = const Value.absent(),
    this.timeSpentSeconds = const Value.absent(),
    this.scrollPercentage = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReadingHistoryCompanion.insert({
    required String articleId,
    required DateTime readAt,
    this.timeSpentSeconds = const Value.absent(),
    this.scrollPercentage = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : articleId = Value(articleId),
        readAt = Value(readAt);
  static Insertable<ReadingHistoryData> custom({
    Expression<String>? articleId,
    Expression<DateTime>? readAt,
    Expression<int>? timeSpentSeconds,
    Expression<double>? scrollPercentage,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (articleId != null) 'article_id': articleId,
      if (readAt != null) 'read_at': readAt,
      if (timeSpentSeconds != null) 'time_spent_seconds': timeSpentSeconds,
      if (scrollPercentage != null) 'scroll_percentage': scrollPercentage,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReadingHistoryCompanion copyWith(
      {Value<String>? articleId,
      Value<DateTime>? readAt,
      Value<int>? timeSpentSeconds,
      Value<double>? scrollPercentage,
      Value<int>? rowid}) {
    return ReadingHistoryCompanion(
      articleId: articleId ?? this.articleId,
      readAt: readAt ?? this.readAt,
      timeSpentSeconds: timeSpentSeconds ?? this.timeSpentSeconds,
      scrollPercentage: scrollPercentage ?? this.scrollPercentage,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (articleId.present) {
      map['article_id'] = Variable<String>(articleId.value);
    }
    if (readAt.present) {
      map['read_at'] = Variable<DateTime>(readAt.value);
    }
    if (timeSpentSeconds.present) {
      map['time_spent_seconds'] = Variable<int>(timeSpentSeconds.value);
    }
    if (scrollPercentage.present) {
      map['scroll_percentage'] = Variable<double>(scrollPercentage.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReadingHistoryCompanion(')
          ..write('articleId: $articleId, ')
          ..write('readAt: $readAt, ')
          ..write('timeSpentSeconds: $timeSpentSeconds, ')
          ..write('scrollPercentage: $scrollPercentage, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncJournalTable extends SyncJournal
    with TableInfo<$SyncJournalTable, SyncJournalData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncJournalTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _entityIdMeta =
      const VerificationMeta('entityId');
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
      'entity_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _entityTypeMeta =
      const VerificationMeta('entityType');
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
      'entity_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _operationMeta =
      const VerificationMeta('operation');
  @override
  late final GeneratedColumn<String> operation = GeneratedColumn<String>(
      'operation', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _payloadJsonMeta =
      const VerificationMeta('payloadJson');
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
      'payload_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _syncStatusMeta =
      const VerificationMeta('syncStatus');
  @override
  late final GeneratedColumn<int> syncStatus = GeneratedColumn<int>(
      'sync_status', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _sequenceNumberMeta =
      const VerificationMeta('sequenceNumber');
  @override
  late final GeneratedColumn<int> sequenceNumber = GeneratedColumn<int>(
      'sequence_number', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _eventVersionMeta =
      const VerificationMeta('eventVersion');
  @override
  late final GeneratedColumn<int> eventVersion = GeneratedColumn<int>(
      'event_version', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        entityId,
        entityType,
        operation,
        payloadJson,
        createdAt,
        syncStatus,
        sequenceNumber,
        eventVersion
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_journal';
  @override
  VerificationContext validateIntegrity(Insertable<SyncJournalData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('entity_id')) {
      context.handle(_entityIdMeta,
          entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta));
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('entity_type')) {
      context.handle(
          _entityTypeMeta,
          entityType.isAcceptableOrUnknown(
              data['entity_type']!, _entityTypeMeta));
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('operation')) {
      context.handle(_operationMeta,
          operation.isAcceptableOrUnknown(data['operation']!, _operationMeta));
    } else if (isInserting) {
      context.missing(_operationMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
          _payloadJsonMeta,
          payloadJson.isAcceptableOrUnknown(
              data['payload_json']!, _payloadJsonMeta));
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('sync_status')) {
      context.handle(
          _syncStatusMeta,
          syncStatus.isAcceptableOrUnknown(
              data['sync_status']!, _syncStatusMeta));
    }
    if (data.containsKey('sequence_number')) {
      context.handle(
          _sequenceNumberMeta,
          sequenceNumber.isAcceptableOrUnknown(
              data['sequence_number']!, _sequenceNumberMeta));
    }
    if (data.containsKey('event_version')) {
      context.handle(
          _eventVersionMeta,
          eventVersion.isAcceptableOrUnknown(
              data['event_version']!, _eventVersionMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncJournalData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncJournalData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      entityId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}entity_id'])!,
      entityType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}entity_type'])!,
      operation: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}operation'])!,
      payloadJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payload_json'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      syncStatus: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sync_status'])!,
      sequenceNumber: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sequence_number']),
      eventVersion: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}event_version'])!,
    );
  }

  @override
  $SyncJournalTable createAlias(String alias) {
    return $SyncJournalTable(attachedDatabase, alias);
  }
}

class SyncJournalData extends DataClass implements Insertable<SyncJournalData> {
  final int id;
  final String entityId;
  final String entityType;
  final String operation;
  final String payloadJson;
  final DateTime createdAt;
  final int syncStatus;
  final int? sequenceNumber;
  final int eventVersion;
  const SyncJournalData(
      {required this.id,
      required this.entityId,
      required this.entityType,
      required this.operation,
      required this.payloadJson,
      required this.createdAt,
      required this.syncStatus,
      this.sequenceNumber,
      required this.eventVersion});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['entity_id'] = Variable<String>(entityId);
    map['entity_type'] = Variable<String>(entityType);
    map['operation'] = Variable<String>(operation);
    map['payload_json'] = Variable<String>(payloadJson);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['sync_status'] = Variable<int>(syncStatus);
    if (!nullToAbsent || sequenceNumber != null) {
      map['sequence_number'] = Variable<int>(sequenceNumber);
    }
    map['event_version'] = Variable<int>(eventVersion);
    return map;
  }

  SyncJournalCompanion toCompanion(bool nullToAbsent) {
    return SyncJournalCompanion(
      id: Value(id),
      entityId: Value(entityId),
      entityType: Value(entityType),
      operation: Value(operation),
      payloadJson: Value(payloadJson),
      createdAt: Value(createdAt),
      syncStatus: Value(syncStatus),
      sequenceNumber: sequenceNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(sequenceNumber),
      eventVersion: Value(eventVersion),
    );
  }

  factory SyncJournalData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncJournalData(
      id: serializer.fromJson<int>(json['id']),
      entityId: serializer.fromJson<String>(json['entityId']),
      entityType: serializer.fromJson<String>(json['entityType']),
      operation: serializer.fromJson<String>(json['operation']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      syncStatus: serializer.fromJson<int>(json['syncStatus']),
      sequenceNumber: serializer.fromJson<int?>(json['sequenceNumber']),
      eventVersion: serializer.fromJson<int>(json['eventVersion']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'entityId': serializer.toJson<String>(entityId),
      'entityType': serializer.toJson<String>(entityType),
      'operation': serializer.toJson<String>(operation),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'syncStatus': serializer.toJson<int>(syncStatus),
      'sequenceNumber': serializer.toJson<int?>(sequenceNumber),
      'eventVersion': serializer.toJson<int>(eventVersion),
    };
  }

  SyncJournalData copyWith(
          {int? id,
          String? entityId,
          String? entityType,
          String? operation,
          String? payloadJson,
          DateTime? createdAt,
          int? syncStatus,
          Value<int?> sequenceNumber = const Value.absent(),
          int? eventVersion}) =>
      SyncJournalData(
        id: id ?? this.id,
        entityId: entityId ?? this.entityId,
        entityType: entityType ?? this.entityType,
        operation: operation ?? this.operation,
        payloadJson: payloadJson ?? this.payloadJson,
        createdAt: createdAt ?? this.createdAt,
        syncStatus: syncStatus ?? this.syncStatus,
        sequenceNumber:
            sequenceNumber.present ? sequenceNumber.value : this.sequenceNumber,
        eventVersion: eventVersion ?? this.eventVersion,
      );
  SyncJournalData copyWithCompanion(SyncJournalCompanion data) {
    return SyncJournalData(
      id: data.id.present ? data.id.value : this.id,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      entityType:
          data.entityType.present ? data.entityType.value : this.entityType,
      operation: data.operation.present ? data.operation.value : this.operation,
      payloadJson:
          data.payloadJson.present ? data.payloadJson.value : this.payloadJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      syncStatus:
          data.syncStatus.present ? data.syncStatus.value : this.syncStatus,
      sequenceNumber: data.sequenceNumber.present
          ? data.sequenceNumber.value
          : this.sequenceNumber,
      eventVersion: data.eventVersion.present
          ? data.eventVersion.value
          : this.eventVersion,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncJournalData(')
          ..write('id: $id, ')
          ..write('entityId: $entityId, ')
          ..write('entityType: $entityType, ')
          ..write('operation: $operation, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('sequenceNumber: $sequenceNumber, ')
          ..write('eventVersion: $eventVersion')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, entityId, entityType, operation,
      payloadJson, createdAt, syncStatus, sequenceNumber, eventVersion);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncJournalData &&
          other.id == this.id &&
          other.entityId == this.entityId &&
          other.entityType == this.entityType &&
          other.operation == this.operation &&
          other.payloadJson == this.payloadJson &&
          other.createdAt == this.createdAt &&
          other.syncStatus == this.syncStatus &&
          other.sequenceNumber == this.sequenceNumber &&
          other.eventVersion == this.eventVersion);
}

class SyncJournalCompanion extends UpdateCompanion<SyncJournalData> {
  final Value<int> id;
  final Value<String> entityId;
  final Value<String> entityType;
  final Value<String> operation;
  final Value<String> payloadJson;
  final Value<DateTime> createdAt;
  final Value<int> syncStatus;
  final Value<int?> sequenceNumber;
  final Value<int> eventVersion;
  const SyncJournalCompanion({
    this.id = const Value.absent(),
    this.entityId = const Value.absent(),
    this.entityType = const Value.absent(),
    this.operation = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.sequenceNumber = const Value.absent(),
    this.eventVersion = const Value.absent(),
  });
  SyncJournalCompanion.insert({
    this.id = const Value.absent(),
    required String entityId,
    required String entityType,
    required String operation,
    required String payloadJson,
    required DateTime createdAt,
    this.syncStatus = const Value.absent(),
    this.sequenceNumber = const Value.absent(),
    this.eventVersion = const Value.absent(),
  })  : entityId = Value(entityId),
        entityType = Value(entityType),
        operation = Value(operation),
        payloadJson = Value(payloadJson),
        createdAt = Value(createdAt);
  static Insertable<SyncJournalData> custom({
    Expression<int>? id,
    Expression<String>? entityId,
    Expression<String>? entityType,
    Expression<String>? operation,
    Expression<String>? payloadJson,
    Expression<DateTime>? createdAt,
    Expression<int>? syncStatus,
    Expression<int>? sequenceNumber,
    Expression<int>? eventVersion,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (entityId != null) 'entity_id': entityId,
      if (entityType != null) 'entity_type': entityType,
      if (operation != null) 'operation': operation,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (createdAt != null) 'created_at': createdAt,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (sequenceNumber != null) 'sequence_number': sequenceNumber,
      if (eventVersion != null) 'event_version': eventVersion,
    });
  }

  SyncJournalCompanion copyWith(
      {Value<int>? id,
      Value<String>? entityId,
      Value<String>? entityType,
      Value<String>? operation,
      Value<String>? payloadJson,
      Value<DateTime>? createdAt,
      Value<int>? syncStatus,
      Value<int?>? sequenceNumber,
      Value<int>? eventVersion}) {
    return SyncJournalCompanion(
      id: id ?? this.id,
      entityId: entityId ?? this.entityId,
      entityType: entityType ?? this.entityType,
      operation: operation ?? this.operation,
      payloadJson: payloadJson ?? this.payloadJson,
      createdAt: createdAt ?? this.createdAt,
      syncStatus: syncStatus ?? this.syncStatus,
      sequenceNumber: sequenceNumber ?? this.sequenceNumber,
      eventVersion: eventVersion ?? this.eventVersion,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (operation.present) {
      map['operation'] = Variable<String>(operation.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<int>(syncStatus.value);
    }
    if (sequenceNumber.present) {
      map['sequence_number'] = Variable<int>(sequenceNumber.value);
    }
    if (eventVersion.present) {
      map['event_version'] = Variable<int>(eventVersion.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncJournalCompanion(')
          ..write('id: $id, ')
          ..write('entityId: $entityId, ')
          ..write('entityType: $entityType, ')
          ..write('operation: $operation, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('sequenceNumber: $sequenceNumber, ')
          ..write('eventVersion: $eventVersion')
          ..write(')'))
        .toString();
  }
}

class $BookmarksTable extends Bookmarks
    with TableInfo<$BookmarksTable, Bookmark> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BookmarksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _articleIdMeta =
      const VerificationMeta('articleId');
  @override
  late final GeneratedColumn<String> articleId = GeneratedColumn<String>(
      'article_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES articles (id)'));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [articleId, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bookmarks';
  @override
  VerificationContext validateIntegrity(Insertable<Bookmark> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('article_id')) {
      context.handle(_articleIdMeta,
          articleId.isAcceptableOrUnknown(data['article_id']!, _articleIdMeta));
    } else if (isInserting) {
      context.missing(_articleIdMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {articleId};
  @override
  Bookmark map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Bookmark(
      articleId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}article_id'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $BookmarksTable createAlias(String alias) {
    return $BookmarksTable(attachedDatabase, alias);
  }
}

class Bookmark extends DataClass implements Insertable<Bookmark> {
  final String articleId;
  final DateTime createdAt;
  const Bookmark({required this.articleId, required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['article_id'] = Variable<String>(articleId);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  BookmarksCompanion toCompanion(bool nullToAbsent) {
    return BookmarksCompanion(
      articleId: Value(articleId),
      createdAt: Value(createdAt),
    );
  }

  factory Bookmark.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Bookmark(
      articleId: serializer.fromJson<String>(json['articleId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'articleId': serializer.toJson<String>(articleId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Bookmark copyWith({String? articleId, DateTime? createdAt}) => Bookmark(
        articleId: articleId ?? this.articleId,
        createdAt: createdAt ?? this.createdAt,
      );
  Bookmark copyWithCompanion(BookmarksCompanion data) {
    return Bookmark(
      articleId: data.articleId.present ? data.articleId.value : this.articleId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Bookmark(')
          ..write('articleId: $articleId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(articleId, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Bookmark &&
          other.articleId == this.articleId &&
          other.createdAt == this.createdAt);
}

class BookmarksCompanion extends UpdateCompanion<Bookmark> {
  final Value<String> articleId;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const BookmarksCompanion({
    this.articleId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BookmarksCompanion.insert({
    required String articleId,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  })  : articleId = Value(articleId),
        createdAt = Value(createdAt);
  static Insertable<Bookmark> custom({
    Expression<String>? articleId,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (articleId != null) 'article_id': articleId,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BookmarksCompanion copyWith(
      {Value<String>? articleId,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return BookmarksCompanion(
      articleId: articleId ?? this.articleId,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (articleId.present) {
      map['article_id'] = Variable<String>(articleId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BookmarksCompanion(')
          ..write('articleId: $articleId, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncSnapshotsTable extends SyncSnapshots
    with TableInfo<$SyncSnapshotsTable, SyncSnapshot> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncSnapshotsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _entityTypeMeta =
      const VerificationMeta('entityType');
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
      'entity_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _lastSequenceNumberMeta =
      const VerificationMeta('lastSequenceNumber');
  @override
  late final GeneratedColumn<int> lastSequenceNumber = GeneratedColumn<int>(
      'last_sequence_number', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _snapshotJsonMeta =
      const VerificationMeta('snapshotJson');
  @override
  late final GeneratedColumn<String> snapshotJson = GeneratedColumn<String>(
      'snapshot_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, entityType, lastSequenceNumber, snapshotJson, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_snapshots';
  @override
  VerificationContext validateIntegrity(Insertable<SyncSnapshot> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('entity_type')) {
      context.handle(
          _entityTypeMeta,
          entityType.isAcceptableOrUnknown(
              data['entity_type']!, _entityTypeMeta));
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('last_sequence_number')) {
      context.handle(
          _lastSequenceNumberMeta,
          lastSequenceNumber.isAcceptableOrUnknown(
              data['last_sequence_number']!, _lastSequenceNumberMeta));
    } else if (isInserting) {
      context.missing(_lastSequenceNumberMeta);
    }
    if (data.containsKey('snapshot_json')) {
      context.handle(
          _snapshotJsonMeta,
          snapshotJson.isAcceptableOrUnknown(
              data['snapshot_json']!, _snapshotJsonMeta));
    } else if (isInserting) {
      context.missing(_snapshotJsonMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncSnapshot map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncSnapshot(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      entityType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}entity_type'])!,
      lastSequenceNumber: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}last_sequence_number'])!,
      snapshotJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}snapshot_json'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $SyncSnapshotsTable createAlias(String alias) {
    return $SyncSnapshotsTable(attachedDatabase, alias);
  }
}

class SyncSnapshot extends DataClass implements Insertable<SyncSnapshot> {
  final int id;
  final String entityType;
  final int lastSequenceNumber;
  final String snapshotJson;
  final DateTime createdAt;
  const SyncSnapshot(
      {required this.id,
      required this.entityType,
      required this.lastSequenceNumber,
      required this.snapshotJson,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['entity_type'] = Variable<String>(entityType);
    map['last_sequence_number'] = Variable<int>(lastSequenceNumber);
    map['snapshot_json'] = Variable<String>(snapshotJson);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  SyncSnapshotsCompanion toCompanion(bool nullToAbsent) {
    return SyncSnapshotsCompanion(
      id: Value(id),
      entityType: Value(entityType),
      lastSequenceNumber: Value(lastSequenceNumber),
      snapshotJson: Value(snapshotJson),
      createdAt: Value(createdAt),
    );
  }

  factory SyncSnapshot.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncSnapshot(
      id: serializer.fromJson<int>(json['id']),
      entityType: serializer.fromJson<String>(json['entityType']),
      lastSequenceNumber: serializer.fromJson<int>(json['lastSequenceNumber']),
      snapshotJson: serializer.fromJson<String>(json['snapshotJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'entityType': serializer.toJson<String>(entityType),
      'lastSequenceNumber': serializer.toJson<int>(lastSequenceNumber),
      'snapshotJson': serializer.toJson<String>(snapshotJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  SyncSnapshot copyWith(
          {int? id,
          String? entityType,
          int? lastSequenceNumber,
          String? snapshotJson,
          DateTime? createdAt}) =>
      SyncSnapshot(
        id: id ?? this.id,
        entityType: entityType ?? this.entityType,
        lastSequenceNumber: lastSequenceNumber ?? this.lastSequenceNumber,
        snapshotJson: snapshotJson ?? this.snapshotJson,
        createdAt: createdAt ?? this.createdAt,
      );
  SyncSnapshot copyWithCompanion(SyncSnapshotsCompanion data) {
    return SyncSnapshot(
      id: data.id.present ? data.id.value : this.id,
      entityType:
          data.entityType.present ? data.entityType.value : this.entityType,
      lastSequenceNumber: data.lastSequenceNumber.present
          ? data.lastSequenceNumber.value
          : this.lastSequenceNumber,
      snapshotJson: data.snapshotJson.present
          ? data.snapshotJson.value
          : this.snapshotJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncSnapshot(')
          ..write('id: $id, ')
          ..write('entityType: $entityType, ')
          ..write('lastSequenceNumber: $lastSequenceNumber, ')
          ..write('snapshotJson: $snapshotJson, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, entityType, lastSequenceNumber, snapshotJson, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncSnapshot &&
          other.id == this.id &&
          other.entityType == this.entityType &&
          other.lastSequenceNumber == this.lastSequenceNumber &&
          other.snapshotJson == this.snapshotJson &&
          other.createdAt == this.createdAt);
}

class SyncSnapshotsCompanion extends UpdateCompanion<SyncSnapshot> {
  final Value<int> id;
  final Value<String> entityType;
  final Value<int> lastSequenceNumber;
  final Value<String> snapshotJson;
  final Value<DateTime> createdAt;
  const SyncSnapshotsCompanion({
    this.id = const Value.absent(),
    this.entityType = const Value.absent(),
    this.lastSequenceNumber = const Value.absent(),
    this.snapshotJson = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  SyncSnapshotsCompanion.insert({
    this.id = const Value.absent(),
    required String entityType,
    required int lastSequenceNumber,
    required String snapshotJson,
    required DateTime createdAt,
  })  : entityType = Value(entityType),
        lastSequenceNumber = Value(lastSequenceNumber),
        snapshotJson = Value(snapshotJson),
        createdAt = Value(createdAt);
  static Insertable<SyncSnapshot> custom({
    Expression<int>? id,
    Expression<String>? entityType,
    Expression<int>? lastSequenceNumber,
    Expression<String>? snapshotJson,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (entityType != null) 'entity_type': entityType,
      if (lastSequenceNumber != null)
        'last_sequence_number': lastSequenceNumber,
      if (snapshotJson != null) 'snapshot_json': snapshotJson,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  SyncSnapshotsCompanion copyWith(
      {Value<int>? id,
      Value<String>? entityType,
      Value<int>? lastSequenceNumber,
      Value<String>? snapshotJson,
      Value<DateTime>? createdAt}) {
    return SyncSnapshotsCompanion(
      id: id ?? this.id,
      entityType: entityType ?? this.entityType,
      lastSequenceNumber: lastSequenceNumber ?? this.lastSequenceNumber,
      snapshotJson: snapshotJson ?? this.snapshotJson,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (lastSequenceNumber.present) {
      map['last_sequence_number'] = Variable<int>(lastSequenceNumber.value);
    }
    if (snapshotJson.present) {
      map['snapshot_json'] = Variable<String>(snapshotJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncSnapshotsCompanion(')
          ..write('id: $id, ')
          ..write('entityType: $entityType, ')
          ..write('lastSequenceNumber: $lastSequenceNumber, ')
          ..write('snapshotJson: $snapshotJson, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ArticlesTable articles = $ArticlesTable(this);
  late final $ReadingHistoryTable readingHistory = $ReadingHistoryTable(this);
  late final $SyncJournalTable syncJournal = $SyncJournalTable(this);
  late final $BookmarksTable bookmarks = $BookmarksTable(this);
  late final $SyncSnapshotsTable syncSnapshots = $SyncSnapshotsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [articles, readingHistory, syncJournal, bookmarks, syncSnapshots];
}

typedef $$ArticlesTableCreateCompanionBuilder = ArticlesCompanion Function({
  required String id,
  required String title,
  Value<String> description,
  required String url,
  Value<String?> content,
  Value<String?> imageUrl,
  required String source,
  Value<String> language,
  required DateTime publishedAt,
  Value<String?> category,
  Value<Uint8List?> embedding,
  Value<int> rowid,
});
typedef $$ArticlesTableUpdateCompanionBuilder = ArticlesCompanion Function({
  Value<String> id,
  Value<String> title,
  Value<String> description,
  Value<String> url,
  Value<String?> content,
  Value<String?> imageUrl,
  Value<String> source,
  Value<String> language,
  Value<DateTime> publishedAt,
  Value<String?> category,
  Value<Uint8List?> embedding,
  Value<int> rowid,
});

final class $$ArticlesTableReferences
    extends BaseReferences<_$AppDatabase, $ArticlesTable, Article> {
  $$ArticlesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ReadingHistoryTable, List<ReadingHistoryData>>
      _readingHistoryRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.readingHistory,
              aliasName: $_aliasNameGenerator(
                  db.articles.id, db.readingHistory.articleId));

  $$ReadingHistoryTableProcessedTableManager get readingHistoryRefs {
    final manager = $$ReadingHistoryTableTableManager($_db, $_db.readingHistory)
        .filter((f) => f.articleId.id($_item.id));

    final cache = $_typedResult.readTableOrNull(_readingHistoryRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$BookmarksTable, List<Bookmark>>
      _bookmarksRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.bookmarks,
              aliasName:
                  $_aliasNameGenerator(db.articles.id, db.bookmarks.articleId));

  $$BookmarksTableProcessedTableManager get bookmarksRefs {
    final manager = $$BookmarksTableTableManager($_db, $_db.bookmarks)
        .filter((f) => f.articleId.id($_item.id));

    final cache = $_typedResult.readTableOrNull(_bookmarksRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$ArticlesTableFilterComposer
    extends Composer<_$AppDatabase, $ArticlesTable> {
  $$ArticlesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get url => $composableBuilder(
      column: $table.url, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get imageUrl => $composableBuilder(
      column: $table.imageUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get language => $composableBuilder(
      column: $table.language, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get publishedAt => $composableBuilder(
      column: $table.publishedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnFilters(column));

  ColumnFilters<Uint8List> get embedding => $composableBuilder(
      column: $table.embedding, builder: (column) => ColumnFilters(column));

  Expression<bool> readingHistoryRefs(
      Expression<bool> Function($$ReadingHistoryTableFilterComposer f) f) {
    final $$ReadingHistoryTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.readingHistory,
        getReferencedColumn: (t) => t.articleId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ReadingHistoryTableFilterComposer(
              $db: $db,
              $table: $db.readingHistory,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> bookmarksRefs(
      Expression<bool> Function($$BookmarksTableFilterComposer f) f) {
    final $$BookmarksTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.bookmarks,
        getReferencedColumn: (t) => t.articleId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BookmarksTableFilterComposer(
              $db: $db,
              $table: $db.bookmarks,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$ArticlesTableOrderingComposer
    extends Composer<_$AppDatabase, $ArticlesTable> {
  $$ArticlesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get url => $composableBuilder(
      column: $table.url, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get imageUrl => $composableBuilder(
      column: $table.imageUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get language => $composableBuilder(
      column: $table.language, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get publishedAt => $composableBuilder(
      column: $table.publishedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<Uint8List> get embedding => $composableBuilder(
      column: $table.embedding, builder: (column) => ColumnOrderings(column));
}

class $$ArticlesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ArticlesTable> {
  $$ArticlesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get imageUrl =>
      $composableBuilder(column: $table.imageUrl, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get language =>
      $composableBuilder(column: $table.language, builder: (column) => column);

  GeneratedColumn<DateTime> get publishedAt => $composableBuilder(
      column: $table.publishedAt, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<Uint8List> get embedding =>
      $composableBuilder(column: $table.embedding, builder: (column) => column);

  Expression<T> readingHistoryRefs<T extends Object>(
      Expression<T> Function($$ReadingHistoryTableAnnotationComposer a) f) {
    final $$ReadingHistoryTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.readingHistory,
        getReferencedColumn: (t) => t.articleId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ReadingHistoryTableAnnotationComposer(
              $db: $db,
              $table: $db.readingHistory,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> bookmarksRefs<T extends Object>(
      Expression<T> Function($$BookmarksTableAnnotationComposer a) f) {
    final $$BookmarksTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.bookmarks,
        getReferencedColumn: (t) => t.articleId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BookmarksTableAnnotationComposer(
              $db: $db,
              $table: $db.bookmarks,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$ArticlesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ArticlesTable,
    Article,
    $$ArticlesTableFilterComposer,
    $$ArticlesTableOrderingComposer,
    $$ArticlesTableAnnotationComposer,
    $$ArticlesTableCreateCompanionBuilder,
    $$ArticlesTableUpdateCompanionBuilder,
    (Article, $$ArticlesTableReferences),
    Article,
    PrefetchHooks Function({bool readingHistoryRefs, bool bookmarksRefs})> {
  $$ArticlesTableTableManager(_$AppDatabase db, $ArticlesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ArticlesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ArticlesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ArticlesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String> description = const Value.absent(),
            Value<String> url = const Value.absent(),
            Value<String?> content = const Value.absent(),
            Value<String?> imageUrl = const Value.absent(),
            Value<String> source = const Value.absent(),
            Value<String> language = const Value.absent(),
            Value<DateTime> publishedAt = const Value.absent(),
            Value<String?> category = const Value.absent(),
            Value<Uint8List?> embedding = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ArticlesCompanion(
            id: id,
            title: title,
            description: description,
            url: url,
            content: content,
            imageUrl: imageUrl,
            source: source,
            language: language,
            publishedAt: publishedAt,
            category: category,
            embedding: embedding,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String title,
            Value<String> description = const Value.absent(),
            required String url,
            Value<String?> content = const Value.absent(),
            Value<String?> imageUrl = const Value.absent(),
            required String source,
            Value<String> language = const Value.absent(),
            required DateTime publishedAt,
            Value<String?> category = const Value.absent(),
            Value<Uint8List?> embedding = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ArticlesCompanion.insert(
            id: id,
            title: title,
            description: description,
            url: url,
            content: content,
            imageUrl: imageUrl,
            source: source,
            language: language,
            publishedAt: publishedAt,
            category: category,
            embedding: embedding,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$ArticlesTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: (
              {readingHistoryRefs = false, bookmarksRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (readingHistoryRefs) db.readingHistory,
                if (bookmarksRefs) db.bookmarks
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (readingHistoryRefs)
                    await $_getPrefetchedData(
                        currentTable: table,
                        referencedTable: $$ArticlesTableReferences
                            ._readingHistoryRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$ArticlesTableReferences(db, table, p0)
                                .readingHistoryRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.articleId == item.id),
                        typedResults: items),
                  if (bookmarksRefs)
                    await $_getPrefetchedData(
                        currentTable: table,
                        referencedTable:
                            $$ArticlesTableReferences._bookmarksRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$ArticlesTableReferences(db, table, p0)
                                .bookmarksRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.articleId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$ArticlesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ArticlesTable,
    Article,
    $$ArticlesTableFilterComposer,
    $$ArticlesTableOrderingComposer,
    $$ArticlesTableAnnotationComposer,
    $$ArticlesTableCreateCompanionBuilder,
    $$ArticlesTableUpdateCompanionBuilder,
    (Article, $$ArticlesTableReferences),
    Article,
    PrefetchHooks Function({bool readingHistoryRefs, bool bookmarksRefs})>;
typedef $$ReadingHistoryTableCreateCompanionBuilder = ReadingHistoryCompanion
    Function({
  required String articleId,
  required DateTime readAt,
  Value<int> timeSpentSeconds,
  Value<double> scrollPercentage,
  Value<int> rowid,
});
typedef $$ReadingHistoryTableUpdateCompanionBuilder = ReadingHistoryCompanion
    Function({
  Value<String> articleId,
  Value<DateTime> readAt,
  Value<int> timeSpentSeconds,
  Value<double> scrollPercentage,
  Value<int> rowid,
});

final class $$ReadingHistoryTableReferences extends BaseReferences<
    _$AppDatabase, $ReadingHistoryTable, ReadingHistoryData> {
  $$ReadingHistoryTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $ArticlesTable _articleIdTable(_$AppDatabase db) =>
      db.articles.createAlias(
          $_aliasNameGenerator(db.readingHistory.articleId, db.articles.id));

  $$ArticlesTableProcessedTableManager? get articleId {
    if ($_item.articleId == null) return null;
    final manager = $$ArticlesTableTableManager($_db, $_db.articles)
        .filter((f) => f.id($_item.articleId!));
    final item = $_typedResult.readTableOrNull(_articleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$ReadingHistoryTableFilterComposer
    extends Composer<_$AppDatabase, $ReadingHistoryTable> {
  $$ReadingHistoryTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<DateTime> get readAt => $composableBuilder(
      column: $table.readAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get timeSpentSeconds => $composableBuilder(
      column: $table.timeSpentSeconds,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get scrollPercentage => $composableBuilder(
      column: $table.scrollPercentage,
      builder: (column) => ColumnFilters(column));

  $$ArticlesTableFilterComposer get articleId {
    final $$ArticlesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.articleId,
        referencedTable: $db.articles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ArticlesTableFilterComposer(
              $db: $db,
              $table: $db.articles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ReadingHistoryTableOrderingComposer
    extends Composer<_$AppDatabase, $ReadingHistoryTable> {
  $$ReadingHistoryTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<DateTime> get readAt => $composableBuilder(
      column: $table.readAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get timeSpentSeconds => $composableBuilder(
      column: $table.timeSpentSeconds,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get scrollPercentage => $composableBuilder(
      column: $table.scrollPercentage,
      builder: (column) => ColumnOrderings(column));

  $$ArticlesTableOrderingComposer get articleId {
    final $$ArticlesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.articleId,
        referencedTable: $db.articles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ArticlesTableOrderingComposer(
              $db: $db,
              $table: $db.articles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ReadingHistoryTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReadingHistoryTable> {
  $$ReadingHistoryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get readAt =>
      $composableBuilder(column: $table.readAt, builder: (column) => column);

  GeneratedColumn<int> get timeSpentSeconds => $composableBuilder(
      column: $table.timeSpentSeconds, builder: (column) => column);

  GeneratedColumn<double> get scrollPercentage => $composableBuilder(
      column: $table.scrollPercentage, builder: (column) => column);

  $$ArticlesTableAnnotationComposer get articleId {
    final $$ArticlesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.articleId,
        referencedTable: $db.articles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ArticlesTableAnnotationComposer(
              $db: $db,
              $table: $db.articles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ReadingHistoryTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ReadingHistoryTable,
    ReadingHistoryData,
    $$ReadingHistoryTableFilterComposer,
    $$ReadingHistoryTableOrderingComposer,
    $$ReadingHistoryTableAnnotationComposer,
    $$ReadingHistoryTableCreateCompanionBuilder,
    $$ReadingHistoryTableUpdateCompanionBuilder,
    (ReadingHistoryData, $$ReadingHistoryTableReferences),
    ReadingHistoryData,
    PrefetchHooks Function({bool articleId})> {
  $$ReadingHistoryTableTableManager(
      _$AppDatabase db, $ReadingHistoryTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReadingHistoryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReadingHistoryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReadingHistoryTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> articleId = const Value.absent(),
            Value<DateTime> readAt = const Value.absent(),
            Value<int> timeSpentSeconds = const Value.absent(),
            Value<double> scrollPercentage = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ReadingHistoryCompanion(
            articleId: articleId,
            readAt: readAt,
            timeSpentSeconds: timeSpentSeconds,
            scrollPercentage: scrollPercentage,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String articleId,
            required DateTime readAt,
            Value<int> timeSpentSeconds = const Value.absent(),
            Value<double> scrollPercentage = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ReadingHistoryCompanion.insert(
            articleId: articleId,
            readAt: readAt,
            timeSpentSeconds: timeSpentSeconds,
            scrollPercentage: scrollPercentage,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$ReadingHistoryTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({articleId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (articleId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.articleId,
                    referencedTable:
                        $$ReadingHistoryTableReferences._articleIdTable(db),
                    referencedColumn:
                        $$ReadingHistoryTableReferences._articleIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$ReadingHistoryTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ReadingHistoryTable,
    ReadingHistoryData,
    $$ReadingHistoryTableFilterComposer,
    $$ReadingHistoryTableOrderingComposer,
    $$ReadingHistoryTableAnnotationComposer,
    $$ReadingHistoryTableCreateCompanionBuilder,
    $$ReadingHistoryTableUpdateCompanionBuilder,
    (ReadingHistoryData, $$ReadingHistoryTableReferences),
    ReadingHistoryData,
    PrefetchHooks Function({bool articleId})>;
typedef $$SyncJournalTableCreateCompanionBuilder = SyncJournalCompanion
    Function({
  Value<int> id,
  required String entityId,
  required String entityType,
  required String operation,
  required String payloadJson,
  required DateTime createdAt,
  Value<int> syncStatus,
  Value<int?> sequenceNumber,
  Value<int> eventVersion,
});
typedef $$SyncJournalTableUpdateCompanionBuilder = SyncJournalCompanion
    Function({
  Value<int> id,
  Value<String> entityId,
  Value<String> entityType,
  Value<String> operation,
  Value<String> payloadJson,
  Value<DateTime> createdAt,
  Value<int> syncStatus,
  Value<int?> sequenceNumber,
  Value<int> eventVersion,
});

class $$SyncJournalTableFilterComposer
    extends Composer<_$AppDatabase, $SyncJournalTable> {
  $$SyncJournalTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get entityId => $composableBuilder(
      column: $table.entityId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get entityType => $composableBuilder(
      column: $table.entityType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get operation => $composableBuilder(
      column: $table.operation, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payloadJson => $composableBuilder(
      column: $table.payloadJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sequenceNumber => $composableBuilder(
      column: $table.sequenceNumber,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get eventVersion => $composableBuilder(
      column: $table.eventVersion, builder: (column) => ColumnFilters(column));
}

class $$SyncJournalTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncJournalTable> {
  $$SyncJournalTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get entityId => $composableBuilder(
      column: $table.entityId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get entityType => $composableBuilder(
      column: $table.entityType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get operation => $composableBuilder(
      column: $table.operation, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payloadJson => $composableBuilder(
      column: $table.payloadJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sequenceNumber => $composableBuilder(
      column: $table.sequenceNumber,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get eventVersion => $composableBuilder(
      column: $table.eventVersion,
      builder: (column) => ColumnOrderings(column));
}

class $$SyncJournalTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncJournalTable> {
  $$SyncJournalTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get entityType => $composableBuilder(
      column: $table.entityType, builder: (column) => column);

  GeneratedColumn<String> get operation =>
      $composableBuilder(column: $table.operation, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
      column: $table.payloadJson, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => column);

  GeneratedColumn<int> get sequenceNumber => $composableBuilder(
      column: $table.sequenceNumber, builder: (column) => column);

  GeneratedColumn<int> get eventVersion => $composableBuilder(
      column: $table.eventVersion, builder: (column) => column);
}

class $$SyncJournalTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SyncJournalTable,
    SyncJournalData,
    $$SyncJournalTableFilterComposer,
    $$SyncJournalTableOrderingComposer,
    $$SyncJournalTableAnnotationComposer,
    $$SyncJournalTableCreateCompanionBuilder,
    $$SyncJournalTableUpdateCompanionBuilder,
    (
      SyncJournalData,
      BaseReferences<_$AppDatabase, $SyncJournalTable, SyncJournalData>
    ),
    SyncJournalData,
    PrefetchHooks Function()> {
  $$SyncJournalTableTableManager(_$AppDatabase db, $SyncJournalTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncJournalTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncJournalTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncJournalTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> entityId = const Value.absent(),
            Value<String> entityType = const Value.absent(),
            Value<String> operation = const Value.absent(),
            Value<String> payloadJson = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> syncStatus = const Value.absent(),
            Value<int?> sequenceNumber = const Value.absent(),
            Value<int> eventVersion = const Value.absent(),
          }) =>
              SyncJournalCompanion(
            id: id,
            entityId: entityId,
            entityType: entityType,
            operation: operation,
            payloadJson: payloadJson,
            createdAt: createdAt,
            syncStatus: syncStatus,
            sequenceNumber: sequenceNumber,
            eventVersion: eventVersion,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String entityId,
            required String entityType,
            required String operation,
            required String payloadJson,
            required DateTime createdAt,
            Value<int> syncStatus = const Value.absent(),
            Value<int?> sequenceNumber = const Value.absent(),
            Value<int> eventVersion = const Value.absent(),
          }) =>
              SyncJournalCompanion.insert(
            id: id,
            entityId: entityId,
            entityType: entityType,
            operation: operation,
            payloadJson: payloadJson,
            createdAt: createdAt,
            syncStatus: syncStatus,
            sequenceNumber: sequenceNumber,
            eventVersion: eventVersion,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SyncJournalTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SyncJournalTable,
    SyncJournalData,
    $$SyncJournalTableFilterComposer,
    $$SyncJournalTableOrderingComposer,
    $$SyncJournalTableAnnotationComposer,
    $$SyncJournalTableCreateCompanionBuilder,
    $$SyncJournalTableUpdateCompanionBuilder,
    (
      SyncJournalData,
      BaseReferences<_$AppDatabase, $SyncJournalTable, SyncJournalData>
    ),
    SyncJournalData,
    PrefetchHooks Function()>;
typedef $$BookmarksTableCreateCompanionBuilder = BookmarksCompanion Function({
  required String articleId,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$BookmarksTableUpdateCompanionBuilder = BookmarksCompanion Function({
  Value<String> articleId,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

final class $$BookmarksTableReferences
    extends BaseReferences<_$AppDatabase, $BookmarksTable, Bookmark> {
  $$BookmarksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ArticlesTable _articleIdTable(_$AppDatabase db) =>
      db.articles.createAlias(
          $_aliasNameGenerator(db.bookmarks.articleId, db.articles.id));

  $$ArticlesTableProcessedTableManager? get articleId {
    if ($_item.articleId == null) return null;
    final manager = $$ArticlesTableTableManager($_db, $_db.articles)
        .filter((f) => f.id($_item.articleId!));
    final item = $_typedResult.readTableOrNull(_articleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$BookmarksTableFilterComposer
    extends Composer<_$AppDatabase, $BookmarksTable> {
  $$BookmarksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  $$ArticlesTableFilterComposer get articleId {
    final $$ArticlesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.articleId,
        referencedTable: $db.articles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ArticlesTableFilterComposer(
              $db: $db,
              $table: $db.articles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$BookmarksTableOrderingComposer
    extends Composer<_$AppDatabase, $BookmarksTable> {
  $$BookmarksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  $$ArticlesTableOrderingComposer get articleId {
    final $$ArticlesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.articleId,
        referencedTable: $db.articles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ArticlesTableOrderingComposer(
              $db: $db,
              $table: $db.articles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$BookmarksTableAnnotationComposer
    extends Composer<_$AppDatabase, $BookmarksTable> {
  $$BookmarksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$ArticlesTableAnnotationComposer get articleId {
    final $$ArticlesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.articleId,
        referencedTable: $db.articles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ArticlesTableAnnotationComposer(
              $db: $db,
              $table: $db.articles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$BookmarksTableTableManager extends RootTableManager<
    _$AppDatabase,
    $BookmarksTable,
    Bookmark,
    $$BookmarksTableFilterComposer,
    $$BookmarksTableOrderingComposer,
    $$BookmarksTableAnnotationComposer,
    $$BookmarksTableCreateCompanionBuilder,
    $$BookmarksTableUpdateCompanionBuilder,
    (Bookmark, $$BookmarksTableReferences),
    Bookmark,
    PrefetchHooks Function({bool articleId})> {
  $$BookmarksTableTableManager(_$AppDatabase db, $BookmarksTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BookmarksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BookmarksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BookmarksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> articleId = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              BookmarksCompanion(
            articleId: articleId,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String articleId,
            required DateTime createdAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              BookmarksCompanion.insert(
            articleId: articleId,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$BookmarksTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({articleId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (articleId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.articleId,
                    referencedTable:
                        $$BookmarksTableReferences._articleIdTable(db),
                    referencedColumn:
                        $$BookmarksTableReferences._articleIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$BookmarksTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $BookmarksTable,
    Bookmark,
    $$BookmarksTableFilterComposer,
    $$BookmarksTableOrderingComposer,
    $$BookmarksTableAnnotationComposer,
    $$BookmarksTableCreateCompanionBuilder,
    $$BookmarksTableUpdateCompanionBuilder,
    (Bookmark, $$BookmarksTableReferences),
    Bookmark,
    PrefetchHooks Function({bool articleId})>;
typedef $$SyncSnapshotsTableCreateCompanionBuilder = SyncSnapshotsCompanion
    Function({
  Value<int> id,
  required String entityType,
  required int lastSequenceNumber,
  required String snapshotJson,
  required DateTime createdAt,
});
typedef $$SyncSnapshotsTableUpdateCompanionBuilder = SyncSnapshotsCompanion
    Function({
  Value<int> id,
  Value<String> entityType,
  Value<int> lastSequenceNumber,
  Value<String> snapshotJson,
  Value<DateTime> createdAt,
});

class $$SyncSnapshotsTableFilterComposer
    extends Composer<_$AppDatabase, $SyncSnapshotsTable> {
  $$SyncSnapshotsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get entityType => $composableBuilder(
      column: $table.entityType, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get lastSequenceNumber => $composableBuilder(
      column: $table.lastSequenceNumber,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get snapshotJson => $composableBuilder(
      column: $table.snapshotJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$SyncSnapshotsTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncSnapshotsTable> {
  $$SyncSnapshotsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get entityType => $composableBuilder(
      column: $table.entityType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get lastSequenceNumber => $composableBuilder(
      column: $table.lastSequenceNumber,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get snapshotJson => $composableBuilder(
      column: $table.snapshotJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$SyncSnapshotsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncSnapshotsTable> {
  $$SyncSnapshotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get entityType => $composableBuilder(
      column: $table.entityType, builder: (column) => column);

  GeneratedColumn<int> get lastSequenceNumber => $composableBuilder(
      column: $table.lastSequenceNumber, builder: (column) => column);

  GeneratedColumn<String> get snapshotJson => $composableBuilder(
      column: $table.snapshotJson, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$SyncSnapshotsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SyncSnapshotsTable,
    SyncSnapshot,
    $$SyncSnapshotsTableFilterComposer,
    $$SyncSnapshotsTableOrderingComposer,
    $$SyncSnapshotsTableAnnotationComposer,
    $$SyncSnapshotsTableCreateCompanionBuilder,
    $$SyncSnapshotsTableUpdateCompanionBuilder,
    (
      SyncSnapshot,
      BaseReferences<_$AppDatabase, $SyncSnapshotsTable, SyncSnapshot>
    ),
    SyncSnapshot,
    PrefetchHooks Function()> {
  $$SyncSnapshotsTableTableManager(_$AppDatabase db, $SyncSnapshotsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncSnapshotsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncSnapshotsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncSnapshotsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> entityType = const Value.absent(),
            Value<int> lastSequenceNumber = const Value.absent(),
            Value<String> snapshotJson = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              SyncSnapshotsCompanion(
            id: id,
            entityType: entityType,
            lastSequenceNumber: lastSequenceNumber,
            snapshotJson: snapshotJson,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String entityType,
            required int lastSequenceNumber,
            required String snapshotJson,
            required DateTime createdAt,
          }) =>
              SyncSnapshotsCompanion.insert(
            id: id,
            entityType: entityType,
            lastSequenceNumber: lastSequenceNumber,
            snapshotJson: snapshotJson,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SyncSnapshotsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SyncSnapshotsTable,
    SyncSnapshot,
    $$SyncSnapshotsTableFilterComposer,
    $$SyncSnapshotsTableOrderingComposer,
    $$SyncSnapshotsTableAnnotationComposer,
    $$SyncSnapshotsTableCreateCompanionBuilder,
    $$SyncSnapshotsTableUpdateCompanionBuilder,
    (
      SyncSnapshot,
      BaseReferences<_$AppDatabase, $SyncSnapshotsTable, SyncSnapshot>
    ),
    SyncSnapshot,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ArticlesTableTableManager get articles =>
      $$ArticlesTableTableManager(_db, _db.articles);
  $$ReadingHistoryTableTableManager get readingHistory =>
      $$ReadingHistoryTableTableManager(_db, _db.readingHistory);
  $$SyncJournalTableTableManager get syncJournal =>
      $$SyncJournalTableTableManager(_db, _db.syncJournal);
  $$BookmarksTableTableManager get bookmarks =>
      $$BookmarksTableTableManager(_db, _db.bookmarks);
  $$SyncSnapshotsTableTableManager get syncSnapshots =>
      $$SyncSnapshotsTableTableManager(_db, _db.syncSnapshots);
}
