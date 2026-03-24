// lib/features/news/application/news_feed_notifier.dart
// Paginated feed state — 10 articles per batch, with two-tier category sort.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../domain/entities/news_article.dart';
import '../domain/entities/news_category.dart';
import '../domain/repositories/news_repository.dart';
import '../../../core/providers/providers.dart';
import '../../auth/application/auth_notifier.dart';

import 'pending_activity_provider.dart';
import '../data/repositories/local_persistence_repository.dart';

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
    this.currentIndex = 0,
    this.showChatForArticleId,
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

  final int currentIndex;

  final String? showChatForArticleId;

  FeedState copyWith({
    List<NewsArticle>? articles,
    bool? isLoadingMore,
    bool? hasMore,
    NewsCategory? Function()? selectedCategory,
    int? newArticlesCount,
    List<NewsArticle>? pendingArticles,
    int? currentIndex,
    String? Function()? showChatForArticleId,
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
        currentIndex: currentIndex ?? this.currentIndex,
        showChatForArticleId: showChatForArticleId != null
            ? showChatForArticleId()
            : this.showChatForArticleId,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

@riverpod
class NewsFeedNotifier extends _$NewsFeedNotifier {
  NewsRepository get _repo => ref.read(newsRepositoryProvider);
  LocalPersistenceRepository get _persistence =>
      ref.read(localPersistenceRepositoryProvider);
  Future<void>? _refreshInFlight;

  @override
  Future<FeedState> build() async {
    // 0. Trigger cache cleaning on startup.
    // Since periodic background cleaning is disabled, we do it here.
    unawaited(_repo.clearOldCache());

    // 1. Listen for auth changes to handle transitions (login/logout) without
    // triggering a full provider rebuild. This preserves the in-memory feed
    // and current scroll position (currentIndex) during the auth process.
    ref.listen(authNotifierProvider, (previous, next) {
      if (next.isAuthenticated && !(previous?.isAuthenticated ?? false)) {
        debugPrint(
            '[Feed] Auth state changed to authenticated. Processing pending actions.');
        final pending = ref.read(pendingActivityNotifierProvider);
        if (pending != null) {
          ref.read(pendingActivityNotifierProvider.notifier).clear();
          _handlePendingActivity(pending);
        }

        // Perform a background refresh to fetch articles tailored to the new user session.
        // This will show the 'New Stories' badge if new content is available.
        _backgroundRefresh();
      }
    });

    // 2. Initial load: Check for pending activity if starting as authenticated.
    final auth = ref.read(authNotifierProvider);
    if (auth.isAuthenticated) {
      final pending = ref.read(pendingActivityNotifierProvider);
      if (pending != null) {
        ref.read(pendingActivityNotifierProvider.notifier).clear();
        Future.microtask(() => _handlePendingActivity(pending));
      }
    }

    // 3. Restore persisted article position (we always default to 'For You' category on startup)
    const NewsCategory? savedCategoryId = null; // Always default to 'For You'
    final savedArticleId = _persistence.getCurrentArticleId();

    // 4. Fetch from local cache for initial load.
    // If we are restoring a session, we MUST include viewed articles to find our place.
    final includeViewed = savedArticleId != null;

    final firstPage = await _repo.fetchPage(
      category: savedCategoryId,
      limit: _kPageSize,
      offset: 0,
      includeViewed: includeViewed,
    );

    // 4. Load articles: try local cache first, then remote if empty.
    List<NewsArticle> articles = firstPage;

    if (articles.isEmpty) {
      debugPrint('[Feed] Cache empty. Performing initial remote sync...');
      try {
        await _repo.refreshFeed();
        articles = await _repo.fetchPage(
          category: savedCategoryId,
          limit: _kPageSize,
          offset: 0,
          includeViewed: includeViewed,
        );
      } catch (e) {
        debugPrint('[Feed] Initial remote refresh failed: $e');
      }
    }

    // 5. Calculate initial index if we saved an article ID
    int initialIndex = 0;
    if (savedArticleId != null && articles.isNotEmpty) {
      final index = articles.indexWhere((a) => a.id == savedArticleId);
      if (index != -1) {
        initialIndex = index;
      }
    }

    // SILENT refresh in background.
    Future.microtask(_backgroundRefresh);

    return FeedState(
      articles: articles,
      hasMore: true, // Always allow pagination to trigger remote sync
      selectedCategory: savedCategoryId,
      currentIndex: initialIndex,
    );
  }

  // ── Public API ──────────────────────────────────────────────────

  /// Appends the next batch of articles to the current list.
  Future<void> loadNextPage() async {
    final startState = state.valueOrNull;
    if (startState == null || startState.isLoadingMore || !startState.hasMore)
      return;

    state = AsyncData(startState.copyWith(isLoadingMore: true));

    try {
      final category = startState.selectedCategory;
      final last =
          startState.articles.isEmpty ? null : startState.articles.last;

      var nextPage = await _repo.fetchPage(
        category: category,
        limit: _kPageSize,
        before: last?.publishedAt,
        afterId: last?.id,
        includeViewed: false,
      );

      // If local cache is exhausted or sparse, sync from remote
      int syncedCount = 0;
      if (nextPage.length < _kPageSize) {
        debugPrint(
            '[Feed] Local cache sparse for ${category?.name ?? 'all'}. Syncing from remote...');
        syncedCount = await _repo.syncMoreFromRemote(
          category: category,
          before: last?.publishedAt,
          limit: 30, // Fetch a healthy batch
        );

        if (syncedCount > 0) {
          // Fetch again to include newly synced items
          nextPage = await _repo.fetchPage(
            category: category,
            limit: _kPageSize,
            before: last?.publishedAt,
            afterId: last?.id,
            includeViewed: false,
          );
        }
      }

      final current = state.valueOrNull;
      if (current == null || current.selectedCategory != category) return;

      // Deduplicate against already loaded articles
      final existingIds = current.articles.map((a) => a.id).toSet();
      final uniqueNextPage =
          nextPage.where((a) => !existingIds.contains(a.id)).toList();

      state = AsyncData(current.copyWith(
        articles: [...current.articles, ...uniqueNextPage],
        isLoadingMore: false,
        hasMore: (nextPage.isNotEmpty || syncedCount > 0),
      ));
    } catch (e, st) {
      debugPrint('[Feed] loadNextPage error: $e\n$st');
      final current = state.valueOrNull;
      if (current != null) {
        state = AsyncData(current.copyWith(isLoadingMore: false));
      }
    }
  }

  /// Filter by category, resetting pagination to page 0.
  /// Auto-fetches a second page if the first returns fewer than [_kPageSize].
  Future<void> filterByCategory(NewsCategory? category) async {
    // 2. Immediately update state to loading carrying the target category
    state = AsyncLoading<FeedState>().copyWithPrevious(AsyncData(FeedState(
      articles: [], // Clear articles to show whole-screen shimmer
      selectedCategory: category,
    )));

    try {
      // 3. Fetch from local cache first
      final articles = await _repo.fetchPage(
        category: category,
        limit: _kPageSize,
        offset: 0,
      );

      // 4. Update memory state
      final currentState = FeedState(
        articles: articles,
        hasMore: true,
        selectedCategory: category,
        isLoadingMore: false, // Set to false so loadNextPage can start
      );

      // 5. If cache is empty, we must keep the UI in a loading state while we fetch remote.
      if (articles.isEmpty) {
        state =
            AsyncLoading<FeedState>().copyWithPrevious(AsyncData(currentState));
        await loadNextPage();
      } else {
        // We have articles! Show them immediately.
        state = AsyncData(currentState);

        // If we have very few articles, proactively load the next batch in background
        if (articles.length < _kPageSize) {
          unawaited(loadNextPage());
        }
      }

      // Persist the first article ID of this new feed if available
      if (articles.isNotEmpty) {
        _persistence.saveCurrentArticleId(articles.firstOrNull?.id);
      }
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Full refresh: re-syncs remote data then resets to page 1.
  /// Full refresh: re-syncs remote data then incorporates results.
  /// If already viewing articles, it performs a silent refresh to avoid losing place.
  Future<void> refresh() async {
    final startState = state.valueOrNull;

    // If we have nothing, show full loading.
    // Otherwise, do a silent refresh to preserve the current view.
    if (startState == null || startState.articles.isEmpty) {
      state = const AsyncLoading();
    }

    final currentCategory = startState?.selectedCategory;
    await _backgroundRefresh(forcedCategory: currentCategory);

    // If new articles were found, apply them using the preservation logic.
    final updatedState = state.valueOrNull;
    if (updatedState != null && updatedState.pendingArticles.isNotEmpty) {
      applyPendingArticles();
    }
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
      debugPrint('[Feed] toggleLike error: $e');
      // Revert if still on same state
      if (state.valueOrNull == current) {
        state = AsyncData(current);
      }
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
      if (state.valueOrNull == current) {
        state = AsyncData(current);
      }
    }
  }

  /// Incorporates pending articles into the main feed and clears the count.
  /// This is usually triggered by a 'New Stories' button in the UI.
  ///
  /// CRITICAL: To prevent the user from seeing articles they already scrolled past,
  /// we truncate the 'old' feed to only include articles that haven't been viewed yet.
  /// Incorporates pending articles into the main feed while preserving the current article.
  /// The current article is moved to index 0, and the new articles begin at index 1.
  /// This allows the user to swipe up to return to what they were reading.
  void applyPendingArticles() {
    final current = state.valueOrNull;
    if (current == null || current.pendingArticles.isEmpty) return;

    // 1. Identify the currently visible article
    final currentArticle = (current.currentIndex >= 0 &&
            current.currentIndex < current.articles.length)
        ? current.articles[current.currentIndex]
        : null;

    // 2. Filter out already viewed articles from the old list
    // (excluding the current one since we want to keep it)
    final unviewedOldArticles = current.articles.where((a) {
      if (currentArticle != null && a.id == currentArticle.id) return false;
      return !a.isViewed;
    }).toList();

    // 3. Deduplicate against pending articles
    final pendingIds = current.pendingArticles.map((a) => a.id).toSet();
    final uniqueUnviewedOld =
        unviewedOldArticles.where((a) => !pendingIds.contains(a.id)).toList();

    // 4. Construct new list: [Current, New1, New2..., OldUnviewed1...]
    final newList = <NewsArticle>[];
    if (currentArticle != null) {
      newList.add(currentArticle);
    }
    newList.addAll(current.pendingArticles);
    newList.addAll(uniqueUnviewedOld);

    state = AsyncData(current.copyWith(
      articles: newList,
      pendingArticles: [],
      newArticlesCount: 0,
      currentIndex: currentArticle != null ? 1 : 0,
    ));

    // Persist the new "current" article (the one the user is now looking at)
    if (newList.isNotEmpty) {
      final newIndex = currentArticle != null ? 1 : 0;
      if (newIndex < newList.length) {
        _persistence.saveCurrentArticleId(newList[newIndex].id);
      }
    }
  }

  /// Explicitly marks an article as viewed in memory and persists to DB.
  /// This ensures that [applyPendingArticles] can correctly filter out seen articles.
  Future<void> markArticleAsViewed(String articleId) async {
    final current = state.valueOrNull;
    if (current == null) return;

    // 1. Update in-memory state immediately
    final updatedArticles = current.articles.map((a) {
      if (a.id == articleId) return a.copyWith(isViewed: true);
      return a;
    }).toList();

    state = AsyncData(current.copyWith(articles: updatedArticles));

    // 2. Persist to Repository
    try {
      await _repo.markAsViewed(articleId);
    } catch (e) {
      debugPrint('[Feed] failed to mark article $articleId as viewed: $e');
    }
  }

  /// Updates the current index track in state.
  void updateCurrentIndex(int index) {
    final current = state.valueOrNull;
    if (current != null && current.currentIndex != index) {
      state = AsyncData(current.copyWith(currentIndex: index));

      // Persist the current article ID
      if (index >= 0 && index < current.articles.length) {
        _persistence.saveCurrentArticleId(current.articles[index].id);
      }
    }
  }

  /// Clears the pending chat flag.
  void clearPendingChat() {
    final current = state.valueOrNull;
    if (current != null && current.showChatForArticleId != null) {
      state = AsyncData(current.copyWith(showChatForArticleId: () => null));
    }
  }

  // ── Private ─────────────────────────────────────────────────────

  Future<void> _handlePendingActivity(PendingActivity pending) async {
    debugPrint(
        '[Feed] Executing pending action: ${pending.action} for ${pending.articleId}');
    switch (pending.action) {
      case PendingAction.like:
        await toggleLike(pending.articleId);
        break;
      case PendingAction.favorite:
        await toggleFavorite(pending.articleId);
        break;
      case PendingAction.chat:
        final current = state.valueOrNull;
        if (current != null) {
          state = AsyncData(
              current.copyWith(showChatForArticleId: () => pending.articleId));
        }
        break;
    }
  }

  /// Silently checks for new articles in the background.
  /// Instead of replacing the current list, it stores them in [pendingArticles].
  Future<void> _backgroundRefresh({NewsCategory? forcedCategory}) async {
    // Collapse concurrent startup/auth-triggered refreshes into one network request.
    if (_refreshInFlight != null) {
      await _refreshInFlight;
      return;
    }

    final completer = Completer<void>();
    _refreshInFlight = completer.future;

    final startState = state.valueOrNull;
    final category = forcedCategory ?? startState?.selectedCategory;
    final isInitial = startState == null || startState.articles.isEmpty;

    try {
      // Keep refresh aligned with the active category; otherwise category tabs
      // can appear stale even when remote has more items.
      if (category != null) {
        await _repo.syncMoreFromRemote(
          category: category,
          remoteOffset: 0,
          limit: 30,
        );
      } else {
        await _repo.refreshFeed();
      }

      // Fetch the top articles for the relevant category
      final freshPage = await _repo.fetchPage(
        category: category,
        limit: _kPageSize,
        offset: 0,
        includeViewed: true,
      );

      final current = state.valueOrNull;

      // If the category has changed since we started, discard the results to prevent mixing feeds.
      if (current != null && current.selectedCategory != category) {
        debugPrint('[Feed] backgroundRefresh discarded: category changed.');
        return;
      }

      if (current == null || current.articles.isEmpty) {
        // If we really have nothing, show immediately.
        state = AsyncData(FeedState(
          articles: freshPage,
          hasMore: true,
          selectedCategory: category,
        ));
        return;
      }

      // Already have data: Find NEW articles that we don't have yet.
      final currentTopId = current.articles.firstOrNull?.id;
      if (currentTopId == null) return;

      final newArticles = <NewsArticle>[];
      for (final article in freshPage) {
        if (article.id == currentTopId) break;
        if (!article.isViewed) {
          newArticles.add(article);
        }
      }

      if (newArticles.isNotEmpty) {
        debugPrint('[Feed] ${newArticles.length} new articles found silently.');
        state = AsyncData(current.copyWith(
          newArticlesCount: newArticles.length,
          pendingArticles: newArticles,
        ));
      }
    } catch (e, st) {
      if (isInitial && state.isLoading) {
        state = AsyncError(e, st);
      } else {
        debugPrint('[Feed] Silent background sync failed: $e');
      }
    } finally {
      completer.complete();
      _refreshInFlight = null;
    }
  }
}
