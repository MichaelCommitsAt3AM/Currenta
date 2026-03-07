// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'news_article.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$NewsArticle {
  /// Unique identifier (UUID)
  String get id;

  /// Headline of the article
  String get title;

  /// AI-generated summary (max 64 words, 5Ws framework)
  String get summary;

  /// Link to the original article
  @JsonKey(name: 'original_url')
  String get originalUrl;

  /// Cover image URL
  @JsonKey(name: 'image_url')
  String? get imageUrl;

  /// Publisher name, e.g. "BBC News"
  @JsonKey(name: 'source_name')
  String get sourceName;

  /// URL to the publisher's favicon / logo
  @JsonKey(name: 'source_favicon_url')
  String? get sourceFaviconUrl;

  /// When the article was published
  @JsonKey(name: 'published_at')
  DateTime get publishedAt;

  /// News categories (multi-label). First element is primary display category.
  @JsonKey(
      name: 'categories',
      fromJson: _categoriesFromJson,
      toJson: _categoriesToJson)
  List<NewsCategory> get categories;

  /// Whether this article is behind a paywall
  @JsonKey(name: 'is_paywalled')
  bool get isPaywalled;

  /// Whether the current user has liked this article
  @JsonKey(name: 'is_liked')
  bool get isLiked;

  /// Total number of likes
  @JsonKey(name: 'likes_count')
  int get likesCount;

  /// Whether the current user has favorited this article
  @JsonKey(name: 'is_favorited')
  bool get isFavorited;

  /// Semantic cluster ID — articles with the same cluster cover the same story
  @JsonKey(name: 'cluster_id')
  String? get clusterId;

  /// Create a copy of NewsArticle
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $NewsArticleCopyWith<NewsArticle> get copyWith =>
      _$NewsArticleCopyWithImpl<NewsArticle>(this as NewsArticle, _$identity);

  /// Serializes this NewsArticle to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is NewsArticle &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.summary, summary) || other.summary == summary) &&
            (identical(other.originalUrl, originalUrl) ||
                other.originalUrl == originalUrl) &&
            (identical(other.imageUrl, imageUrl) ||
                other.imageUrl == imageUrl) &&
            (identical(other.sourceName, sourceName) ||
                other.sourceName == sourceName) &&
            (identical(other.sourceFaviconUrl, sourceFaviconUrl) ||
                other.sourceFaviconUrl == sourceFaviconUrl) &&
            (identical(other.publishedAt, publishedAt) ||
                other.publishedAt == publishedAt) &&
            const DeepCollectionEquality()
                .equals(other.categories, categories) &&
            (identical(other.isPaywalled, isPaywalled) ||
                other.isPaywalled == isPaywalled) &&
            (identical(other.isLiked, isLiked) || other.isLiked == isLiked) &&
            (identical(other.likesCount, likesCount) ||
                other.likesCount == likesCount) &&
            (identical(other.isFavorited, isFavorited) ||
                other.isFavorited == isFavorited) &&
            (identical(other.clusterId, clusterId) ||
                other.clusterId == clusterId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      title,
      summary,
      originalUrl,
      imageUrl,
      sourceName,
      sourceFaviconUrl,
      publishedAt,
      const DeepCollectionEquality().hash(categories),
      isPaywalled,
      isLiked,
      likesCount,
      isFavorited,
      clusterId);

  @override
  String toString() {
    return 'NewsArticle(id: $id, title: $title, summary: $summary, originalUrl: $originalUrl, imageUrl: $imageUrl, sourceName: $sourceName, sourceFaviconUrl: $sourceFaviconUrl, publishedAt: $publishedAt, categories: $categories, isPaywalled: $isPaywalled, isLiked: $isLiked, likesCount: $likesCount, isFavorited: $isFavorited, clusterId: $clusterId)';
  }
}

