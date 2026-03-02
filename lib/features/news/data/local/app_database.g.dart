// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $NewsArticlesTableTable extends NewsArticlesTable
    with TableInfo<$NewsArticlesTableTable, NewsArticlesTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NewsArticlesTableTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _summaryMeta =
      const VerificationMeta('summary');
  @override
  late final GeneratedColumn<String> summary = GeneratedColumn<String>(
      'summary', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _originalUrlMeta =
      const VerificationMeta('originalUrl');
  @override
  late final GeneratedColumn<String> originalUrl = GeneratedColumn<String>(
      'original_url', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _imageUrlMeta =
      const VerificationMeta('imageUrl');
  @override
  late final GeneratedColumn<String> imageUrl = GeneratedColumn<String>(
      'image_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _sourceNameMeta =
      const VerificationMeta('sourceName');
  @override
  late final GeneratedColumn<String> sourceName = GeneratedColumn<String>(
      'source_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sourceFaviconUrlMeta =
      const VerificationMeta('sourceFaviconUrl');
  @override
  late final GeneratedColumn<String> sourceFaviconUrl = GeneratedColumn<String>(
      'source_favicon_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
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
      'category', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('world'));
  static const VerificationMeta _isPaywalledMeta =
      const VerificationMeta('isPaywalled');
  @override
  late final GeneratedColumn<bool> isPaywalled = GeneratedColumn<bool>(
      'is_paywalled', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_paywalled" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _clusterIdMeta =
      const VerificationMeta('clusterId');
  @override
  late final GeneratedColumn<String> clusterId = GeneratedColumn<String>(
      'cluster_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        title,
        summary,
        originalUrl,
        imageUrl,
        sourceName,
        sourceFaviconUrl,
        publishedAt,
        category,
        isPaywalled,
        clusterId
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'news_articles';
  @override
  VerificationContext validateIntegrity(
      Insertable<NewsArticlesTableData> instance,
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
    if (data.containsKey('summary')) {
      context.handle(_summaryMeta,
          summary.isAcceptableOrUnknown(data['summary']!, _summaryMeta));
    } else if (isInserting) {
      context.missing(_summaryMeta);
    }
    if (data.containsKey('original_url')) {
      context.handle(
          _originalUrlMeta,
          originalUrl.isAcceptableOrUnknown(
              data['original_url']!, _originalUrlMeta));
    } else if (isInserting) {
      context.missing(_originalUrlMeta);
    }
    if (data.containsKey('image_url')) {
      context.handle(_imageUrlMeta,
          imageUrl.isAcceptableOrUnknown(data['image_url']!, _imageUrlMeta));
    }
    if (data.containsKey('source_name')) {
      context.handle(
          _sourceNameMeta,
          sourceName.isAcceptableOrUnknown(
              data['source_name']!, _sourceNameMeta));
    } else if (isInserting) {
      context.missing(_sourceNameMeta);
    }
    if (data.containsKey('source_favicon_url')) {
      context.handle(
          _sourceFaviconUrlMeta,
          sourceFaviconUrl.isAcceptableOrUnknown(
              data['source_favicon_url']!, _sourceFaviconUrlMeta));
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
    if (data.containsKey('is_paywalled')) {
      context.handle(
          _isPaywalledMeta,
          isPaywalled.isAcceptableOrUnknown(
              data['is_paywalled']!, _isPaywalledMeta));
    }
    if (data.containsKey('cluster_id')) {
      context.handle(_clusterIdMeta,
          clusterId.isAcceptableOrUnknown(data['cluster_id']!, _clusterIdMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  NewsArticlesTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NewsArticlesTableData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      summary: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}summary'])!,
      originalUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}original_url'])!,
      imageUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}image_url']),
      sourceName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source_name'])!,
      sourceFaviconUrl: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}source_favicon_url']),
      publishedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}published_at'])!,
      category: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category'])!,
      isPaywalled: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_paywalled'])!,
      clusterId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}cluster_id']),
    );
  }

  @override
  $NewsArticlesTableTable createAlias(String alias) {
    return $NewsArticlesTableTable(attachedDatabase, alias);
  }
}

class NewsArticlesTableData extends DataClass
    implements Insertable<NewsArticlesTableData> {
  final String id;
  final String title;
  final String summary;
  final String originalUrl;
  final String? imageUrl;
  final String sourceName;
  final String? sourceFaviconUrl;
  final DateTime publishedAt;
  final String category;
  final bool isPaywalled;
  final String? clusterId;
  const NewsArticlesTableData(
      {required this.id,
      required this.title,
      required this.summary,
      required this.originalUrl,
      this.imageUrl,
      required this.sourceName,
      this.sourceFaviconUrl,
      required this.publishedAt,
      required this.category,
      required this.isPaywalled,
      this.clusterId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['summary'] = Variable<String>(summary);
    map['original_url'] = Variable<String>(originalUrl);
    if (!nullToAbsent || imageUrl != null) {
      map['image_url'] = Variable<String>(imageUrl);
    }
    map['source_name'] = Variable<String>(sourceName);
    if (!nullToAbsent || sourceFaviconUrl != null) {
      map['source_favicon_url'] = Variable<String>(sourceFaviconUrl);
    }
    map['published_at'] = Variable<DateTime>(publishedAt);
    map['category'] = Variable<String>(category);
    map['is_paywalled'] = Variable<bool>(isPaywalled);
    if (!nullToAbsent || clusterId != null) {
      map['cluster_id'] = Variable<String>(clusterId);
    }
    return map;
  }

  NewsArticlesTableCompanion toCompanion(bool nullToAbsent) {
    return NewsArticlesTableCompanion(
      id: Value(id),
      title: Value(title),
      summary: Value(summary),
      originalUrl: Value(originalUrl),
      imageUrl: imageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(imageUrl),
      sourceName: Value(sourceName),
      sourceFaviconUrl: sourceFaviconUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceFaviconUrl),
      publishedAt: Value(publishedAt),
      category: Value(category),
      isPaywalled: Value(isPaywalled),
      clusterId: clusterId == null && nullToAbsent
          ? const Value.absent()
          : Value(clusterId),
    );
  }

  factory NewsArticlesTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NewsArticlesTableData(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      summary: serializer.fromJson<String>(json['summary']),
      originalUrl: serializer.fromJson<String>(json['originalUrl']),
      imageUrl: serializer.fromJson<String?>(json['imageUrl']),
      sourceName: serializer.fromJson<String>(json['sourceName']),
      sourceFaviconUrl: serializer.fromJson<String?>(json['sourceFaviconUrl']),
      publishedAt: serializer.fromJson<DateTime>(json['publishedAt']),
      category: serializer.fromJson<String>(json['category']),
      isPaywalled: serializer.fromJson<bool>(json['isPaywalled']),
      clusterId: serializer.fromJson<String?>(json['clusterId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'summary': serializer.toJson<String>(summary),
      'originalUrl': serializer.toJson<String>(originalUrl),
      'imageUrl': serializer.toJson<String?>(imageUrl),
      'sourceName': serializer.toJson<String>(sourceName),
      'sourceFaviconUrl': serializer.toJson<String?>(sourceFaviconUrl),
      'publishedAt': serializer.toJson<DateTime>(publishedAt),
      'category': serializer.toJson<String>(category),
      'isPaywalled': serializer.toJson<bool>(isPaywalled),
      'clusterId': serializer.toJson<String?>(clusterId),
    };
  }

  NewsArticlesTableData copyWith(
          {String? id,
          String? title,
          String? summary,
          String? originalUrl,
          Value<String?> imageUrl = const Value.absent(),
          String? sourceName,
          Value<String?> sourceFaviconUrl = const Value.absent(),
          DateTime? publishedAt,
          String? category,
          bool? isPaywalled,
          Value<String?> clusterId = const Value.absent()}) =>
      NewsArticlesTableData(
        id: id ?? this.id,
        title: title ?? this.title,
        summary: summary ?? this.summary,
        originalUrl: originalUrl ?? this.originalUrl,
        imageUrl: imageUrl.present ? imageUrl.value : this.imageUrl,
        sourceName: sourceName ?? this.sourceName,
        sourceFaviconUrl: sourceFaviconUrl.present
            ? sourceFaviconUrl.value
            : this.sourceFaviconUrl,
        publishedAt: publishedAt ?? this.publishedAt,
        category: category ?? this.category,
        isPaywalled: isPaywalled ?? this.isPaywalled,
        clusterId: clusterId.present ? clusterId.value : this.clusterId,
      );
  NewsArticlesTableData copyWithCompanion(NewsArticlesTableCompanion data) {
    return NewsArticlesTableData(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      summary: data.summary.present ? data.summary.value : this.summary,
      originalUrl:
          data.originalUrl.present ? data.originalUrl.value : this.originalUrl,
      imageUrl: data.imageUrl.present ? data.imageUrl.value : this.imageUrl,
      sourceName:
          data.sourceName.present ? data.sourceName.value : this.sourceName,
      sourceFaviconUrl: data.sourceFaviconUrl.present
          ? data.sourceFaviconUrl.value
          : this.sourceFaviconUrl,
      publishedAt:
          data.publishedAt.present ? data.publishedAt.value : this.publishedAt,
      category: data.category.present ? data.category.value : this.category,
      isPaywalled:
          data.isPaywalled.present ? data.isPaywalled.value : this.isPaywalled,
      clusterId: data.clusterId.present ? data.clusterId.value : this.clusterId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NewsArticlesTableData(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('summary: $summary, ')
          ..write('originalUrl: $originalUrl, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('sourceName: $sourceName, ')
          ..write('sourceFaviconUrl: $sourceFaviconUrl, ')
          ..write('publishedAt: $publishedAt, ')
          ..write('category: $category, ')
          ..write('isPaywalled: $isPaywalled, ')
          ..write('clusterId: $clusterId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      title,
      summary,
      originalUrl,
      imageUrl,
      sourceName,
      sourceFaviconUrl,
      publishedAt,
      category,
      isPaywalled,
      clusterId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NewsArticlesTableData &&
          other.id == this.id &&
          other.title == this.title &&
          other.summary == this.summary &&
          other.originalUrl == this.originalUrl &&
          other.imageUrl == this.imageUrl &&
          other.sourceName == this.sourceName &&
          other.sourceFaviconUrl == this.sourceFaviconUrl &&
          other.publishedAt == this.publishedAt &&
          other.category == this.category &&
          other.isPaywalled == this.isPaywalled &&
          other.clusterId == this.clusterId);
}

class NewsArticlesTableCompanion
    extends UpdateCompanion<NewsArticlesTableData> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> summary;
  final Value<String> originalUrl;
  final Value<String?> imageUrl;
  final Value<String> sourceName;
  final Value<String?> sourceFaviconUrl;
  final Value<DateTime> publishedAt;
  final Value<String> category;
  final Value<bool> isPaywalled;
  final Value<String?> clusterId;
  final Value<int> rowid;
  const NewsArticlesTableCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.summary = const Value.absent(),
    this.originalUrl = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.sourceName = const Value.absent(),
    this.sourceFaviconUrl = const Value.absent(),
    this.publishedAt = const Value.absent(),
    this.category = const Value.absent(),
    this.isPaywalled = const Value.absent(),
    this.clusterId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NewsArticlesTableCompanion.insert({
    required String id,
    required String title,
    required String summary,
    required String originalUrl,
    this.imageUrl = const Value.absent(),
    required String sourceName,
    this.sourceFaviconUrl = const Value.absent(),
    required DateTime publishedAt,
    this.category = const Value.absent(),
    this.isPaywalled = const Value.absent(),
    this.clusterId = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        title = Value(title),
        summary = Value(summary),
        originalUrl = Value(originalUrl),
        sourceName = Value(sourceName),
        publishedAt = Value(publishedAt);
  static Insertable<NewsArticlesTableData> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? summary,
    Expression<String>? originalUrl,
    Expression<String>? imageUrl,
    Expression<String>? sourceName,
    Expression<String>? sourceFaviconUrl,
    Expression<DateTime>? publishedAt,
    Expression<String>? category,
    Expression<bool>? isPaywalled,
    Expression<String>? clusterId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (summary != null) 'summary': summary,
      if (originalUrl != null) 'original_url': originalUrl,
      if (imageUrl != null) 'image_url': imageUrl,
      if (sourceName != null) 'source_name': sourceName,
      if (sourceFaviconUrl != null) 'source_favicon_url': sourceFaviconUrl,
      if (publishedAt != null) 'published_at': publishedAt,
      if (category != null) 'category': category,
      if (isPaywalled != null) 'is_paywalled': isPaywalled,
      if (clusterId != null) 'cluster_id': clusterId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NewsArticlesTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? title,
      Value<String>? summary,
      Value<String>? originalUrl,
      Value<String?>? imageUrl,
      Value<String>? sourceName,
      Value<String?>? sourceFaviconUrl,
      Value<DateTime>? publishedAt,
      Value<String>? category,
      Value<bool>? isPaywalled,
      Value<String?>? clusterId,
      Value<int>? rowid}) {
    return NewsArticlesTableCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      originalUrl: originalUrl ?? this.originalUrl,
      imageUrl: imageUrl ?? this.imageUrl,
      sourceName: sourceName ?? this.sourceName,
      sourceFaviconUrl: sourceFaviconUrl ?? this.sourceFaviconUrl,
      publishedAt: publishedAt ?? this.publishedAt,
      category: category ?? this.category,
      isPaywalled: isPaywalled ?? this.isPaywalled,
      clusterId: clusterId ?? this.clusterId,
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
    if (summary.present) {
      map['summary'] = Variable<String>(summary.value);
    }
    if (originalUrl.present) {
      map['original_url'] = Variable<String>(originalUrl.value);
    }
    if (imageUrl.present) {
      map['image_url'] = Variable<String>(imageUrl.value);
    }
    if (sourceName.present) {
      map['source_name'] = Variable<String>(sourceName.value);
    }
    if (sourceFaviconUrl.present) {
      map['source_favicon_url'] = Variable<String>(sourceFaviconUrl.value);
    }
    if (publishedAt.present) {
      map['published_at'] = Variable<DateTime>(publishedAt.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (isPaywalled.present) {
      map['is_paywalled'] = Variable<bool>(isPaywalled.value);
    }
    if (clusterId.present) {
      map['cluster_id'] = Variable<String>(clusterId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NewsArticlesTableCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('summary: $summary, ')
          ..write('originalUrl: $originalUrl, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('sourceName: $sourceName, ')
          ..write('sourceFaviconUrl: $sourceFaviconUrl, ')
          ..write('publishedAt: $publishedAt, ')
          ..write('category: $category, ')
          ..write('isPaywalled: $isPaywalled, ')
          ..write('clusterId: $clusterId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $NewsArticlesTableTable newsArticlesTable =
      $NewsArticlesTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [newsArticlesTable];
}

typedef $$NewsArticlesTableTableCreateCompanionBuilder
    = NewsArticlesTableCompanion Function({
  required String id,
  required String title,
  required String summary,
  required String originalUrl,
  Value<String?> imageUrl,
  required String sourceName,
  Value<String?> sourceFaviconUrl,
  required DateTime publishedAt,
  Value<String> category,
  Value<bool> isPaywalled,
  Value<String?> clusterId,
  Value<int> rowid,
});
typedef $$NewsArticlesTableTableUpdateCompanionBuilder
    = NewsArticlesTableCompanion Function({
  Value<String> id,
  Value<String> title,
  Value<String> summary,
  Value<String> originalUrl,
  Value<String?> imageUrl,
  Value<String> sourceName,
  Value<String?> sourceFaviconUrl,
  Value<DateTime> publishedAt,
  Value<String> category,
  Value<bool> isPaywalled,
  Value<String?> clusterId,
  Value<int> rowid,
});

class $$NewsArticlesTableTableFilterComposer
    extends Composer<_$AppDatabase, $NewsArticlesTableTable> {
  $$NewsArticlesTableTableFilterComposer({
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

  ColumnFilters<String> get summary => $composableBuilder(
      column: $table.summary, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get originalUrl => $composableBuilder(
      column: $table.originalUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get imageUrl => $composableBuilder(
      column: $table.imageUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sourceName => $composableBuilder(
      column: $table.sourceName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sourceFaviconUrl => $composableBuilder(
      column: $table.sourceFaviconUrl,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get publishedAt => $composableBuilder(
      column: $table.publishedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isPaywalled => $composableBuilder(
      column: $table.isPaywalled, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get clusterId => $composableBuilder(
      column: $table.clusterId, builder: (column) => ColumnFilters(column));
}

class $$NewsArticlesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $NewsArticlesTableTable> {
  $$NewsArticlesTableTableOrderingComposer({
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

  ColumnOrderings<String> get summary => $composableBuilder(
      column: $table.summary, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get originalUrl => $composableBuilder(
      column: $table.originalUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get imageUrl => $composableBuilder(
      column: $table.imageUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sourceName => $composableBuilder(
      column: $table.sourceName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sourceFaviconUrl => $composableBuilder(
      column: $table.sourceFaviconUrl,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get publishedAt => $composableBuilder(
      column: $table.publishedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isPaywalled => $composableBuilder(
      column: $table.isPaywalled, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get clusterId => $composableBuilder(
      column: $table.clusterId, builder: (column) => ColumnOrderings(column));
}

class $$NewsArticlesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $NewsArticlesTableTable> {
  $$NewsArticlesTableTableAnnotationComposer({
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

  GeneratedColumn<String> get summary =>
      $composableBuilder(column: $table.summary, builder: (column) => column);

  GeneratedColumn<String> get originalUrl => $composableBuilder(
      column: $table.originalUrl, builder: (column) => column);

  GeneratedColumn<String> get imageUrl =>
      $composableBuilder(column: $table.imageUrl, builder: (column) => column);

  GeneratedColumn<String> get sourceName => $composableBuilder(
      column: $table.sourceName, builder: (column) => column);

  GeneratedColumn<String> get sourceFaviconUrl => $composableBuilder(
      column: $table.sourceFaviconUrl, builder: (column) => column);

  GeneratedColumn<DateTime> get publishedAt => $composableBuilder(
      column: $table.publishedAt, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<bool> get isPaywalled => $composableBuilder(
      column: $table.isPaywalled, builder: (column) => column);

  GeneratedColumn<String> get clusterId =>
      $composableBuilder(column: $table.clusterId, builder: (column) => column);
}

class $$NewsArticlesTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $NewsArticlesTableTable,
    NewsArticlesTableData,
    $$NewsArticlesTableTableFilterComposer,
    $$NewsArticlesTableTableOrderingComposer,
    $$NewsArticlesTableTableAnnotationComposer,
    $$NewsArticlesTableTableCreateCompanionBuilder,
    $$NewsArticlesTableTableUpdateCompanionBuilder,
    (
      NewsArticlesTableData,
      BaseReferences<_$AppDatabase, $NewsArticlesTableTable,
          NewsArticlesTableData>
    ),
    NewsArticlesTableData,
    PrefetchHooks Function()> {
  $$NewsArticlesTableTableTableManager(
      _$AppDatabase db, $NewsArticlesTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NewsArticlesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NewsArticlesTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NewsArticlesTableTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String> summary = const Value.absent(),
            Value<String> originalUrl = const Value.absent(),
            Value<String?> imageUrl = const Value.absent(),
            Value<String> sourceName = const Value.absent(),
            Value<String?> sourceFaviconUrl = const Value.absent(),
            Value<DateTime> publishedAt = const Value.absent(),
            Value<String> category = const Value.absent(),
            Value<bool> isPaywalled = const Value.absent(),
            Value<String?> clusterId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              NewsArticlesTableCompanion(
            id: id,
            title: title,
            summary: summary,
            originalUrl: originalUrl,
            imageUrl: imageUrl,
            sourceName: sourceName,
            sourceFaviconUrl: sourceFaviconUrl,
            publishedAt: publishedAt,
            category: category,
            isPaywalled: isPaywalled,
            clusterId: clusterId,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String title,
            required String summary,
            required String originalUrl,
            Value<String?> imageUrl = const Value.absent(),
            required String sourceName,
            Value<String?> sourceFaviconUrl = const Value.absent(),
            required DateTime publishedAt,
            Value<String> category = const Value.absent(),
            Value<bool> isPaywalled = const Value.absent(),
            Value<String?> clusterId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              NewsArticlesTableCompanion.insert(
            id: id,
            title: title,
            summary: summary,
            originalUrl: originalUrl,
            imageUrl: imageUrl,
            sourceName: sourceName,
            sourceFaviconUrl: sourceFaviconUrl,
            publishedAt: publishedAt,
            category: category,
            isPaywalled: isPaywalled,
            clusterId: clusterId,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$NewsArticlesTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $NewsArticlesTableTable,
    NewsArticlesTableData,
    $$NewsArticlesTableTableFilterComposer,
    $$NewsArticlesTableTableOrderingComposer,
    $$NewsArticlesTableTableAnnotationComposer,
    $$NewsArticlesTableTableCreateCompanionBuilder,
    $$NewsArticlesTableTableUpdateCompanionBuilder,
    (
      NewsArticlesTableData,
      BaseReferences<_$AppDatabase, $NewsArticlesTableTable,
          NewsArticlesTableData>
    ),
    NewsArticlesTableData,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$NewsArticlesTableTableTableManager get newsArticlesTable =>
      $$NewsArticlesTableTableTableManager(_db, _db.newsArticlesTable);
}
