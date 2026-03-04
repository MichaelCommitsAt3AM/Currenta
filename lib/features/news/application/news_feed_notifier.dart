// lib/features/news/application/news_feed_notifier.dart
// Paginated feed state — 10 articles per batch, with two-tier category sort.

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../domain/entities/news_article.dart';
import '../domain/entities/news_category.dart';
import '../domain/repositories/news_repository.dart';
import '../../../core/providers/providers.dart';

part 'news_feed_notifier.g.dart';

const _kPageSize = 10;

// ── Feed State ────────────────────────────────────────────────────────────────

@immutable
class FeedState {
  const FeedState({
    this.articles = const [],
    this.isLoadingMore = false,
    this.hasMore = true,
    this.selectedCategory,
  });

  final List<NewsArticle> articles;

  /// True while a next-page fetch is in flight.
  final bool isLoadingMore;

  /// False once a fetch returns fewer articles than [_kPageSize].
  final bool hasMore;

  final NewsCategory? selectedCategory;

  FeedState copyWith({
    List<NewsArticle>? articles,
    bool? isLoadingMore,
    bool? hasMore,
    NewsCategory? Function()? selectedCategory,
  }) =>
      FeedState(
        articles: articles ?? this.articles,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        hasMore: hasMore ?? this.hasMore,
        selectedCategory: selectedCategory != null
            ? selectedCategory()
            : this.selectedCategory,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

@riverpod
class NewsFeedNotifier extends _$NewsFeedNotifier {
  NewsRepository get _repo => ref.read(newsRepositoryProvider);

  // Tracks how many articles have been loaded so far (for offset calculation).
  int _loadedCount = 0;

  @override
  Future<FeedState> build() async {
    final firstPage = await _repo.fetchPage(limit: _kPageSize, offset: 0);

    // If cache is empty, wait for the first refresh to complete before showing data.
    // This keeps the UI in AsyncLoading (shimmer) rather than flashing "Empty State".
    if (firstPage.isEmpty) {
      debugPrint('[Feed] Cache empty. Performing initial remote sync...');
      await _repo.refreshFeed();
      final freshPage = await _repo.fetchPage(limit: _kPageSize, offset: 0);
      _loadedCount = freshPage.length;
      return FeedState(
        articles: freshPage,
        hasMore: freshPage.length >= _kPageSize,
      );
    }

    // If we have cache, show it immediately and refresh in background.
    Future.microtask(_backgroundRefresh);
    _loadedCount = firstPage.length;
    return FeedState(
      articles: firstPage,
      hasMore: firstPage.length >= _kPageSize,
    );
  }

  // ── Public API ──────────────────────────────────────────────────

  /// Appends the next batch of articles to the current list.
  Future<void> loadNextPage() async {
    final current = state.valueOrNull;
    if (current == null || current.isLoadingMore || !current.hasMore) return;

    try {
      final category = current.selectedCategory;

      // 1. Try local cache first (FAST, shouldn't trigger loading state change)
      var nextPage = await _repo.fetchPage(
        category: category,
        limit: _kPageSize,
        offset: _loadedCount,
      );

      // 2. Only if local cache is empty do we trigger the 'Loading More' UI state
      // and hit the network.
      if (nextPage.isEmpty) {
        state = AsyncData(current.copyWith(isLoadingMore: true));

        final impl = _repo as dynamic;
        final synced = await impl.syncMoreFromRemote(
          category: category,
          remoteOffset: _loadedCount,
          limit: 30,
        ) as int;

        if (synced == 0) {
          state = AsyncData(current.copyWith(
            isLoadingMore: false,
            hasMore: false,
          ));
          return;
        }

        nextPage = await _repo.fetchPage(
          category: category,
          limit: _kPageSize,
          offset: _loadedCount,
        );
      }

      _loadedCount += nextPage.length;

      // De-duplicate by id before appending
      final existingIds = current.articles.map((a) => a.id).toSet();
      final fresh = nextPage.where((a) => !existingIds.contains(a.id)).toList();

      state = AsyncData(current.copyWith(
        articles: [...current.articles, ...fresh],
        isLoadingMore: false,
        hasMore: nextPage.length >= _kPageSize,
      ));
    } catch (e, st) {
      final current = state.valueOrNull;
      if (current != null) {
        state = AsyncData(current.copyWith(isLoadingMore: false));
      }
      debugPrint('[Feed] loadNextPage error: $e\n$st');
    }
  }

  /// Filter by category, resetting pagination to page 0.
  /// Auto-fetches a second page if the first returns fewer than [_kPageSize].
  Future<void> filterByCategory(NewsCategory? category) async {
    state = const AsyncLoading();
    _loadedCount = 0;

    try {
      final firstPage = await _repo.fetchPage(
        category: category,
        limit: _kPageSize,
        offset: 0,
      );
      _loadedCount = firstPage.length;

      state = AsyncData(FeedState(
        articles: firstPage,
        hasMore: firstPage.length >= _kPageSize,
        selectedCategory: category,
      ));

      // If the first batch is thin, immediately fetch a second page so the
      // user isn't left staring at near-empty content.
      if (firstPage.length < _kPageSize) {
        await loadNextPage();
      }
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Full refresh: re-syncs remote data then resets to page 1.
  Future<void> refresh() async {
    state = const AsyncLoading();
    await _backgroundRefresh();
  }

  /// Toggles the like status of an article.
  Future<void> toggleLike(String articleId) async {
    final current = state.valueOrNull;
    if (current == null) return;

    // 1. Optimistic UI update
    final updatedArticles = current.articles.map((a) {
      if (a.id == articleId) {
        final newIsLiked = !a.isLiked;
        return a.copyWith(
          isLiked: newIsLiked,
          likesCount: newIsLiked ? a.likesCount + 1 : a.likesCount - 1,
        );
      }
      return a;
    }).toList();

    state = AsyncData(current.copyWith(articles: updatedArticles));

    // 2. Persist to DB
    try {
      await _repo.toggleLike(articleId);
    } catch (e) {
      // Revert on error if needed, but for now we'll just log it
      debugPrint('[Feed] toggleLike error: $e');
      state = AsyncData(current);
    }
  }

  // ── Private ─────────────────────────────────────────────────────

  Future<void> _backgroundRefresh() async {
    try {
      await _repo.refreshFeed();

      // After the remote sync, start fresh from page 1.
      _loadedCount = 0;
      final category = state.valueOrNull?.selectedCategory;
      final firstPage = await _repo.fetchPage(
        category: category,
        limit: _kPageSize,
        offset: 0,
      );

      _loadedCount = firstPage.length;
      state = AsyncData(FeedState(
        articles: firstPage,
        hasMore: firstPage.length >= _kPageSize,
        selectedCategory: category,
      ));
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}