/// @nodoc
abstract mixin class $NewsArticleCopyWith<$Res> {
  factory $NewsArticleCopyWith(
          NewsArticle value, $Res Function(NewsArticle) _then) =
      _$NewsArticleCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String title,
      String summary,
      @JsonKey(name: 'original_url') String originalUrl,
      @JsonKey(name: 'image_url') String? imageUrl,
      @JsonKey(name: 'source_name') String sourceName,
      @JsonKey(name: 'source_favicon_url') String? sourceFaviconUrl,
      @JsonKey(name: 'published_at') DateTime publishedAt,
      @JsonKey(
          name: 'categories',
          fromJson: _categoriesFromJson,
          toJson: _categoriesToJson)
      List<NewsCategory> categories,
      @JsonKey(name: 'is_paywalled') bool isPaywalled,
      @JsonKey(name: 'is_liked') bool isLiked,
      @JsonKey(name: 'likes_count') int likesCount,
      @JsonKey(name: 'is_favorited') bool isFavorited,
      @JsonKey(name: 'cluster_id') String? clusterId});
}

/// @nodoc
class _$NewsArticleCopyWithImpl<$Res> implements $NewsArticleCopyWith<$Res> {
  _$NewsArticleCopyWithImpl(this._self, this._then);

  final NewsArticle _self;
  final $Res Function(NewsArticle) _then;

