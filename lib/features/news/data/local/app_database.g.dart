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
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  late final GeneratedColumnWithTypeConverter<List<NewsCategory>, String>
      categories = GeneratedColumn<String>('categories', aliasedName, false,
              type: DriftSqlType.string,
              requiredDuringInsert: false,
              defaultValue: const Constant('["world"]'))
          .withConverter<List<NewsCategory>>(
              $NewsArticlesTableTable.$convertercategories);
  @override
  late final GeneratedColumnWithTypeConverter<List<NewsSubCategory>, String>
      subCategories = GeneratedColumn<String>(
              'sub_categories', aliasedName, false,
              type: DriftSqlType.string,
              requiredDuringInsert: false,
              defaultValue: const Constant('[]'))
          .withConverter<List<NewsSubCategory>>(
              $NewsArticlesTableTable.$convertersubCategories);
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
  static const VerificationMeta _isFavoritedMeta =
      const VerificationMeta('isFavorited');
  @override
  late final GeneratedColumn<bool> isFavorited = GeneratedColumn<bool>(
      'is_favorited', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_favorited" IN (0, 1))'),
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
  static const VerificationMeta _countryCodeMeta =
      const VerificationMeta('countryCode');
  @override
  late final GeneratedColumn<String> countryCode = GeneratedColumn<String>(
      'country_code', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _trendScoreMeta =
      const VerificationMeta('trendScore');
  @override
  late final GeneratedColumn<double> trendScore = GeneratedColumn<double>(
      'trend_score', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0.0));
  static const VerificationMeta _lastTrendUpdateMeta =
      const VerificationMeta('lastTrendUpdate');
  @override
  late final GeneratedColumn<DateTime> lastTrendUpdate =
      GeneratedColumn<DateTime>('last_trend_update', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _rankingScoreMeta =
      const VerificationMeta('rankingScore');
  @override
  late final GeneratedColumn<double> rankingScore = GeneratedColumn<double>(
      'ranking_score', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0.0));
  static const VerificationMeta _isMajorSourceMeta =
      const VerificationMeta('isMajorSource');
  @override
  late final GeneratedColumn<bool> isMajorSource = GeneratedColumn<bool>(
      'is_major_source', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_major_source" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _expiresAtMeta =
      const VerificationMeta('expiresAt');
  @override
  late final GeneratedColumn<DateTime> expiresAt = GeneratedColumn<DateTime>(
      'expires_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _primarySubcategorySlugMeta =
      const VerificationMeta('primarySubcategorySlug');
  @override
  late final GeneratedColumn<String> primarySubcategorySlug =
      GeneratedColumn<String>('primary_subcategory_slug', aliasedName, true,
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
        createdAt,
        categories,
        subCategories,
        isPaywalled,
        isLiked,
        isFavorited,
        likesCount,
        clusterId,
        countryCode,
        trendScore,
        lastTrendUpdate,
        rankingScore,
        isMajorSource,
        expiresAt,
        primarySubcategorySlug
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
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
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
    if (data.containsKey('is_favorited')) {
      context.handle(
          _isFavoritedMeta,
          isFavorited.isAcceptableOrUnknown(
              data['is_favorited']!, _isFavoritedMeta));
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
    if (data.containsKey('country_code')) {
      context.handle(
          _countryCodeMeta,
          countryCode.isAcceptableOrUnknown(
              data['country_code']!, _countryCodeMeta));
    }
    if (data.containsKey('trend_score')) {
      context.handle(
          _trendScoreMeta,
          trendScore.isAcceptableOrUnknown(
              data['trend_score']!, _trendScoreMeta));
    }
    if (data.containsKey('last_trend_update')) {
      context.handle(
          _lastTrendUpdateMeta,
          lastTrendUpdate.isAcceptableOrUnknown(
              data['last_trend_update']!, _lastTrendUpdateMeta));
    }
    if (data.containsKey('ranking_score')) {
      context.handle(
          _rankingScoreMeta,
          rankingScore.isAcceptableOrUnknown(
              data['ranking_score']!, _rankingScoreMeta));
    }
    if (data.containsKey('is_major_source')) {
      context.handle(
          _isMajorSourceMeta,
          isMajorSource.isAcceptableOrUnknown(
              data['is_major_source']!, _isMajorSourceMeta));
    }
    if (data.containsKey('expires_at')) {
      context.handle(_expiresAtMeta,
          expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta));
    }
    if (data.containsKey('primary_subcategory_slug')) {
      context.handle(
          _primarySubcategorySlugMeta,
          primarySubcategorySlug.isAcceptableOrUnknown(
              data['primary_subcategory_slug']!, _primarySubcategorySlugMeta));
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
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      categories: $NewsArticlesTableTable.$convertercategories.fromSql(
          attachedDatabase.typeMapping.read(
              DriftSqlType.string, data['${effectivePrefix}categories'])!),
      subCategories: $NewsArticlesTableTable.$convertersubCategories.fromSql(
          attachedDatabase.typeMapping.read(
              DriftSqlType.string, data['${effectivePrefix}sub_categories'])!),
      isPaywalled: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_paywalled'])!,
      isLiked: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_liked'])!,
      isFavorited: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_favorited'])!,
      likesCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}likes_count'])!,
      clusterId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}cluster_id']),
      countryCode: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}country_code']),
      trendScore: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}trend_score'])!,
      lastTrendUpdate: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_trend_update']),
      rankingScore: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}ranking_score'])!,
      isMajorSource: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_major_source'])!,
      expiresAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}expires_at']),
      primarySubcategorySlug: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}primary_subcategory_slug']),
    );
  }

  @override
  $NewsArticlesTableTable createAlias(String alias) {
    return $NewsArticlesTableTable(attachedDatabase, alias);
  }

  static TypeConverter<List<NewsCategory>, String> $convertercategories =
      const CategoryListConverter();
  static TypeConverter<List<NewsSubCategory>, String> $convertersubCategories =
      const SubCategoryListConverter();
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
  final DateTime createdAt;

  /// Stored as a JSON-encoded list, e.g. '["tech","politics"]'
  final List<NewsCategory> categories;

  /// Fine-grained sub-categories
  final List<NewsSubCategory> subCategories;
  final bool isPaywalled;
  final bool isLiked;
  final bool isFavorited;
  final int likesCount;
  final String? clusterId;
  final String? countryCode;
  final double trendScore;
  final DateTime? lastTrendUpdate;
  final double rankingScore;
  final bool isMajorSource;
  final DateTime? expiresAt;

  /// Raw canonical taxonomy slug (e.g. 'ai_research') — see
  /// NewsArticle.primarySubcategorySlug for why this exists alongside the
  /// (currently unusable) subCategories column above.
  final String? primarySubcategorySlug;
  const NewsArticlesTableData(
      {required this.id,
      required this.title,
      required this.summary,
      required this.originalUrl,
      this.imageUrl,
      required this.sourceName,
      this.sourceFaviconUrl,
      required this.publishedAt,
      required this.createdAt,
      required this.categories,
      required this.subCategories,
      required this.isPaywalled,
      required this.isLiked,
      required this.isFavorited,
      required this.likesCount,
      this.clusterId,
      this.countryCode,
      required this.trendScore,
      this.lastTrendUpdate,
      required this.rankingScore,
      required this.isMajorSource,
      this.expiresAt,
      this.primarySubcategorySlug});
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
    map['created_at'] = Variable<DateTime>(createdAt);
    {
      map['categories'] = Variable<String>(
          $NewsArticlesTableTable.$convertercategories.toSql(categories));
    }
    {
      map['sub_categories'] = Variable<String>(
          $NewsArticlesTableTable.$convertersubCategories.toSql(subCategories));
    }
    map['is_paywalled'] = Variable<bool>(isPaywalled);
    map['is_liked'] = Variable<bool>(isLiked);
    map['is_favorited'] = Variable<bool>(isFavorited);
    map['likes_count'] = Variable<int>(likesCount);
    if (!nullToAbsent || clusterId != null) {
      map['cluster_id'] = Variable<String>(clusterId);
    }
    if (!nullToAbsent || countryCode != null) {
      map['country_code'] = Variable<String>(countryCode);
    }
    map['trend_score'] = Variable<double>(trendScore);
    if (!nullToAbsent || lastTrendUpdate != null) {
      map['last_trend_update'] = Variable<DateTime>(lastTrendUpdate);
    }
    map['ranking_score'] = Variable<double>(rankingScore);
    map['is_major_source'] = Variable<bool>(isMajorSource);
    if (!nullToAbsent || expiresAt != null) {
      map['expires_at'] = Variable<DateTime>(expiresAt);
    }
    if (!nullToAbsent || primarySubcategorySlug != null) {
      map['primary_subcategory_slug'] =
          Variable<String>(primarySubcategorySlug);
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
      createdAt: Value(createdAt),
      categories: Value(categories),
      subCategories: Value(subCategories),
      isPaywalled: Value(isPaywalled),
      isLiked: Value(isLiked),
      isFavorited: Value(isFavorited),
      likesCount: Value(likesCount),
      clusterId: clusterId == null && nullToAbsent
          ? const Value.absent()
          : Value(clusterId),
      countryCode: countryCode == null && nullToAbsent
          ? const Value.absent()
          : Value(countryCode),
      trendScore: Value(trendScore),
      lastTrendUpdate: lastTrendUpdate == null && nullToAbsent
          ? const Value.absent()
          : Value(lastTrendUpdate),
      rankingScore: Value(rankingScore),
      isMajorSource: Value(isMajorSource),
      expiresAt: expiresAt == null && nullToAbsent
          ? const Value.absent()
          : Value(expiresAt),
      primarySubcategorySlug: primarySubcategorySlug == null && nullToAbsent
          ? const Value.absent()
          : Value(primarySubcategorySlug),
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
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      categories: serializer.fromJson<List<NewsCategory>>(json['categories']),
      subCategories:
          serializer.fromJson<List<NewsSubCategory>>(json['subCategories']),
      isPaywalled: serializer.fromJson<bool>(json['isPaywalled']),
      isLiked: serializer.fromJson<bool>(json['isLiked']),
      isFavorited: serializer.fromJson<bool>(json['isFavorited']),
      likesCount: serializer.fromJson<int>(json['likesCount']),
      clusterId: serializer.fromJson<String?>(json['clusterId']),
      countryCode: serializer.fromJson<String?>(json['countryCode']),
      trendScore: serializer.fromJson<double>(json['trendScore']),
      lastTrendUpdate: serializer.fromJson<DateTime?>(json['lastTrendUpdate']),
      rankingScore: serializer.fromJson<double>(json['rankingScore']),
      isMajorSource: serializer.fromJson<bool>(json['isMajorSource']),
      expiresAt: serializer.fromJson<DateTime?>(json['expiresAt']),
      primarySubcategorySlug:
          serializer.fromJson<String?>(json['primarySubcategorySlug']),
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
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'categories': serializer.toJson<List<NewsCategory>>(categories),
      'subCategories': serializer.toJson<List<NewsSubCategory>>(subCategories),
      'isPaywalled': serializer.toJson<bool>(isPaywalled),
      'isLiked': serializer.toJson<bool>(isLiked),
      'isFavorited': serializer.toJson<bool>(isFavorited),
      'likesCount': serializer.toJson<int>(likesCount),
      'clusterId': serializer.toJson<String?>(clusterId),
      'countryCode': serializer.toJson<String?>(countryCode),
      'trendScore': serializer.toJson<double>(trendScore),
      'lastTrendUpdate': serializer.toJson<DateTime?>(lastTrendUpdate),
      'rankingScore': serializer.toJson<double>(rankingScore),
      'isMajorSource': serializer.toJson<bool>(isMajorSource),
      'expiresAt': serializer.toJson<DateTime?>(expiresAt),
      'primarySubcategorySlug':
          serializer.toJson<String?>(primarySubcategorySlug),
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
          DateTime? createdAt,
          List<NewsCategory>? categories,
          List<NewsSubCategory>? subCategories,
          bool? isPaywalled,
          bool? isLiked,
          bool? isFavorited,
          int? likesCount,
          Value<String?> clusterId = const Value.absent(),
          Value<String?> countryCode = const Value.absent(),
          double? trendScore,
          Value<DateTime?> lastTrendUpdate = const Value.absent(),
          double? rankingScore,
          bool? isMajorSource,
          Value<DateTime?> expiresAt = const Value.absent(),
          Value<String?> primarySubcategorySlug = const Value.absent()}) =>
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
        createdAt: createdAt ?? this.createdAt,
        categories: categories ?? this.categories,
        subCategories: subCategories ?? this.subCategories,
        isPaywalled: isPaywalled ?? this.isPaywalled,
        isLiked: isLiked ?? this.isLiked,
        isFavorited: isFavorited ?? this.isFavorited,
        likesCount: likesCount ?? this.likesCount,
        clusterId: clusterId.present ? clusterId.value : this.clusterId,
        countryCode: countryCode.present ? countryCode.value : this.countryCode,
        trendScore: trendScore ?? this.trendScore,
        lastTrendUpdate: lastTrendUpdate.present
            ? lastTrendUpdate.value
            : this.lastTrendUpdate,
        rankingScore: rankingScore ?? this.rankingScore,
        isMajorSource: isMajorSource ?? this.isMajorSource,
        expiresAt: expiresAt.present ? expiresAt.value : this.expiresAt,
        primarySubcategorySlug: primarySubcategorySlug.present
            ? primarySubcategorySlug.value
            : this.primarySubcategorySlug,
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
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      categories:
          data.categories.present ? data.categories.value : this.categories,
      subCategories: data.subCategories.present
          ? data.subCategories.value
          : this.subCategories,
      isPaywalled:
          data.isPaywalled.present ? data.isPaywalled.value : this.isPaywalled,
      isLiked: data.isLiked.present ? data.isLiked.value : this.isLiked,
      isFavorited:
          data.isFavorited.present ? data.isFavorited.value : this.isFavorited,
      likesCount:
          data.likesCount.present ? data.likesCount.value : this.likesCount,
      clusterId: data.clusterId.present ? data.clusterId.value : this.clusterId,
      countryCode:
          data.countryCode.present ? data.countryCode.value : this.countryCode,
      trendScore:
          data.trendScore.present ? data.trendScore.value : this.trendScore,
      lastTrendUpdate: data.lastTrendUpdate.present
          ? data.lastTrendUpdate.value
          : this.lastTrendUpdate,
      rankingScore: data.rankingScore.present
          ? data.rankingScore.value
          : this.rankingScore,
      isMajorSource: data.isMajorSource.present
          ? data.isMajorSource.value
          : this.isMajorSource,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
      primarySubcategorySlug: data.primarySubcategorySlug.present
          ? data.primarySubcategorySlug.value
          : this.primarySubcategorySlug,
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
          ..write('createdAt: $createdAt, ')
          ..write('categories: $categories, ')
          ..write('subCategories: $subCategories, ')
          ..write('isPaywalled: $isPaywalled, ')
          ..write('isLiked: $isLiked, ')
          ..write('isFavorited: $isFavorited, ')
          ..write('likesCount: $likesCount, ')
          ..write('clusterId: $clusterId, ')
          ..write('countryCode: $countryCode, ')
          ..write('trendScore: $trendScore, ')
          ..write('lastTrendUpdate: $lastTrendUpdate, ')
          ..write('rankingScore: $rankingScore, ')
          ..write('isMajorSource: $isMajorSource, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('primarySubcategorySlug: $primarySubcategorySlug')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
        id,
        title,
        summary,
        originalUrl,
        imageUrl,
        sourceName,
        sourceFaviconUrl,
        publishedAt,
        createdAt,
        categories,
        subCategories,
        isPaywalled,
        isLiked,
        isFavorited,
        likesCount,
        clusterId,
        countryCode,
        trendScore,
        lastTrendUpdate,
        rankingScore,
        isMajorSource,
        expiresAt,
        primarySubcategorySlug
      ]);
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
          other.createdAt == this.createdAt &&
          other.categories == this.categories &&
          other.subCategories == this.subCategories &&
          other.isPaywalled == this.isPaywalled &&
          other.isLiked == this.isLiked &&
          other.isFavorited == this.isFavorited &&
          other.likesCount == this.likesCount &&
          other.clusterId == this.clusterId &&
          other.countryCode == this.countryCode &&
          other.trendScore == this.trendScore &&
          other.lastTrendUpdate == this.lastTrendUpdate &&
          other.rankingScore == this.rankingScore &&
          other.isMajorSource == this.isMajorSource &&
          other.expiresAt == this.expiresAt &&
          other.primarySubcategorySlug == this.primarySubcategorySlug);
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
  final Value<DateTime> createdAt;
  final Value<List<NewsCategory>> categories;
  final Value<List<NewsSubCategory>> subCategories;
  final Value<bool> isPaywalled;
  final Value<bool> isLiked;
  final Value<bool> isFavorited;
  final Value<int> likesCount;
  final Value<String?> clusterId;
  final Value<String?> countryCode;
  final Value<double> trendScore;
  final Value<DateTime?> lastTrendUpdate;
  final Value<double> rankingScore;
  final Value<bool> isMajorSource;
  final Value<DateTime?> expiresAt;
  final Value<String?> primarySubcategorySlug;
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
    this.createdAt = const Value.absent(),
    this.categories = const Value.absent(),
    this.subCategories = const Value.absent(),
    this.isPaywalled = const Value.absent(),
    this.isLiked = const Value.absent(),
    this.isFavorited = const Value.absent(),
    this.likesCount = const Value.absent(),
    this.clusterId = const Value.absent(),
    this.countryCode = const Value.absent(),
    this.trendScore = const Value.absent(),
    this.lastTrendUpdate = const Value.absent(),
    this.rankingScore = const Value.absent(),
    this.isMajorSource = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.primarySubcategorySlug = const Value.absent(),
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
    this.createdAt = const Value.absent(),
    this.categories = const Value.absent(),
    this.subCategories = const Value.absent(),
    this.isPaywalled = const Value.absent(),
    this.isLiked = const Value.absent(),
    this.isFavorited = const Value.absent(),
    this.likesCount = const Value.absent(),
    this.clusterId = const Value.absent(),
    this.countryCode = const Value.absent(),
    this.trendScore = const Value.absent(),
    this.lastTrendUpdate = const Value.absent(),
    this.rankingScore = const Value.absent(),
    this.isMajorSource = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.primarySubcategorySlug = const Value.absent(),
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
    Expression<DateTime>? createdAt,
    Expression<String>? categories,
    Expression<String>? subCategories,
    Expression<bool>? isPaywalled,
    Expression<bool>? isLiked,
    Expression<bool>? isFavorited,
    Expression<int>? likesCount,
    Expression<String>? clusterId,
    Expression<String>? countryCode,
    Expression<double>? trendScore,
    Expression<DateTime>? lastTrendUpdate,
    Expression<double>? rankingScore,
    Expression<bool>? isMajorSource,
    Expression<DateTime>? expiresAt,
    Expression<String>? primarySubcategorySlug,
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
      if (createdAt != null) 'created_at': createdAt,
      if (categories != null) 'categories': categories,
      if (subCategories != null) 'sub_categories': subCategories,
      if (isPaywalled != null) 'is_paywalled': isPaywalled,
      if (isLiked != null) 'is_liked': isLiked,
      if (isFavorited != null) 'is_favorited': isFavorited,
      if (likesCount != null) 'likes_count': likesCount,
      if (clusterId != null) 'cluster_id': clusterId,
      if (countryCode != null) 'country_code': countryCode,
      if (trendScore != null) 'trend_score': trendScore,
      if (lastTrendUpdate != null) 'last_trend_update': lastTrendUpdate,
      if (rankingScore != null) 'ranking_score': rankingScore,
      if (isMajorSource != null) 'is_major_source': isMajorSource,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (primarySubcategorySlug != null)
        'primary_subcategory_slug': primarySubcategorySlug,
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
      Value<DateTime>? createdAt,
      Value<List<NewsCategory>>? categories,
      Value<List<NewsSubCategory>>? subCategories,
      Value<bool>? isPaywalled,
      Value<bool>? isLiked,
      Value<bool>? isFavorited,
      Value<int>? likesCount,
      Value<String?>? clusterId,
      Value<String?>? countryCode,
      Value<double>? trendScore,
      Value<DateTime?>? lastTrendUpdate,
      Value<double>? rankingScore,
      Value<bool>? isMajorSource,
      Value<DateTime?>? expiresAt,
      Value<String?>? primarySubcategorySlug,
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
      createdAt: createdAt ?? this.createdAt,
      categories: categories ?? this.categories,
      subCategories: subCategories ?? this.subCategories,
      isPaywalled: isPaywalled ?? this.isPaywalled,
      isLiked: isLiked ?? this.isLiked,
      isFavorited: isFavorited ?? this.isFavorited,
      likesCount: likesCount ?? this.likesCount,
      clusterId: clusterId ?? this.clusterId,
      countryCode: countryCode ?? this.countryCode,
      trendScore: trendScore ?? this.trendScore,
      lastTrendUpdate: lastTrendUpdate ?? this.lastTrendUpdate,
      rankingScore: rankingScore ?? this.rankingScore,
      isMajorSource: isMajorSource ?? this.isMajorSource,
      expiresAt: expiresAt ?? this.expiresAt,
      primarySubcategorySlug:
          primarySubcategorySlug ?? this.primarySubcategorySlug,
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
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (categories.present) {
      map['categories'] = Variable<String>(
          $NewsArticlesTableTable.$convertercategories.toSql(categories.value));
    }
    if (subCategories.present) {
      map['sub_categories'] = Variable<String>($NewsArticlesTableTable
          .$convertersubCategories
          .toSql(subCategories.value));
    }
    if (isPaywalled.present) {
      map['is_paywalled'] = Variable<bool>(isPaywalled.value);
    }
    if (isLiked.present) {
      map['is_liked'] = Variable<bool>(isLiked.value);
    }
    if (isFavorited.present) {
      map['is_favorited'] = Variable<bool>(isFavorited.value);
    }
    if (likesCount.present) {
      map['likes_count'] = Variable<int>(likesCount.value);
    }
    if (clusterId.present) {
      map['cluster_id'] = Variable<String>(clusterId.value);
    }
    if (countryCode.present) {
      map['country_code'] = Variable<String>(countryCode.value);
    }
    if (trendScore.present) {
      map['trend_score'] = Variable<double>(trendScore.value);
    }
    if (lastTrendUpdate.present) {
      map['last_trend_update'] = Variable<DateTime>(lastTrendUpdate.value);
    }
    if (rankingScore.present) {
      map['ranking_score'] = Variable<double>(rankingScore.value);
    }
    if (isMajorSource.present) {
      map['is_major_source'] = Variable<bool>(isMajorSource.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<DateTime>(expiresAt.value);
    }
    if (primarySubcategorySlug.present) {
      map['primary_subcategory_slug'] =
          Variable<String>(primarySubcategorySlug.value);
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
          ..write('createdAt: $createdAt, ')
          ..write('categories: $categories, ')
          ..write('subCategories: $subCategories, ')
          ..write('isPaywalled: $isPaywalled, ')
          ..write('isLiked: $isLiked, ')
          ..write('isFavorited: $isFavorited, ')
          ..write('likesCount: $likesCount, ')
          ..write('clusterId: $clusterId, ')
          ..write('countryCode: $countryCode, ')
          ..write('trendScore: $trendScore, ')
          ..write('lastTrendUpdate: $lastTrendUpdate, ')
          ..write('rankingScore: $rankingScore, ')
          ..write('isMajorSource: $isMajorSource, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('primarySubcategorySlug: $primarySubcategorySlug, ')
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

class $ChatSessionsTableTable extends ChatSessionsTable
    with TableInfo<$ChatSessionsTableTable, ChatSessionsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChatSessionsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _articleIdMeta =
      const VerificationMeta('articleId');
  @override
  late final GeneratedColumn<String> articleId = GeneratedColumn<String>(
      'article_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _articleTitleMeta =
      const VerificationMeta('articleTitle');
  @override
  late final GeneratedColumn<String> articleTitle = GeneratedColumn<String>(
      'article_title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [id, articleId, articleTitle, createdAt, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chat_sessions';
  @override
  VerificationContext validateIntegrity(
      Insertable<ChatSessionsTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('article_id')) {
      context.handle(_articleIdMeta,
          articleId.isAcceptableOrUnknown(data['article_id']!, _articleIdMeta));
    } else if (isInserting) {
      context.missing(_articleIdMeta);
    }
    if (data.containsKey('article_title')) {
      context.handle(
          _articleTitleMeta,
          articleTitle.isAcceptableOrUnknown(
              data['article_title']!, _articleTitleMeta));
    } else if (isInserting) {
      context.missing(_articleTitleMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ChatSessionsTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChatSessionsTableData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      articleId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}article_id'])!,
      articleTitle: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}article_title'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $ChatSessionsTableTable createAlias(String alias) {
    return $ChatSessionsTableTable(attachedDatabase, alias);
  }
}

class ChatSessionsTableData extends DataClass
    implements Insertable<ChatSessionsTableData> {
  final String id;
  final String articleId;
  final String articleTitle;
  final DateTime createdAt;
  final DateTime updatedAt;
  const ChatSessionsTableData(
      {required this.id,
      required this.articleId,
      required this.articleTitle,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['article_id'] = Variable<String>(articleId);
    map['article_title'] = Variable<String>(articleTitle);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ChatSessionsTableCompanion toCompanion(bool nullToAbsent) {
    return ChatSessionsTableCompanion(
      id: Value(id),
      articleId: Value(articleId),
      articleTitle: Value(articleTitle),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ChatSessionsTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChatSessionsTableData(
      id: serializer.fromJson<String>(json['id']),
      articleId: serializer.fromJson<String>(json['articleId']),
      articleTitle: serializer.fromJson<String>(json['articleTitle']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'articleId': serializer.toJson<String>(articleId),
      'articleTitle': serializer.toJson<String>(articleTitle),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ChatSessionsTableData copyWith(
          {String? id,
          String? articleId,
          String? articleTitle,
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      ChatSessionsTableData(
        id: id ?? this.id,
        articleId: articleId ?? this.articleId,
        articleTitle: articleTitle ?? this.articleTitle,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  ChatSessionsTableData copyWithCompanion(ChatSessionsTableCompanion data) {
    return ChatSessionsTableData(
      id: data.id.present ? data.id.value : this.id,
      articleId: data.articleId.present ? data.articleId.value : this.articleId,
      articleTitle: data.articleTitle.present
          ? data.articleTitle.value
          : this.articleTitle,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChatSessionsTableData(')
          ..write('id: $id, ')
          ..write('articleId: $articleId, ')
          ..write('articleTitle: $articleTitle, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, articleId, articleTitle, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChatSessionsTableData &&
          other.id == this.id &&
          other.articleId == this.articleId &&
          other.articleTitle == this.articleTitle &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ChatSessionsTableCompanion
    extends UpdateCompanion<ChatSessionsTableData> {
  final Value<String> id;
  final Value<String> articleId;
  final Value<String> articleTitle;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ChatSessionsTableCompanion({
    this.id = const Value.absent(),
    this.articleId = const Value.absent(),
    this.articleTitle = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChatSessionsTableCompanion.insert({
    required String id,
    required String articleId,
    required String articleTitle,
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        articleId = Value(articleId),
        articleTitle = Value(articleTitle);
  static Insertable<ChatSessionsTableData> custom({
    Expression<String>? id,
    Expression<String>? articleId,
    Expression<String>? articleTitle,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (articleId != null) 'article_id': articleId,
      if (articleTitle != null) 'article_title': articleTitle,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChatSessionsTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? articleId,
      Value<String>? articleTitle,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return ChatSessionsTableCompanion(
      id: id ?? this.id,
      articleId: articleId ?? this.articleId,
      articleTitle: articleTitle ?? this.articleTitle,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (articleId.present) {
      map['article_id'] = Variable<String>(articleId.value);
    }
    if (articleTitle.present) {
      map['article_title'] = Variable<String>(articleTitle.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChatSessionsTableCompanion(')
          ..write('id: $id, ')
          ..write('articleId: $articleId, ')
          ..write('articleTitle: $articleTitle, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ChatMessagesTableTable extends ChatMessagesTable
    with TableInfo<$ChatMessagesTableTable, ChatMessagesTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChatMessagesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _sessionIdMeta =
      const VerificationMeta('sessionId');
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
      'session_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
      'role', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _contentMeta =
      const VerificationMeta('content');
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
      'content', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [id, sessionId, role, content, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chat_messages';
  @override
  VerificationContext validateIntegrity(
      Insertable<ChatMessagesTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('session_id')) {
      context.handle(_sessionIdMeta,
          sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta));
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('role')) {
      context.handle(
          _roleMeta, role.isAcceptableOrUnknown(data['role']!, _roleMeta));
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    if (data.containsKey('content')) {
      context.handle(_contentMeta,
          content.isAcceptableOrUnknown(data['content']!, _contentMeta));
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ChatMessagesTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChatMessagesTableData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      sessionId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}session_id'])!,
      role: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}role'])!,
      content: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}content'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $ChatMessagesTableTable createAlias(String alias) {
    return $ChatMessagesTableTable(attachedDatabase, alias);
  }
}

class ChatMessagesTableData extends DataClass
    implements Insertable<ChatMessagesTableData> {
  final int id;
  final String sessionId;
  final String role;
  final String content;
  final DateTime createdAt;
  const ChatMessagesTableData(
      {required this.id,
      required this.sessionId,
      required this.role,
      required this.content,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['session_id'] = Variable<String>(sessionId);
    map['role'] = Variable<String>(role);
    map['content'] = Variable<String>(content);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ChatMessagesTableCompanion toCompanion(bool nullToAbsent) {
    return ChatMessagesTableCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      role: Value(role),
      content: Value(content),
      createdAt: Value(createdAt),
    );
  }

  factory ChatMessagesTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChatMessagesTableData(
      id: serializer.fromJson<int>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      role: serializer.fromJson<String>(json['role']),
      content: serializer.fromJson<String>(json['content']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'role': serializer.toJson<String>(role),
      'content': serializer.toJson<String>(content),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ChatMessagesTableData copyWith(
          {int? id,
          String? sessionId,
          String? role,
          String? content,
          DateTime? createdAt}) =>
      ChatMessagesTableData(
        id: id ?? this.id,
        sessionId: sessionId ?? this.sessionId,
        role: role ?? this.role,
        content: content ?? this.content,
        createdAt: createdAt ?? this.createdAt,
      );
  ChatMessagesTableData copyWithCompanion(ChatMessagesTableCompanion data) {
    return ChatMessagesTableData(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      role: data.role.present ? data.role.value : this.role,
      content: data.content.present ? data.content.value : this.content,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChatMessagesTableData(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('role: $role, ')
          ..write('content: $content, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, sessionId, role, content, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChatMessagesTableData &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.role == this.role &&
          other.content == this.content &&
          other.createdAt == this.createdAt);
}

class ChatMessagesTableCompanion
    extends UpdateCompanion<ChatMessagesTableData> {
  final Value<int> id;
  final Value<String> sessionId;
  final Value<String> role;
  final Value<String> content;
  final Value<DateTime> createdAt;
  const ChatMessagesTableCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.role = const Value.absent(),
    this.content = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  ChatMessagesTableCompanion.insert({
    this.id = const Value.absent(),
    required String sessionId,
    required String role,
    required String content,
    this.createdAt = const Value.absent(),
  })  : sessionId = Value(sessionId),
        role = Value(role),
        content = Value(content);
  static Insertable<ChatMessagesTableData> custom({
    Expression<int>? id,
    Expression<String>? sessionId,
    Expression<String>? role,
    Expression<String>? content,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (role != null) 'role': role,
      if (content != null) 'content': content,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  ChatMessagesTableCompanion copyWith(
      {Value<int>? id,
      Value<String>? sessionId,
      Value<String>? role,
      Value<String>? content,
      Value<DateTime>? createdAt}) {
    return ChatMessagesTableCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      role: role ?? this.role,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChatMessagesTableCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('role: $role, ')
          ..write('content: $content, ')
          ..write('createdAt: $createdAt')
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
  late final $ChatSessionsTableTable chatSessionsTable =
      $ChatSessionsTableTable(this);
  late final $ChatMessagesTableTable chatMessagesTable =
      $ChatMessagesTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        newsArticlesTable,
        viewedArticlesTable,
        chatSessionsTable,
        chatMessagesTable
      ];
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
  Value<DateTime> createdAt,
  Value<List<NewsCategory>> categories,
  Value<List<NewsSubCategory>> subCategories,
  Value<bool> isPaywalled,
  Value<bool> isLiked,
  Value<bool> isFavorited,
  Value<int> likesCount,
  Value<String?> clusterId,
  Value<String?> countryCode,
  Value<double> trendScore,
  Value<DateTime?> lastTrendUpdate,
  Value<double> rankingScore,
  Value<bool> isMajorSource,
  Value<DateTime?> expiresAt,
  Value<String?> primarySubcategorySlug,
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
  Value<DateTime> createdAt,
  Value<List<NewsCategory>> categories,
  Value<List<NewsSubCategory>> subCategories,
  Value<bool> isPaywalled,
  Value<bool> isLiked,
  Value<bool> isFavorited,
  Value<int> likesCount,
  Value<String?> clusterId,
  Value<String?> countryCode,
  Value<double> trendScore,
  Value<DateTime?> lastTrendUpdate,
  Value<double> rankingScore,
  Value<bool> isMajorSource,
  Value<DateTime?> expiresAt,
  Value<String?> primarySubcategorySlug,
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

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<List<NewsCategory>, List<NewsCategory>, String>
      get categories => $composableBuilder(
          column: $table.categories,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnWithTypeConverterFilters<List<NewsSubCategory>, List<NewsSubCategory>,
          String>
      get subCategories => $composableBuilder(
          column: $table.subCategories,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<bool> get isPaywalled => $composableBuilder(
      column: $table.isPaywalled, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isLiked => $composableBuilder(
      column: $table.isLiked, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isFavorited => $composableBuilder(
      column: $table.isFavorited, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get likesCount => $composableBuilder(
      column: $table.likesCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get clusterId => $composableBuilder(
      column: $table.clusterId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get countryCode => $composableBuilder(
      column: $table.countryCode, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get trendScore => $composableBuilder(
      column: $table.trendScore, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastTrendUpdate => $composableBuilder(
      column: $table.lastTrendUpdate,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get rankingScore => $composableBuilder(
      column: $table.rankingScore, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isMajorSource => $composableBuilder(
      column: $table.isMajorSource, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get expiresAt => $composableBuilder(
      column: $table.expiresAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get primarySubcategorySlug => $composableBuilder(
      column: $table.primarySubcategorySlug,
      builder: (column) => ColumnFilters(column));
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

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get categories => $composableBuilder(
      column: $table.categories, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get subCategories => $composableBuilder(
      column: $table.subCategories,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isPaywalled => $composableBuilder(
      column: $table.isPaywalled, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isLiked => $composableBuilder(
      column: $table.isLiked, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isFavorited => $composableBuilder(
      column: $table.isFavorited, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get likesCount => $composableBuilder(
      column: $table.likesCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get clusterId => $composableBuilder(
      column: $table.clusterId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get countryCode => $composableBuilder(
      column: $table.countryCode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get trendScore => $composableBuilder(
      column: $table.trendScore, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastTrendUpdate => $composableBuilder(
      column: $table.lastTrendUpdate,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get rankingScore => $composableBuilder(
      column: $table.rankingScore,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isMajorSource => $composableBuilder(
      column: $table.isMajorSource,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get expiresAt => $composableBuilder(
      column: $table.expiresAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get primarySubcategorySlug => $composableBuilder(
      column: $table.primarySubcategorySlug,
      builder: (column) => ColumnOrderings(column));
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

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<NewsCategory>, String> get categories =>
      $composableBuilder(
          column: $table.categories, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<NewsSubCategory>, String>
      get subCategories => $composableBuilder(
          column: $table.subCategories, builder: (column) => column);

  GeneratedColumn<bool> get isPaywalled => $composableBuilder(
      column: $table.isPaywalled, builder: (column) => column);

  GeneratedColumn<bool> get isLiked =>
      $composableBuilder(column: $table.isLiked, builder: (column) => column);

  GeneratedColumn<bool> get isFavorited => $composableBuilder(
      column: $table.isFavorited, builder: (column) => column);

  GeneratedColumn<int> get likesCount => $composableBuilder(
      column: $table.likesCount, builder: (column) => column);

  GeneratedColumn<String> get clusterId =>
      $composableBuilder(column: $table.clusterId, builder: (column) => column);

  GeneratedColumn<String> get countryCode => $composableBuilder(
      column: $table.countryCode, builder: (column) => column);

  GeneratedColumn<double> get trendScore => $composableBuilder(
      column: $table.trendScore, builder: (column) => column);

  GeneratedColumn<DateTime> get lastTrendUpdate => $composableBuilder(
      column: $table.lastTrendUpdate, builder: (column) => column);

  GeneratedColumn<double> get rankingScore => $composableBuilder(
      column: $table.rankingScore, builder: (column) => column);

  GeneratedColumn<bool> get isMajorSource => $composableBuilder(
      column: $table.isMajorSource, builder: (column) => column);

  GeneratedColumn<DateTime> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);

  GeneratedColumn<String> get primarySubcategorySlug => $composableBuilder(
      column: $table.primarySubcategorySlug, builder: (column) => column);
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
            Value<DateTime> createdAt = const Value.absent(),
            Value<List<NewsCategory>> categories = const Value.absent(),
            Value<List<NewsSubCategory>> subCategories = const Value.absent(),
            Value<bool> isPaywalled = const Value.absent(),
            Value<bool> isLiked = const Value.absent(),
            Value<bool> isFavorited = const Value.absent(),
            Value<int> likesCount = const Value.absent(),
            Value<String?> clusterId = const Value.absent(),
            Value<String?> countryCode = const Value.absent(),
            Value<double> trendScore = const Value.absent(),
            Value<DateTime?> lastTrendUpdate = const Value.absent(),
            Value<double> rankingScore = const Value.absent(),
            Value<bool> isMajorSource = const Value.absent(),
            Value<DateTime?> expiresAt = const Value.absent(),
            Value<String?> primarySubcategorySlug = const Value.absent(),
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
            createdAt: createdAt,
            categories: categories,
            subCategories: subCategories,
            isPaywalled: isPaywalled,
            isLiked: isLiked,
            isFavorited: isFavorited,
            likesCount: likesCount,
            clusterId: clusterId,
            countryCode: countryCode,
            trendScore: trendScore,
            lastTrendUpdate: lastTrendUpdate,
            rankingScore: rankingScore,
            isMajorSource: isMajorSource,
            expiresAt: expiresAt,
            primarySubcategorySlug: primarySubcategorySlug,
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
            Value<DateTime> createdAt = const Value.absent(),
            Value<List<NewsCategory>> categories = const Value.absent(),
            Value<List<NewsSubCategory>> subCategories = const Value.absent(),
            Value<bool> isPaywalled = const Value.absent(),
            Value<bool> isLiked = const Value.absent(),
            Value<bool> isFavorited = const Value.absent(),
            Value<int> likesCount = const Value.absent(),
            Value<String?> clusterId = const Value.absent(),
            Value<String?> countryCode = const Value.absent(),
            Value<double> trendScore = const Value.absent(),
            Value<DateTime?> lastTrendUpdate = const Value.absent(),
            Value<double> rankingScore = const Value.absent(),
            Value<bool> isMajorSource = const Value.absent(),
            Value<DateTime?> expiresAt = const Value.absent(),
            Value<String?> primarySubcategorySlug = const Value.absent(),
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
            createdAt: createdAt,
            categories: categories,
            subCategories: subCategories,
            isPaywalled: isPaywalled,
            isLiked: isLiked,
            isFavorited: isFavorited,
            likesCount: likesCount,
            clusterId: clusterId,
            countryCode: countryCode,
            trendScore: trendScore,
            lastTrendUpdate: lastTrendUpdate,
            rankingScore: rankingScore,
            isMajorSource: isMajorSource,
            expiresAt: expiresAt,
            primarySubcategorySlug: primarySubcategorySlug,
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
typedef $$ChatSessionsTableTableCreateCompanionBuilder
    = ChatSessionsTableCompanion Function({
  required String id,
  required String articleId,
  required String articleTitle,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});
typedef $$ChatSessionsTableTableUpdateCompanionBuilder
    = ChatSessionsTableCompanion Function({
  Value<String> id,
  Value<String> articleId,
  Value<String> articleTitle,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$ChatSessionsTableTableFilterComposer
    extends Composer<_$AppDatabase, $ChatSessionsTableTable> {
  $$ChatSessionsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get articleId => $composableBuilder(
      column: $table.articleId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get articleTitle => $composableBuilder(
      column: $table.articleTitle, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$ChatSessionsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $ChatSessionsTableTable> {
  $$ChatSessionsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get articleId => $composableBuilder(
      column: $table.articleId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get articleTitle => $composableBuilder(
      column: $table.articleTitle,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$ChatSessionsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChatSessionsTableTable> {
  $$ChatSessionsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get articleId =>
      $composableBuilder(column: $table.articleId, builder: (column) => column);

  GeneratedColumn<String> get articleTitle => $composableBuilder(
      column: $table.articleTitle, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ChatSessionsTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ChatSessionsTableTable,
    ChatSessionsTableData,
    $$ChatSessionsTableTableFilterComposer,
    $$ChatSessionsTableTableOrderingComposer,
    $$ChatSessionsTableTableAnnotationComposer,
    $$ChatSessionsTableTableCreateCompanionBuilder,
    $$ChatSessionsTableTableUpdateCompanionBuilder,
    (
      ChatSessionsTableData,
      BaseReferences<_$AppDatabase, $ChatSessionsTableTable,
          ChatSessionsTableData>
    ),
    ChatSessionsTableData,
    PrefetchHooks Function()> {
  $$ChatSessionsTableTableTableManager(
      _$AppDatabase db, $ChatSessionsTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChatSessionsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChatSessionsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChatSessionsTableTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> articleId = const Value.absent(),
            Value<String> articleTitle = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ChatSessionsTableCompanion(
            id: id,
            articleId: articleId,
            articleTitle: articleTitle,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String articleId,
            required String articleTitle,
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ChatSessionsTableCompanion.insert(
            id: id,
            articleId: articleId,
            articleTitle: articleTitle,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ChatSessionsTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ChatSessionsTableTable,
    ChatSessionsTableData,
    $$ChatSessionsTableTableFilterComposer,
    $$ChatSessionsTableTableOrderingComposer,
    $$ChatSessionsTableTableAnnotationComposer,
    $$ChatSessionsTableTableCreateCompanionBuilder,
    $$ChatSessionsTableTableUpdateCompanionBuilder,
    (
      ChatSessionsTableData,
      BaseReferences<_$AppDatabase, $ChatSessionsTableTable,
          ChatSessionsTableData>
    ),
    ChatSessionsTableData,
    PrefetchHooks Function()>;
typedef $$ChatMessagesTableTableCreateCompanionBuilder
    = ChatMessagesTableCompanion Function({
  Value<int> id,
  required String sessionId,
  required String role,
  required String content,
  Value<DateTime> createdAt,
});
typedef $$ChatMessagesTableTableUpdateCompanionBuilder
    = ChatMessagesTableCompanion Function({
  Value<int> id,
  Value<String> sessionId,
  Value<String> role,
  Value<String> content,
  Value<DateTime> createdAt,
});

class $$ChatMessagesTableTableFilterComposer
    extends Composer<_$AppDatabase, $ChatMessagesTableTable> {
  $$ChatMessagesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sessionId => $composableBuilder(
      column: $table.sessionId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get role => $composableBuilder(
      column: $table.role, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$ChatMessagesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $ChatMessagesTableTable> {
  $$ChatMessagesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sessionId => $composableBuilder(
      column: $table.sessionId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get role => $composableBuilder(
      column: $table.role, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$ChatMessagesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChatMessagesTableTable> {
  $$ChatMessagesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ChatMessagesTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ChatMessagesTableTable,
    ChatMessagesTableData,
    $$ChatMessagesTableTableFilterComposer,
    $$ChatMessagesTableTableOrderingComposer,
    $$ChatMessagesTableTableAnnotationComposer,
    $$ChatMessagesTableTableCreateCompanionBuilder,
    $$ChatMessagesTableTableUpdateCompanionBuilder,
    (
      ChatMessagesTableData,
      BaseReferences<_$AppDatabase, $ChatMessagesTableTable,
          ChatMessagesTableData>
    ),
    ChatMessagesTableData,
    PrefetchHooks Function()> {
  $$ChatMessagesTableTableTableManager(
      _$AppDatabase db, $ChatMessagesTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChatMessagesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChatMessagesTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChatMessagesTableTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> sessionId = const Value.absent(),
            Value<String> role = const Value.absent(),
            Value<String> content = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              ChatMessagesTableCompanion(
            id: id,
            sessionId: sessionId,
            role: role,
            content: content,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String sessionId,
            required String role,
            required String content,
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              ChatMessagesTableCompanion.insert(
            id: id,
            sessionId: sessionId,
            role: role,
            content: content,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ChatMessagesTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ChatMessagesTableTable,
    ChatMessagesTableData,
    $$ChatMessagesTableTableFilterComposer,
    $$ChatMessagesTableTableOrderingComposer,
    $$ChatMessagesTableTableAnnotationComposer,
    $$ChatMessagesTableTableCreateCompanionBuilder,
    $$ChatMessagesTableTableUpdateCompanionBuilder,
    (
      ChatMessagesTableData,
      BaseReferences<_$AppDatabase, $ChatMessagesTableTable,
          ChatMessagesTableData>
    ),
    ChatMessagesTableData,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$NewsArticlesTableTableTableManager get newsArticlesTable =>
      $$NewsArticlesTableTableTableManager(_db, _db.newsArticlesTable);
  $$ViewedArticlesTableTableTableManager get viewedArticlesTable =>
      $$ViewedArticlesTableTableTableManager(_db, _db.viewedArticlesTable);
  $$ChatSessionsTableTableTableManager get chatSessionsTable =>
      $$ChatSessionsTableTableTableManager(_db, _db.chatSessionsTable);
  $$ChatMessagesTableTableTableManager get chatMessagesTable =>
      $$ChatMessagesTableTableTableManager(_db, _db.chatMessagesTable);
}
