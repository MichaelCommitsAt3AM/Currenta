// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trending_filters.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TrendingFilters _$TrendingFiltersFromJson(Map<String, dynamic> json) =>
    _TrendingFilters(
      countryCode: json['countryCode'] as String?,
      hours: (json['hours'] as num?)?.toInt() ?? 24,
    );

Map<String, dynamic> _$TrendingFiltersToJson(_TrendingFilters instance) =>
    <String, dynamic>{
      'countryCode': instance.countryCode,
      'hours': instance.hours,
    };