  /// Create a copy of NewsArticle
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? summary = null,
    Object? originalUrl = null,
    Object? imageUrl = freezed,
    Object? sourceName = null,
    Object? sourceFaviconUrl = freezed,
    Object? publishedAt = null,
    Object? categories = null,
    Object? isPaywalled = null,
    Object? isLiked = null,
    Object? likesCount = null,
    Object? isFavorited = null,
    Object? clusterId = freezed,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _self.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      summary: null == summary
          ? _self.summary
          : summary // ignore: cast_nullable_to_non_nullable
              as String,
      originalUrl: null == originalUrl
          ? _self.originalUrl
          : originalUrl // ignore: cast_nullable_to_non_nullable
              as String,
      imageUrl: freezed == imageUrl
          ? _self.imageUrl
          : imageUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      sourceName: null == sourceName
          ? _self.sourceName
          : sourceName // ignore: cast_nullable_to_non_nullable
              as String,
      sourceFaviconUrl: freezed == sourceFaviconUrl
          ? _self.sourceFaviconUrl
          : sourceFaviconUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      publishedAt: null == publishedAt
          ? _self.publishedAt
          : publishedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      categories: null == categories
          ? _self.categories
          : categories // ignore: cast_nullable_to_non_nullable
              as List<NewsCategory>,
      isPaywalled: null == isPaywalled
          ? _self.isPaywalled
          : isPaywalled // ignore: cast_nullable_to_non_nullable
              as bool,
      isLiked: null == isLiked
          ? _self.isLiked
          : isLiked // ignore: cast_nullable_to_non_nullable
              as bool,
      likesCount: null == likesCount
          ? _self.likesCount
          : likesCount // ignore: cast_nullable_to_non_nullable
              as int,
      isFavorited: null == isFavorited
          ? _self.isFavorited
          : isFavorited // ignore: cast_nullable_to_non_nullable
              as bool,
      clusterId: freezed == clusterId
          ? _self.clusterId
          : clusterId // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// Adds pattern-matching-related methods to [NewsArticle].
extension NewsArticlePatterns on NewsArticle {
  /// A variant of `map` that fallback to returning `orElse`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>(
    TResult Function(_NewsArticle value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _NewsArticle() when $default != null:
        return $default(_that);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// Callbacks receives the raw object, upcasted.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case final Subclass2 value:
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult map<TResult extends Object?>(
    TResult Function(_NewsArticle value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _NewsArticle():
        return $default(_that);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `map` that fallback to returning `null`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>(
    TResult? Function(_NewsArticle value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _NewsArticle() when $default != null:
        return $default(_that);
      case _:
        return null;
    }
  }

  /// A variant of `when` that fallback to an `orElse` callback.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>(
    TResult Function(
            String id,
            String title,
            String summary,
            @JsonKey(name: 'original_url') String originalUrl,
            @JsonKey(name: 'image_url') String? imageUrl,
            @JsonKey(name: 'source_name') String sourceName,
            @JsonKey(name: 'source_favicon_url') String? sourceFaviconUrl,
            @JsonKey(name: 'published_at') DateTime publishedAt,
            @JsonKey(
                name: 'categories',
                fromJson: _categoriesFromJson,
                toJson: _categoriesToJson)
            List<NewsCategory> categories,
            @JsonKey(name: 'is_paywalled') bool isPaywalled,
            @JsonKey(name: 'is_liked') bool isLiked,
            @JsonKey(name: 'likes_count') int likesCount,
            @JsonKey(name: 'is_favorited') bool isFavorited,
            @JsonKey(name: 'cluster_id') String? clusterId)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _NewsArticle() when $default != null:
        return $default(
            _that.id,
            _that.title,
            _that.summary,
            _that.originalUrl,
            _that.imageUrl,
            _that.sourceName,
            _that.sourceFaviconUrl,
            _that.publishedAt,
            _that.categories,
            _that.isPaywalled,
            _that.isLiked,
            _that.likesCount,
            _that.isFavorited,
            _that.clusterId);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// As opposed to `map`, this offers destructuring.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case Subclass2(:final field2):
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult when<TResult extends Object?>(
    TResult Function(
            String id,
            String title,
            String summary,
            @JsonKey(name: 'original_url') String originalUrl,
            @JsonKey(name: 'image_url') String? imageUrl,
            @JsonKey(name: 'source_name') String sourceName,
            @JsonKey(name: 'source_favicon_url') String? sourceFaviconUrl,
            @JsonKey(name: 'published_at') DateTime publishedAt,
            @JsonKey(
                name: 'categories',
                fromJson: _categoriesFromJson,
                toJson: _categoriesToJson)
            List<NewsCategory> categories,
            @JsonKey(name: 'is_paywalled') bool isPaywalled,
            @JsonKey(name: 'is_liked') bool isLiked,
            @JsonKey(name: 'likes_count') int likesCount,
            @JsonKey(name: 'is_favorited') bool isFavorited,
            @JsonKey(name: 'cluster_id') String? clusterId)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _NewsArticle():
        return $default(
            _that.id,
            _that.title,
            _that.summary,
            _that.originalUrl,
            _that.imageUrl,
            _that.sourceName,
            _that.sourceFaviconUrl,
            _that.publishedAt,
            _that.categories,
            _that.isPaywalled,
            _that.isLiked,
            _that.likesCount,
            _that.isFavorited,
            _that.clusterId);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `when` that fallback to returning `null`
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>(
    TResult? Function(
            String id,
            String title,
            String summary,
            @JsonKey(name: 'original_url') String originalUrl,
            @JsonKey(name: 'image_url') String? imageUrl,
            @JsonKey(name: 'source_name') String sourceName,
            @JsonKey(name: 'source_favicon_url') String? sourceFaviconUrl,
            @JsonKey(name: 'published_at') DateTime publishedAt,
            @JsonKey(
                name: 'categories',
                fromJson: _categoriesFromJson,
                toJson: _categoriesToJson)
            List<NewsCategory> categories,
            @JsonKey(name: 'is_paywalled') bool isPaywalled,
            @JsonKey(name: 'is_liked') bool isLiked,
            @JsonKey(name: 'likes_count') int likesCount,
            @JsonKey(name: 'is_favorited') bool isFavorited,
            @JsonKey(name: 'cluster_id') String? clusterId)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _NewsArticle() when $default != null:
        return $default(
            _that.id,
            _that.title,
            _that.summary,
            _that.originalUrl,
            _that.imageUrl,
            _that.sourceName,
            _that.sourceFaviconUrl,
            _that.publishedAt,
            _that.categories,
            _that.isPaywalled,
            _that.isLiked,
            _that.likesCount,
            _that.isFavorited,
            _that.clusterId);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _NewsArticle implements NewsArticle {
  const _NewsArticle(
      {required this.id,
      required this.title,
      required this.summary,
      @JsonKey(name: 'original_url') required this.originalUrl,
      @JsonKey(name: 'image_url') this.imageUrl,
      @JsonKey(name: 'source_name') required this.sourceName,
      @JsonKey(name: 'source_favicon_url') this.sourceFaviconUrl,
      @JsonKey(name: 'published_at') required this.publishedAt,
      @JsonKey(
          name: 'categories',
          fromJson: _categoriesFromJson,
          toJson: _categoriesToJson)
      final List<NewsCategory> categories = const [NewsCategory.world],
      @JsonKey(name: 'is_paywalled') this.isPaywalled = false,
      @JsonKey(name: 'is_liked') this.isLiked = false,
      @JsonKey(name: 'likes_count') this.likesCount = 0,
      @JsonKey(name: 'is_favorited') this.isFavorited = false,
      @JsonKey(name: 'cluster_id') this.clusterId})
      : _categories = categories;
  factory _NewsArticle.fromJson(Map<String, dynamic> json) =>
      _$NewsArticleFromJson(json);

  /// Unique identifier (UUID)
  @override
  final String id;

  /// Headline of the article
  @override
  final String title;

  /// AI-generated summary (max 64 words, 5Ws framework)
  @override
  final String summary;

  /// Link to the original article
  @override
  @JsonKey(name: 'original_url')
  final String originalUrl;

  /// Cover image URL
  @override
  @JsonKey(name: 'image_url')
  final String? imageUrl;

  /// Publisher name, e.g. "BBC News"
  @override
  @JsonKey(name: 'source_name')
  final String sourceName;

  /// URL to the publisher's favicon / logo
  @override
  @JsonKey(name: 'source_favicon_url')
  final String? sourceFaviconUrl;

  /// When the article was published
  @override
  @JsonKey(name: 'published_at')
  final DateTime publishedAt;

  /// News categories (multi-label). First element is primary display category.
  final List<NewsCategory> _categories;

  /// News categories (multi-label). First element is primary display category.
  @override
  @JsonKey(
      name: 'categories',
      fromJson: _categoriesFromJson,
      toJson: _categoriesToJson)
  List<NewsCategory> get categories {
    if (_categories is EqualUnmodifiableListView) return _categories;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_categories);
  }

  /// Whether this article is behind a paywall
  @override
  @JsonKey(name: 'is_paywalled')
  final bool isPaywalled;

  /// Whether the current user has liked this article
  @override
  @JsonKey(name: 'is_liked')
  final bool isLiked;

  /// Total number of likes
  @override
  @JsonKey(name: 'likes_count')
  final int likesCount;

  /// Whether the current user has favorited this article
  @override
  @JsonKey(name: 'is_favorited')
  final bool isFavorited;

  /// Semantic cluster ID — articles with the same cluster cover the same story
  @override
  @JsonKey(name: 'cluster_id')
  final String? clusterId;

  /// Create a copy of NewsArticle
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$NewsArticleCopyWith<_NewsArticle> get copyWith =>
      __$NewsArticleCopyWithImpl<_NewsArticle>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$NewsArticleToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _NewsArticle &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.summary, summary) || other.summary == summary) &&
            (identical(other.originalUrl, originalUrl) ||
                other.originalUrl == originalUrl) &&
            (identical(other.imageUrl, imageUrl) ||
                other.imageUrl == imageUrl) &&
            (identical(other.sourceName, sourceName) ||
                other.sourceName == sourceName) &&
            (identical(other.sourceFaviconUrl, sourceFaviconUrl) ||
                other.sourceFaviconUrl == sourceFaviconUrl) &&
            (identical(other.publishedAt, publishedAt) ||
                other.publishedAt == publishedAt) &&
            const DeepCollectionEquality()
                .equals(other._categories, _categories) &&
            (identical(other.isPaywalled, isPaywalled) ||
                other.isPaywalled == isPaywalled) &&
            (identical(other.isLiked, isLiked) || other.isLiked == isLiked) &&
            (identical(other.likesCount, likesCount) ||
                other.likesCount == likesCount) &&
            (identical(other.isFavorited, isFavorited) ||
                other.isFavorited == isFavorited) &&
            (identical(other.clusterId, clusterId) ||
                other.clusterId == clusterId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      title,
      summary,
      originalUrl,
      imageUrl,
      sourceName,
      sourceFaviconUrl,
      publishedAt,
      const DeepCollectionEquality().hash(_categories),
      isPaywalled,
      isLiked,
      likesCount,
      isFavorited,
      clusterId);

  @override
  String toString() {
    return 'NewsArticle(id: $id, title: $title, summary: $summary, originalUrl: $originalUrl, imageUrl: $imageUrl, sourceName: $sourceName, sourceFaviconUrl: $sourceFaviconUrl, publishedAt: $publishedAt, categories: $categories, isPaywalled: $isPaywalled, isLiked: $isLiked, likesCount: $likesCount, isFavorited: $isFavorited, clusterId: $clusterId)';
  }
}

/// @nodoc
abstract mixin class _$NewsArticleCopyWith<$Res>
    implements $NewsArticleCopyWith<$Res> {
  factory _$NewsArticleCopyWith(
          _NewsArticle value, $Res Function(_NewsArticle) _then) =
      __$NewsArticleCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String title,
      String summary,
      @JsonKey(name: 'original_url') String originalUrl,
      @JsonKey(name: 'image_url') String? imageUrl,
      @JsonKey(name: 'source_name') String sourceName,
      @JsonKey(name: 'source_favicon_url') String? sourceFaviconUrl,
      @JsonKey(name: 'published_at') DateTime publishedAt,
      @JsonKey(
          name: 'categories',
          fromJson: _categoriesFromJson,
          toJson: _categoriesToJson)
      List<NewsCategory> categories,
      @JsonKey(name: 'is_paywalled') bool isPaywalled,
      @JsonKey(name: 'is_liked') bool isLiked,
      @JsonKey(name: 'likes_count') int likesCount,
      @JsonKey(name: 'is_favorited') bool isFavorited,
      @JsonKey(name: 'cluster_id') String? clusterId});
}

/// @nodoc
class __$NewsArticleCopyWithImpl<$Res> implements _$NewsArticleCopyWith<$Res> {
  __$NewsArticleCopyWithImpl(this._self, this._then);

