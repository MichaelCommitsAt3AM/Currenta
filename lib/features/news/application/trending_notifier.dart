// lib/features/news/application/trending_notifier.dart

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../domain/entities/news_article.dart';
import '../domain/entities/trending_filters.dart';
import '../domain/repositories/news_repository.dart';
import '../../../core/providers/providers.dart';
import 'trending_filters_notifier.dart';

part 'trending_notifier.g.dart';

@Riverpod(keepAlive: true)
class TrendingNotifier extends _$TrendingNotifier {
  NewsRepository get _repo => ref.read(newsRepositoryProvider);
  DateTime? _lastFetchTime;
  static const Duration _cacheTtl = Duration(minutes: 10);
  TrendingFilters? _lastFilters;

  @override
  Future<List<NewsArticle>> build() async {
    // Watch filters to trigger re-fetch
    final filters = ref.watch(trendingFiltersNotifierProvider);
    
    final isFilterChange = _lastFilters != null && _lastFilters != filters;
    _lastFilters = filters;

    return _fetch(force: isFilterChange);
  }

  Future<List<NewsArticle>> _fetch({bool force = false}) async {
    final now = DateTime.now();
    final filters = ref.read(trendingFiltersNotifierProvider);

    // 1. Check if we have valid cached data
    if (!force && _lastFetchTime != null) {
      final difference = now.difference(_lastFetchTime!);
      if (difference < _cacheTtl) {
        final currentData = state.valueOrNull;
        if (currentData != null && currentData.isNotEmpty) {
          debugPrint(
              '[Trending] Serving from cache (${difference.inMinutes}m old)');
          return currentData;
        }
      }
    }

    // 2. Otherwise fetch from remote
    try {
      debugPrint(
          '[Trending] Fetching fresh trending articles with filters: $filters');

      final articles = await _repo.fetchTrending(
        limit: 20,
        country: filters.countryCode,
        hours: filters.hours,
      );
      _lastFetchTime = now;
      return articles;
    } catch (e) {
      debugPrint('[Trending] Error fetching: $e');
      // If we have old data, keep it instead of returning empty
      return state.valueOrNull ?? [];
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetch(force: true));
  }
}
