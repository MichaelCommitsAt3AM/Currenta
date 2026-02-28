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
  String get originalUrl;

  /// Publisher name, e.g. "BBC News"
  String get sourceName;

  /// URL to the publisher's favicon / logo
  String? get sourceFaviconUrl;

  /// When the article was published
  DateTime get publishedAt;

  /// News category
  NewsCategory get category;

  /// Whether this article is behind a paywall
  bool get isPaywalled;

  /// Semantic cluster ID — articles with the same cluster cover the same story
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
            (identical(other.sourceName, sourceName) ||
                other.sourceName == sourceName) &&
            (identical(other.sourceFaviconUrl, sourceFaviconUrl) ||
                other.sourceFaviconUrl == sourceFaviconUrl) &&
            (identical(other.publishedAt, publishedAt) ||
                other.publishedAt == publishedAt) &&
            (identical(other.category, category) ||
                other.category == category) &&
            (identical(other.isPaywalled, isPaywalled) ||
                other.isPaywalled == isPaywalled) &&
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
      sourceName,
      sourceFaviconUrl,
      publishedAt,
      category,
      isPaywalled,
      clusterId);

  @override
  String toString() {
    return 'NewsArticle(id: $id, title: $title, summary: $summary, originalUrl: $originalUrl, sourceName: $sourceName, sourceFaviconUrl: $sourceFaviconUrl, publishedAt: $publishedAt, category: $category, isPaywalled: $isPaywalled, clusterId: $clusterId)';
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
      String originalUrl,
      String sourceName,
      String? sourceFaviconUrl,
      DateTime publishedAt,
      NewsCategory category,
      bool isPaywalled,
      String? clusterId});
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
    Object? sourceName = null,
    Object? sourceFaviconUrl = freezed,
    Object? publishedAt = null,
    Object? category = null,
    Object? isPaywalled = null,
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
      category: null == category
          ? _self.category
          : category // ignore: cast_nullable_to_non_nullable
              as NewsCategory,
      isPaywalled: null == isPaywalled
          ? _self.isPaywalled
          : isPaywalled // ignore: cast_nullable_to_non_nullable
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
            String originalUrl,
            String sourceName,
            String? sourceFaviconUrl,
            DateTime publishedAt,
            NewsCategory category,
            bool isPaywalled,
            String? clusterId)?
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
            _that.sourceName,
            _that.sourceFaviconUrl,
            _that.publishedAt,
            _that.category,
            _that.isPaywalled,
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
            String originalUrl,
            String sourceName,
            String? sourceFaviconUrl,
            DateTime publishedAt,
            NewsCategory category,
            bool isPaywalled,
            String? clusterId)
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
            _that.sourceName,
            _that.sourceFaviconUrl,
            _that.publishedAt,
            _that.category,
            _that.isPaywalled,
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
            String originalUrl,
            String sourceName,
            String? sourceFaviconUrl,
            DateTime publishedAt,
            NewsCategory category,
            bool isPaywalled,
            String? clusterId)?
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
            _that.sourceName,
            _that.sourceFaviconUrl,
            _that.publishedAt,
            _that.category,
            _that.isPaywalled,
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
      required this.originalUrl,
      required this.sourceName,
      this.sourceFaviconUrl,
      required this.publishedAt,
      this.category = NewsCategory.world,
      this.isPaywalled = false,
      this.clusterId});
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
  final String originalUrl;

  /// Publisher name, e.g. "BBC News"
  @override
  final String sourceName;

  /// URL to the publisher's favicon / logo
  @override
  final String? sourceFaviconUrl;

  /// When the article was published
  @override
  final DateTime publishedAt;

  /// News category
  @override
  @JsonKey()
  final NewsCategory category;

  /// Whether this article is behind a paywall
  @override
  @JsonKey()
  final bool isPaywalled;

  /// Semantic cluster ID — articles with the same cluster cover the same story
  @override
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
            (identical(other.sourceName, sourceName) ||
                other.sourceName == sourceName) &&
            (identical(other.sourceFaviconUrl, sourceFaviconUrl) ||
                other.sourceFaviconUrl == sourceFaviconUrl) &&
            (identical(other.publishedAt, publishedAt) ||
                other.publishedAt == publishedAt) &&
            (identical(other.category, category) ||
                other.category == category) &&
            (identical(other.isPaywalled, isPaywalled) ||
                other.isPaywalled == isPaywalled) &&
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
      sourceName,
      sourceFaviconUrl,
      publishedAt,
      category,
      isPaywalled,
      clusterId);

  @override
  String toString() {
    return 'NewsArticle(id: $id, title: $title, summary: $summary, originalUrl: $originalUrl, sourceName: $sourceName, sourceFaviconUrl: $sourceFaviconUrl, publishedAt: $publishedAt, category: $category, isPaywalled: $isPaywalled, clusterId: $clusterId)';
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
      String originalUrl,
      String sourceName,
      String? sourceFaviconUrl,
      DateTime publishedAt,
      NewsCategory category,
      bool isPaywalled,
      String? clusterId});
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
    Object? sourceName = null,
    Object? sourceFaviconUrl = freezed,
    Object? publishedAt = null,
    Object? category = null,
    Object? isPaywalled = null,
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
      category: null == category
          ? _self.category
          : category // ignore: cast_nullable_to_non_nullable
              as NewsCategory,
      isPaywalled: null == isPaywalled
          ? _self.isPaywalled
          : isPaywalled // ignore: cast_nullable_to_non_nullable
              as bool,
      clusterId: freezed == clusterId
          ? _self.clusterId
          : clusterId // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

// dart format on