  final _NewsArticle _self;
  final $Res Function(_NewsArticle) _then;

  /// Create a copy of NewsArticle
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? summary = null,
    Object? originalUrl = null,
    Object? imageUrl = freezed,
    Object? sourceName = null,
    Object? sourceFaviconUrl = freezed,
    Object? publishedAt = null,
    Object? categories = null,
    Object? isPaywalled = null,
    Object? isLiked = null,
    Object? likesCount = null,
    Object? isFavorited = null,
    Object? clusterId = freezed,
  }) {
    return _then(_NewsArticle(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _self.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      summary: null == summary
          ? _self.summary
          : summary // ignore: cast_nullable_to_non_nullable
              as String,
      originalUrl: null == originalUrl
          ? _self.originalUrl
          : originalUrl // ignore: cast_nullable_to_non_nullable
              as String,
      imageUrl: freezed == imageUrl
          ? _self.imageUrl
          : imageUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      sourceName: null == sourceName
          ? _self.sourceName
          : sourceName // ignore: cast_nullable_to_non_nullable
              as String,
      sourceFaviconUrl: freezed == sourceFaviconUrl
          ? _self.sourceFaviconUrl
          : sourceFaviconUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      publishedAt: null == publishedAt
          ? _self.publishedAt
          : publishedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      categories: null == categories
          ? _self._categories
          : categories // ignore: cast_nullable_to_non_nullable
              as List<NewsCategory>,
      isPaywalled: null == isPaywalled
          ? _self.isPaywalled
          : isPaywalled // ignore: cast_nullable_to_non_nullable
              as bool,
      isLiked: null == isLiked
          ? _self.isLiked
          : isLiked // ignore: cast_nullable_to_non_nullable
              as bool,
      likesCount: null == likesCount
          ? _self.likesCount
          : likesCount // ignore: cast_nullable_to_non_nullable
              as int,
      isFavorited: null == isFavorited
          ? _self.isFavorited
          : isFavorited // ignore: cast_nullable_to_non_nullable
              as bool,
      clusterId: freezed == clusterId
          ? _self.clusterId
          : clusterId // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

// dart format on
