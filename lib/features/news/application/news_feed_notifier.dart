// lib/features/news/application/news_feed_notifier.dart
// Paginated feed state — 10 articles per batch, with two-tier category sort.

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../domain/entities/news_article.dart';
import '../domain/entities/news_category.dart';
import '../domain/repositories/news_repository.dart';
import '../../../core/providers/providers.dart';
import '../../auth/application/auth_notifier.dart';

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
    this.newArticlesCount = 0,
    this.pendingArticles = const [],
  });

  final List<NewsArticle> articles;

  /// True while a next-page fetch is in flight.
  final bool isLoadingMore;

  /// False once a fetch returns fewer articles than [_kPageSize].
  final bool hasMore;

  final NewsCategory? selectedCategory;

  /// Number of new articles found in background refresh that aren't yet in [articles].
  final int newArticlesCount;

  /// New articles found in background refresh, waiting to be applied.
  final List<NewsArticle> pendingArticles;

  FeedState copyWith({
    List<NewsArticle>? articles,
    bool? isLoadingMore,
    bool? hasMore,
    NewsCategory? Function()? selectedCategory,
    int? newArticlesCount,
    List<NewsArticle>? pendingArticles,
  }) =>
      FeedState(
        articles: articles ?? this.articles,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        hasMore: hasMore ?? this.hasMore,
        selectedCategory: selectedCategory != null
            ? selectedCategory()
            : this.selectedCategory,
        newArticlesCount: newArticlesCount ?? this.newArticlesCount,
        pendingArticles: pendingArticles ?? this.pendingArticles,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

@riverpod
class NewsFeedNotifier extends _$NewsFeedNotifier {
  NewsRepository get _repo => ref.read(newsRepositoryProvider);

  @override
  Future<FeedState> build() async {
    // Watch Auth state so we automatically re-sync when user logs in/out.
    ref.watch(authNotifierProvider);

    // 1. If we already have articles in memory, don't flash the shimmer.
    // This happens when the provider rebuilds (e.g., due to watch(authNotifierProvider)).
    if (state.hasValue && state.value!.articles.isNotEmpty) {
      final current = state.value!;
      debugPrint('[Feed] Retaining existing in-memory articles during rebuild.');
      // Silently refresh in background
      Future.microtask(_backgroundRefresh);
      return current;
    }

    // 2. Fetch from local cache for initial load. 
    // We include results from cache even if viewed, to maintain a stable index 
    // if the user just restarts or if the provider rebuilds.
    final firstPage = await _repo.fetchPage(limit: _kPageSize, offset: 0, includeViewed: true);

    // If cache is empty, wait for the first refresh to complete before showing data.
    if (firstPage.isEmpty) {
      debugPrint('[Feed] Cache empty. Performing initial remote sync...');
      try {
        await _repo.refreshFeed();
        // Initial sync always gets fresh (unviewed) content
        final freshPage = await _repo.fetchPage(limit: _kPageSize, offset: 0);
        return FeedState(
          articles: freshPage,
          hasMore: freshPage.length >= _kPageSize,
        );
      } catch (e) {
        debugPrint('[Feed] Initial remote refresh failed: $e');
        return const FeedState(articles: [], hasMore: false);
      }
    }

    // SILENT refresh in background. 
    // We wait for a microtask to ensure the state returned below is already applied.
    Future.microtask(_backgroundRefresh);
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

    state = AsyncData(current.copyWith(isLoadingMore: true));

    try {
      final category = current.selectedCategory;
      final last = current.articles.isEmpty ? null : current.articles.last;

      // Always includeViewed: true when paginating to avoid skips if user viewed previous items.
      final nextPage = await _repo.fetchPage(
        category: category,
        limit: _kPageSize,
        before: last?.publishedAt,
        afterId: last?.id,
        includeViewed: true,
      );

      state = AsyncData(current.copyWith(
        articles: [...current.articles, ...nextPage],
        isLoadingMore: false,
        hasMore: nextPage.length >= _kPageSize,
      ));
    } catch (e, st) {
      debugPrint('[Feed] loadNextPage error: $e\n$st');
      state = AsyncData(current.copyWith(isLoadingMore: false));
    }
  }


  /// Filter by category, resetting pagination to page 0.
  /// Auto-fetches a second page if the first returns fewer than [_kPageSize].
  Future<void> filterByCategory(NewsCategory? category) async {
    state = const AsyncLoading();
    try {
      // 1. Fetch from local cache first
      var articles = await _repo.fetchPage(
        category: category,
        limit: _kPageSize,
        offset: 0,
      );

      // 2. If local is sparse/empty and we have a category, sync from remote
      // We check if we have at least half a page, otherwise we trigger sync.
      if (articles.length < _kPageSize / 2 && category != null) {
        debugPrint('[Feed] Sparse local cache for ${category.name}. Syncing from remote...');
        try {
          // Sync a larger batch to fill the cache
          await _repo.syncMoreFromRemote(category: category, limit: 30);
          
          // Refresh local list after sync
          articles = await _repo.fetchPage(
            category: category,
            limit: _kPageSize,
            offset: 0,
          );
        } catch (e) {
          debugPrint('[Feed] Remote sync failed for category: $e');
          // Non-blocking error, we show what we have
        }
      }

      state = AsyncData(FeedState(
        articles: articles,
        hasMore: articles.length >= _kPageSize,
        selectedCategory: category,
      ));

      // 3. If we still have very few articles, try to load one more page locally (if any)
      if (articles.isNotEmpty && articles.length < _kPageSize) {
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

  /// Toggles the favorite status of an article.
  Future<void> toggleFavorite(String articleId) async {
    final current = state.valueOrNull;
    if (current == null) return;

    // 1. Optimistic UI update
    final updatedArticles = current.articles.map((a) {
      if (a.id == articleId) {
        return a.copyWith(isFavorited: !a.isFavorited);
      }
      return a;
    }).toList();

    state = AsyncData(current.copyWith(articles: updatedArticles));

    // 2. Persist to DB
    try {
      await _repo.toggleFavorite(articleId);
    } catch (e) {
      debugPrint('[Feed] toggleFavorite error: $e');
      state = AsyncData(current);
    }
  }

  /// Incorporates pending articles into the main feed and clears the count.
  /// This is usually triggered by a 'New Stories' button in the UI.
  void applyPendingArticles() {
    final current = state.valueOrNull;
    if (current == null || current.pendingArticles.isEmpty) return;

    state = AsyncData(current.copyWith(
      articles: [...current.pendingArticles, ...current.articles],
      pendingArticles: [],
      newArticlesCount: 0,
    ));
  }

  // ── Private ─────────────────────────────────────────────────────

  /// Silently checks for new articles in the background.
  /// Instead of replacing the current list, it stores them in [pendingArticles].
  Future<void> _backgroundRefresh() async {
    final current = state.valueOrNull;
    final isInitial = current == null || current.articles.isEmpty;

    try {
      await _repo.refreshFeed();

      final category = current?.selectedCategory;
      // Use includeViewed: true to ensure we can find currentTopId even if it's already marked as viewed.
      final freshPage = await _repo.fetchPage(
        category: category,
        limit: _kPageSize,
        offset: 0,
        includeViewed: true, 
      );

      final hasData = current != null && current.articles.isNotEmpty;

      if (!hasData) {
        // If we really have nothing, show immediately.
        state = AsyncData(FeedState(
          articles: freshPage,
          hasMore: freshPage.length >= _kPageSize,
          selectedCategory: category,
        ));
        return;
      }

      // Already have data: Find NEW articles that we don't have yet.
      // We look at the top ID. 
      final currentTopId = current.articles.firstOrNull?.id;
      if (currentTopId == null) return; 

      final newArticles = <NewsArticle>[];
      for (final article in freshPage) {
        if (article.id == currentTopId) break;
        newArticles.add(article);
      }

      if (newArticles.isNotEmpty) {
        debugPrint('[Feed] ${newArticles.length} new articles found silently.');
        state = AsyncData(current.copyWith(
          newArticlesCount: newArticles.length,
          pendingArticles: newArticles,
        ));
      }
    } catch (e, st) {
      if (isInitial) {
        state = AsyncError(e, st);
      } else {
        debugPrint('[Feed] Silent background sync failed: $e');
        // Let user continue with what they have
      }
    }
  }
}
