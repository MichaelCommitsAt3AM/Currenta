// lib/features/news/domain/entities/trending_filters.dart

import 'package:freezed_annotation/freezed_annotation.dart';

part 'trending_filters.freezed.dart';
part 'trending_filters.g.dart';

@freezed
abstract class TrendingFilters with _$TrendingFilters {
  const factory TrendingFilters({
    /// ISO country code (e.g. "US", "KE") or null for Global
    String? countryCode,

    /// Time window in hours (12, 24, 72, 168)
    @Default(24) int hours,
  }) = _TrendingFilters;

  const TrendingFilters._();

  factory TrendingFilters.fromJson(Map<String, dynamic> json) =>
      _$TrendingFiltersFromJson(json);

  /// Helper to get a human-readable label for the time window
  String get timeLabel => switch (hours) {
        12 => '12 hours',
        24 => '24 hours',
        72 => '3 days',
        168 => '7 days',
        _ => '$hours hours',
      };
}
