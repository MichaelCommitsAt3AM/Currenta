// lib/features/news/application/news_feed_notifier.dart
// AsyncNotifierProvider managing the news feed state.

import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../domain/entities/news_article.dart';
import '../domain/entities/news_category.dart';
import '../domain/repositories/news_repository.dart';
import '../../../core/providers/providers.dart';

part 'news_feed_notifier.g.dart';

@riverpod
class NewsFeedNotifier extends _$NewsFeedNotifier {
  NewsRepository get _repo => ref.read(newsRepositoryProvider);

  @override
  Future<List<NewsArticle>> build() async {
    // Kick off a background refresh without blocking the first load
    Future.microtask(_backgroundRefresh);
    // Serve whatever is in the local cache immediately
    return _repo.watchFeed().first;
  }

  /// Public method called by the UI RefreshIndicator / retry buttons.
  Future<void> refresh() async {
    state = const AsyncLoading();
    await _backgroundRefresh();
  }

  Future<void> _backgroundRefresh() async {
    try {
      await _repo.refreshFeed();
      var articles = await _repo.watchFeed().first;

      // If still empty after refresh, trigger a default ingestion (first run)
      if (articles.isEmpty) {
        await _repo.triggerIngestion(
          feedUrl: 'https://rss.nytimes.com/services/xml/rss/nyt/World.xml',
        );
        // Wait a bit for the edge function to process, then check again
        await Future.delayed(const Duration(seconds: 10));
        await _repo.refreshFeed();
        articles = await _repo.watchFeed().first;
      }

      state = AsyncData(articles);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Filter the feed by category. Pass null to show all categories.
  Future<void> filterByCategory(NewsCategory? category) async {
    state = const AsyncLoading();
    try {
      final articles = await _repo.watchFeed(category: category).first;
      state = AsyncData(articles);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}
