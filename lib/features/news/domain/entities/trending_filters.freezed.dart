// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'trending_filters.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TrendingFilters {
  /// ISO country code (e.g. "US", "KE") or null for Global
  String? get countryCode;

  /// Time window in hours (12, 24, 72, 168)
  int get hours;

  /// Create a copy of TrendingFilters
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $TrendingFiltersCopyWith<TrendingFilters> get copyWith =>
      _$TrendingFiltersCopyWithImpl<TrendingFilters>(
          this as TrendingFilters, _$identity);

  /// Serializes this TrendingFilters to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is TrendingFilters &&
            (identical(other.countryCode, countryCode) ||
                other.countryCode == countryCode) &&
            (identical(other.hours, hours) || other.hours == hours));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, countryCode, hours);

  @override
  String toString() {
    return 'TrendingFilters(countryCode: $countryCode, hours: $hours)';
  }
}

/// @nodoc
abstract mixin class $TrendingFiltersCopyWith<$Res> {
  factory $TrendingFiltersCopyWith(
          TrendingFilters value, $Res Function(TrendingFilters) _then) =
      _$TrendingFiltersCopyWithImpl;
  @useResult
  $Res call({String? countryCode, int hours});
}

/// @nodoc
class _$TrendingFiltersCopyWithImpl<$Res>
    implements $TrendingFiltersCopyWith<$Res> {
  _$TrendingFiltersCopyWithImpl(this._self, this._then);

  final TrendingFilters _self;
  final $Res Function(TrendingFilters) _then;

  /// Create a copy of TrendingFilters
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? countryCode = freezed,
    Object? hours = null,
  }) {
    return _then(_self.copyWith(
      countryCode: freezed == countryCode
          ? _self.countryCode
          : countryCode // ignore: cast_nullable_to_non_nullable
              as String?,
      hours: null == hours
          ? _self.hours
          : hours // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// Adds pattern-matching-related methods to [TrendingFilters].
extension TrendingFiltersPatterns on TrendingFilters {
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
    TResult Function(_TrendingFilters value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _TrendingFilters() when $default != null:
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
    TResult Function(_TrendingFilters value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TrendingFilters():
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
    TResult? Function(_TrendingFilters value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TrendingFilters() when $default != null:
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
    TResult Function(String? countryCode, int hours)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _TrendingFilters() when $default != null:
        return $default(_that.countryCode, _that.hours);
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
    TResult Function(String? countryCode, int hours) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TrendingFilters():
        return $default(_that.countryCode, _that.hours);
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
    TResult? Function(String? countryCode, int hours)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TrendingFilters() when $default != null:
        return $default(_that.countryCode, _that.hours);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _TrendingFilters extends TrendingFilters {
  const _TrendingFilters({this.countryCode, this.hours = 24}) : super._();
  factory _TrendingFilters.fromJson(Map<String, dynamic> json) =>
      _$TrendingFiltersFromJson(json);

  /// ISO country code (e.g. "US", "KE") or null for Global
  @override
  final String? countryCode;

  /// Time window in hours (12, 24, 72, 168)
  @override
  @JsonKey()
  final int hours;

  /// Create a copy of TrendingFilters
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$TrendingFiltersCopyWith<_TrendingFilters> get copyWith =>
      __$TrendingFiltersCopyWithImpl<_TrendingFilters>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$TrendingFiltersToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _TrendingFilters &&
            (identical(other.countryCode, countryCode) ||
                other.countryCode == countryCode) &&
            (identical(other.hours, hours) || other.hours == hours));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, countryCode, hours);

  @override
  String toString() {
    return 'TrendingFilters(countryCode: $countryCode, hours: $hours)';
  }
}

/// @nodoc
abstract mixin class _$TrendingFiltersCopyWith<$Res>
    implements $TrendingFiltersCopyWith<$Res> {
  factory _$TrendingFiltersCopyWith(
          _TrendingFilters value, $Res Function(_TrendingFilters) _then) =
      __$TrendingFiltersCopyWithImpl;
  @override
  @useResult
  $Res call({String? countryCode, int hours});
}

/// @nodoc
class __$TrendingFiltersCopyWithImpl<$Res>
    implements _$TrendingFiltersCopyWith<$Res> {
  __$TrendingFiltersCopyWithImpl(this._self, this._then);

  final _TrendingFilters _self;
  final $Res Function(_TrendingFilters) _then;

  /// Create a copy of TrendingFilters
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? countryCode = freezed,
    Object? hours = null,
  }) {
    return _then(_TrendingFilters(
      countryCode: freezed == countryCode
          ? _self.countryCode
          : countryCode // ignore: cast_nullable_to_non_nullable
              as String?,
      hours: null == hours
          ? _self.hours
          : hours // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

// dart format on
