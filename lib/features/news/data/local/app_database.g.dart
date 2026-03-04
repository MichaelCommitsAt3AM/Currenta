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
  @override
  late final GeneratedColumnWithTypeConverter<List<NewsCategory>, String>
      categories = GeneratedColumn<String>('categories', aliasedName, false,
              type: DriftSqlType.string,
              requiredDuringInsert: false,
              defaultValue: const Constant('["world"]'))
          .withConverter<List<NewsCategory>>(
              $NewsArticlesTableTable.$convertercategories);
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
  static const VerificationMeta _isLikedMeta =
      const VerificationMeta('isLiked');
  @override
  late final GeneratedColumn<bool> isLiked = GeneratedColumn<bool>(
      'is_liked', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_liked" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _likesCountMeta =
      const VerificationMeta('likesCount');
  @override
  late final GeneratedColumn<int> likesCount = GeneratedColumn<int>(
      'likes_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
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
        categories,
        isPaywalled,
        isLiked,
        likesCount,
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
    if (data.containsKey('is_paywalled')) {
      context.handle(
          _isPaywalledMeta,
          isPaywalled.isAcceptableOrUnknown(
              data['is_paywalled']!, _isPaywalledMeta));
    }
    if (data.containsKey('is_liked')) {
      context.handle(_isLikedMeta,
          isLiked.isAcceptableOrUnknown(data['is_liked']!, _isLikedMeta));
    }
    if (data.containsKey('likes_count')) {
      context.handle(
          _likesCountMeta,
          likesCount.isAcceptableOrUnknown(
              data['likes_count']!, _likesCountMeta));
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
      categories: $NewsArticlesTableTable.$convertercategories.fromSql(
          attachedDatabase.typeMapping.read(
              DriftSqlType.string, data['${effectivePrefix}categories'])!),
      isPaywalled: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_paywalled'])!,
      isLiked: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_liked'])!,
      likesCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}likes_count'])!,
      clusterId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}cluster_id']),
    );
  }

  @override
  $NewsArticlesTableTable createAlias(String alias) {
    return $NewsArticlesTableTable(attachedDatabase, alias);
  }

  static TypeConverter<List<NewsCategory>, String> $convertercategories =
      const CategoryListConverter();
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

  /// Stored as a JSON-encoded list, e.g. '["tech","politics"]'
  final List<NewsCategory> categories;
  final bool isPaywalled;
  final bool isLiked;
  final int likesCount;
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
      required this.categories,
      required this.isPaywalled,
      required this.isLiked,
      required this.likesCount,
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
    {
      map['categories'] = Variable<String>(
          $NewsArticlesTableTable.$convertercategories.toSql(categories));
    }
    map['is_paywalled'] = Variable<bool>(isPaywalled);
    map['is_liked'] = Variable<bool>(isLiked);
    map['likes_count'] = Variable<int>(likesCount);
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
      categories: Value(categories),
      isPaywalled: Value(isPaywalled),
      isLiked: Value(isLiked),
      likesCount: Value(likesCount),
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
      categories: serializer.fromJson<List<NewsCategory>>(json['categories']),
      isPaywalled: serializer.fromJson<bool>(json['isPaywalled']),
      isLiked: serializer.fromJson<bool>(json['isLiked']),
      likesCount: serializer.fromJson<int>(json['likesCount']),
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
      'categories': serializer.toJson<List<NewsCategory>>(categories),
      'isPaywalled': serializer.toJson<bool>(isPaywalled),
      'isLiked': serializer.toJson<bool>(isLiked),
      'likesCount': serializer.toJson<int>(likesCount),
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
          List<NewsCategory>? categories,
          bool? isPaywalled,
          bool? isLiked,
          int? likesCount,
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
        categories: categories ?? this.categories,
        isPaywalled: isPaywalled ?? this.isPaywalled,
        isLiked: isLiked ?? this.isLiked,
        likesCount: likesCount ?? this.likesCount,
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
      categories:
          data.categories.present ? data.categories.value : this.categories,
      isPaywalled:
          data.isPaywalled.present ? data.isPaywalled.value : this.isPaywalled,
      isLiked: data.isLiked.present ? data.isLiked.value : this.isLiked,
      likesCount:
          data.likesCount.present ? data.likesCount.value : this.likesCount,
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
          ..write('categories: $categories, ')
          ..write('isPaywalled: $isPaywalled, ')
          ..write('isLiked: $isLiked, ')
          ..write('likesCount: $likesCount, ')
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
      categories,
      isPaywalled,
      isLiked,
      likesCount,
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
          other.categories == this.categories &&
          other.isPaywalled == this.isPaywalled &&
          other.isLiked == this.isLiked &&
          other.likesCount == this.likesCount &&
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
  final Value<List<NewsCategory>> categories;
  final Value<bool> isPaywalled;
  final Value<bool> isLiked;
  final Value<int> likesCount;
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
    this.categories = const Value.absent(),
    this.isPaywalled = const Value.absent(),
    this.isLiked = const Value.absent(),
    this.likesCount = const Value.absent(),
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
    this.categories = const Value.absent(),
    this.isPaywalled = const Value.absent(),
    this.isLiked = const Value.absent(),
    this.likesCount = const Value.absent(),
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
    Expression<String>? categories,
    Expression<bool>? isPaywalled,
    Expression<bool>? isLiked,
    Expression<int>? likesCount,
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
      if (categories != null) 'categories': categories,
      if (isPaywalled != null) 'is_paywalled': isPaywalled,
      if (isLiked != null) 'is_liked': isLiked,
      if (likesCount != null) 'likes_count': likesCount,
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
      Value<List<NewsCategory>>? categories,
      Value<bool>? isPaywalled,
      Value<bool>? isLiked,
      Value<int>? likesCount,
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
      categories: categories ?? this.categories,
      isPaywalled: isPaywalled ?? this.isPaywalled,
      isLiked: isLiked ?? this.isLiked,
      likesCount: likesCount ?? this.likesCount,
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
    if (categories.present) {
      map['categories'] = Variable<String>(
          $NewsArticlesTableTable.$convertercategories.toSql(categories.value));
    }
    if (isPaywalled.present) {
      map['is_paywalled'] = Variable<bool>(isPaywalled.value);
    }
    if (isLiked.present) {
      map['is_liked'] = Variable<bool>(isLiked.value);
    }
    if (likesCount.present) {
      map['likes_count'] = Variable<int>(likesCount.value);
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
          ..write('categories: $categories, ')
          ..write('isPaywalled: $isPaywalled, ')
          ..write('isLiked: $isLiked, ')
          ..write('likesCount: $likesCount, ')
          ..write('clusterId: $clusterId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ViewedArticlesTableTable extends ViewedArticlesTable
    with TableInfo<$ViewedArticlesTableTable, ViewedArticlesTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ViewedArticlesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _viewedAtMeta =
      const VerificationMeta('viewedAt');
  @override
  late final GeneratedColumn<DateTime> viewedAt = GeneratedColumn<DateTime>(
      'viewed_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [id, viewedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'viewed_articles';
  @override
  VerificationContext validateIntegrity(
      Insertable<ViewedArticlesTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('viewed_at')) {
      context.handle(_viewedAtMeta,
          viewedAt.isAcceptableOrUnknown(data['viewed_at']!, _viewedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ViewedArticlesTableData map(Map<String, dynamic> data,
      {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ViewedArticlesTableData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      viewedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}viewed_at'])!,
    );
  }

  @override
  $ViewedArticlesTableTable createAlias(String alias) {
    return $ViewedArticlesTableTable(attachedDatabase, alias);
  }
}

class ViewedArticlesTableData extends DataClass
    implements Insertable<ViewedArticlesTableData> {
  final String id;
  final DateTime viewedAt;
  const ViewedArticlesTableData({required this.id, required this.viewedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['viewed_at'] = Variable<DateTime>(viewedAt);
    return map;
  }

  ViewedArticlesTableCompanion toCompanion(bool nullToAbsent) {
    return ViewedArticlesTableCompanion(
      id: Value(id),
      viewedAt: Value(viewedAt),
    );
  }

  factory ViewedArticlesTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ViewedArticlesTableData(
      id: serializer.fromJson<String>(json['id']),
      viewedAt: serializer.fromJson<DateTime>(json['viewedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'viewedAt': serializer.toJson<DateTime>(viewedAt),
    };
  }

  ViewedArticlesTableData copyWith({String? id, DateTime? viewedAt}) =>
      ViewedArticlesTableData(
        id: id ?? this.id,
        viewedAt: viewedAt ?? this.viewedAt,
      );
  ViewedArticlesTableData copyWithCompanion(ViewedArticlesTableCompanion data) {
    return ViewedArticlesTableData(
      id: data.id.present ? data.id.value : this.id,
      viewedAt: data.viewedAt.present ? data.viewedAt.value : this.viewedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ViewedArticlesTableData(')
          ..write('id: $id, ')
          ..write('viewedAt: $viewedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, viewedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ViewedArticlesTableData &&
          other.id == this.id &&
          other.viewedAt == this.viewedAt);
}

class ViewedArticlesTableCompanion
    extends UpdateCompanion<ViewedArticlesTableData> {
  final Value<String> id;
  final Value<DateTime> viewedAt;
  final Value<int> rowid;
  const ViewedArticlesTableCompanion({
    this.id = const Value.absent(),
    this.viewedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ViewedArticlesTableCompanion.insert({
    required String id,
    this.viewedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id);
  static Insertable<ViewedArticlesTableData> custom({
    Expression<String>? id,
    Expression<DateTime>? viewedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (viewedAt != null) 'viewed_at': viewedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ViewedArticlesTableCompanion copyWith(
      {Value<String>? id, Value<DateTime>? viewedAt, Value<int>? rowid}) {
    return ViewedArticlesTableCompanion(
      id: id ?? this.id,
      viewedAt: viewedAt ?? this.viewedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (viewedAt.present) {
      map['viewed_at'] = Variable<DateTime>(viewedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ViewedArticlesTableCompanion(')
          ..write('id: $id, ')
          ..write('viewedAt: $viewedAt, ')
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
  late final $ViewedArticlesTableTable viewedArticlesTable =
      $ViewedArticlesTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [newsArticlesTable, viewedArticlesTable];
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
  Value<List<NewsCategory>> categories,
  Value<bool> isPaywalled,
  Value<bool> isLiked,
  Value<int> likesCount,
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
  Value<List<NewsCategory>> categories,
  Value<bool> isPaywalled,
  Value<bool> isLiked,
  Value<int> likesCount,
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

  ColumnWithTypeConverterFilters<List<NewsCategory>, List<NewsCategory>, String>
      get categories => $composableBuilder(
          column: $table.categories,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<bool> get isPaywalled => $composableBuilder(
      column: $table.isPaywalled, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isLiked => $composableBuilder(
      column: $table.isLiked, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get likesCount => $composableBuilder(
      column: $table.likesCount, builder: (column) => ColumnFilters(column));

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

  ColumnOrderings<String> get categories => $composableBuilder(
      column: $table.categories, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isPaywalled => $composableBuilder(
      column: $table.isPaywalled, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isLiked => $composableBuilder(
      column: $table.isLiked, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get likesCount => $composableBuilder(
      column: $table.likesCount, builder: (column) => ColumnOrderings(column));

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

  GeneratedColumnWithTypeConverter<List<NewsCategory>, String> get categories =>
      $composableBuilder(
          column: $table.categories, builder: (column) => column);

  GeneratedColumn<bool> get isPaywalled => $composableBuilder(
      column: $table.isPaywalled, builder: (column) => column);

  GeneratedColumn<bool> get isLiked =>
      $composableBuilder(column: $table.isLiked, builder: (column) => column);

  GeneratedColumn<int> get likesCount => $composableBuilder(
      column: $table.likesCount, builder: (column) => column);

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
            Value<List<NewsCategory>> categories = const Value.absent(),
            Value<bool> isPaywalled = const Value.absent(),
            Value<bool> isLiked = const Value.absent(),
            Value<int> likesCount = const Value.absent(),
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
            categories: categories,
            isPaywalled: isPaywalled,
            isLiked: isLiked,
            likesCount: likesCount,
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
            Value<List<NewsCategory>> categories = const Value.absent(),
            Value<bool> isPaywalled = const Value.absent(),
            Value<bool> isLiked = const Value.absent(),
            Value<int> likesCount = const Value.absent(),
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
            categories: categories,
            isPaywalled: isPaywalled,
            isLiked: isLiked,
            likesCount: likesCount,
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
typedef $$ViewedArticlesTableTableCreateCompanionBuilder
    = ViewedArticlesTableCompanion Function({
  required String id,
  Value<DateTime> viewedAt,
  Value<int> rowid,
});
typedef $$ViewedArticlesTableTableUpdateCompanionBuilder
    = ViewedArticlesTableCompanion Function({
  Value<String> id,
  Value<DateTime> viewedAt,
  Value<int> rowid,
});

class $$ViewedArticlesTableTableFilterComposer
    extends Composer<_$AppDatabase, $ViewedArticlesTableTable> {
  $$ViewedArticlesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get viewedAt => $composableBuilder(
      column: $table.viewedAt, builder: (column) => ColumnFilters(column));
}

class $$ViewedArticlesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $ViewedArticlesTableTable> {
  $$ViewedArticlesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get viewedAt => $composableBuilder(
      column: $table.viewedAt, builder: (column) => ColumnOrderings(column));
}

class $$ViewedArticlesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $ViewedArticlesTableTable> {
  $$ViewedArticlesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get viewedAt =>
      $composableBuilder(column: $table.viewedAt, builder: (column) => column);
}

class $$ViewedArticlesTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ViewedArticlesTableTable,
    ViewedArticlesTableData,
    $$ViewedArticlesTableTableFilterComposer,
    $$ViewedArticlesTableTableOrderingComposer,
    $$ViewedArticlesTableTableAnnotationComposer,
    $$ViewedArticlesTableTableCreateCompanionBuilder,
    $$ViewedArticlesTableTableUpdateCompanionBuilder,
    (
      ViewedArticlesTableData,
      BaseReferences<_$AppDatabase, $ViewedArticlesTableTable,
          ViewedArticlesTableData>
    ),
    ViewedArticlesTableData,
    PrefetchHooks Function()> {
  $$ViewedArticlesTableTableTableManager(
      _$AppDatabase db, $ViewedArticlesTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ViewedArticlesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ViewedArticlesTableTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ViewedArticlesTableTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<DateTime> viewedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ViewedArticlesTableCompanion(
            id: id,
            viewedAt: viewedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            Value<DateTime> viewedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ViewedArticlesTableCompanion.insert(
            id: id,
            viewedAt: viewedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ViewedArticlesTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ViewedArticlesTableTable,
    ViewedArticlesTableData,
    $$ViewedArticlesTableTableFilterComposer,
    $$ViewedArticlesTableTableOrderingComposer,
    $$ViewedArticlesTableTableAnnotationComposer,
    $$ViewedArticlesTableTableCreateCompanionBuilder,
    $$ViewedArticlesTableTableUpdateCompanionBuilder,
    (
      ViewedArticlesTableData,
      BaseReferences<_$AppDatabase, $ViewedArticlesTableTable,
          ViewedArticlesTableData>
    ),
    ViewedArticlesTableData,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$NewsArticlesTableTableTableManager get newsArticlesTable =>
      $$NewsArticlesTableTableTableManager(_db, _db.newsArticlesTable);
  $$ViewedArticlesTableTableTableManager get viewedArticlesTable =>
      $$ViewedArticlesTableTableTableManager(_db, _db.viewedArticlesTable);
}
