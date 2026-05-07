// lib/features/news/application/sidebar_trending_notifier.dart
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../domain/entities/news_article.dart';
import '../domain/repositories/news_repository.dart';
import '../../../core/providers/providers.dart';
import '../../auth/application/auth_notifier.dart';

part 'sidebar_trending_notifier.g.dart';

@Riverpod(keepAlive: true)
class SidebarTrendingNotifier extends _$SidebarTrendingNotifier {
  NewsRepository get _repo => ref.read(newsRepositoryProvider);
  DateTime? _lastFetchTime;
  static const Duration _cacheTtl = Duration(minutes: 10);

  @override
  Future<List<NewsArticle>> build() async {
    final authState = ref.watch(authNotifierProvider);
    final userCountry = authState.preferredCountry;

    return _fetch(userCountry);
  }

  Future<List<NewsArticle>> _fetch(String? userCountry) async {
    final now = DateTime.now();

    // 1. Cache Check
    if (_lastFetchTime != null) {
      final difference = now.difference(_lastFetchTime!);
      if (difference < _cacheTtl) {
        final currentData = state.valueOrNull;
        if (currentData != null && currentData.isNotEmpty) {
          return currentData;
        }
      }
    }

    try {
      debugPrint('[SidebarTrending] Fetching balanced trending (local=$userCountry)');

      // 2. Fetch data based on location
      if (userCountry == null) {
        // Fallback: Just fetch 4 global articles
        final articles = await _repo.fetchTrending(limit: 4, country: null);
        _lastFetchTime = now;
        return articles;
      }

      // Parallel fetch local and global
      final results = await Future.wait([
        _repo.fetchTrending(limit: 10, country: userCountry, hours: 24),
        _repo.fetchTrending(limit: 15, country: null, hours: 24),
      ]);

      final local = results[0];
      final global = results[1];

      // 3. Balance Logic: 2 Local + 2 World
      // Filter world to ensure they are strictly global (country_code is null)
      final world = global.where((a) => a.countryCode == null).toList();

      final combined = <NewsArticle>[];
      
      // Add up to 2 local
      combined.addAll(local.take(2));
      
      // Add up to 2 world
      combined.addAll(world.take(2));

      // Fill remaining slots if either category was short
      if (combined.length < 4) {
        final remaining = 4 - combined.length;
        // Try filling with more world first
        final moreWorld = world.skip(combined.where((a) => a.countryCode == null).length).take(remaining);
        combined.addAll(moreWorld);
      }
      
      if (combined.length < 4) {
        final remaining = 4 - combined.length;
        // Try filling with more local
        final moreLocal = local.skip(combined.where((a) => a.countryCode == userCountry).length).take(remaining);
        combined.addAll(moreLocal);
      }

      _lastFetchTime = now;
      return combined.take(4).toList();
    } catch (e) {
      debugPrint('[SidebarTrending] Error: $e');
      return state.valueOrNull ?? [];
    }
  }

  Future<void> refresh() async {
    final userCountry = ref.read(authNotifierProvider).preferredCountry;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetch(userCountry));
  }
}
