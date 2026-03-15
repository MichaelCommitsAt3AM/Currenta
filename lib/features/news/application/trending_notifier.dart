// lib/features/news/application/trending_notifier.dart

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../domain/entities/news_article.dart';
import '../domain/repositories/news_repository.dart';
import '../../../core/providers/providers.dart';

part 'trending_notifier.g.dart';

@Riverpod(keepAlive: true)
class TrendingNotifier extends _$TrendingNotifier {
  NewsRepository get _repo => ref.read(newsRepositoryProvider);
  DateTime? _lastFetchTime;

  @override
  Future<List<NewsArticle>> build() async {
    // Initial fetch
    return _fetch();
  }

  Future<List<NewsArticle>> _fetch({bool force = false}) async {
    // If not forced and we have data within the last 30 minutes, return existing state if available.
    if (!force && _lastFetchTime != null) {
      final now = DateTime.now();
      if (now.difference(_lastFetchTime!) < const Duration(minutes: 30)) {
        final currentData = state.valueOrNull;
        if (currentData != null && currentData.isNotEmpty) {
          debugPrint('[Trending] Serving from cache (${now.difference(_lastFetchTime!).inMinutes}m old)');
          return currentData;
        }
      }
    }

    try {
      debugPrint('[Trending] Fetching fresh trending articles...');
      final articles = await _repo.fetchTrending(limit: 20);
      _lastFetchTime = DateTime.now();
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
