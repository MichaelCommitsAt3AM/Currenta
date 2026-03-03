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
    await _backgroundRefresh(forceIngest: true);
  }

  Future<void> _backgroundRefresh({bool forceIngest = false}) async {
    try {
      if (forceIngest) {
        // Trigger a couple of random feeds even if we have data to keep it fresh
        await _repo.triggerAllIngestion(limit: 5);
      }

      await _repo.refreshFeed();
      var articles = await _repo.watchFeed().first;

      // If still empty after refresh, queue jobs and poll until the worker
      // delivers the first batch (queue model: worker runs every ~60s).
      if (articles.isEmpty) {
        await _repo.triggerAllIngestion(limit: 15);

        // Poll every 15s for up to 3 minutes waiting for the worker to process
        // the first jobs and write articles to the DB.
        const pollInterval = Duration(seconds: 15);
        const maxWait = Duration(minutes: 3);
        final deadline = DateTime.now().add(maxWait);

        while (articles.isEmpty && DateTime.now().isBefore(deadline)) {
          await Future.delayed(pollInterval);
          await _repo.refreshFeed();
          articles = await _repo.watchFeed().first;
        }
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
