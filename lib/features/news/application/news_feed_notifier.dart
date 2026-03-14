// lib/features/news/application/news_feed_notifier.dart
// Paginated feed state — 10 articles per batch, with two-tier category sort.

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
  LocalPersistenceRepository get _persistence => ref.read(localPersistenceRepositoryProvider);

  @override
  Future<FeedState> build() async {
    // 1. Check for pending activity if we just became authenticated.
    final auth = ref.watch(authNotifierProvider);
    if (auth.isAuthenticated) {
      final pending = ref.read(pendingActivityNotifierProvider);
      if (pending != null) {
        // Clear immediately to prevent re-execution
        ref.read(pendingActivityNotifierProvider.notifier).clear();
        Future.microtask(() => _handlePendingActivity(pending));
      }
    }

    // 2. If we already have articles in memory, don't flash the shimmer.
    // This happens when the provider rebuilds (e.g., due to watch(authNotifierProvider)).
    final previousState = state.valueOrNull;
    if (previousState != null && previousState.articles.isNotEmpty) {
      debugPrint('[Feed] Retaining existing in-memory articles during rebuild.');
      // Silently refresh in background
      Future.microtask(_backgroundRefresh);
      return previousState;
    }

    // 3. Check for persisted state
    final savedCategoryId = _persistence.getCurrentCategory();
    final savedArticleId = _persistence.getCurrentArticleId();

    // 4. Fetch from local cache for initial load. 
    // If we have a saved article ID, we MUST include viewed articles to find it.
    // Otherwise, we exclude viewed articles to keep the feed fresh.
    final includeViewed = savedArticleId != null;
    
    final firstPage = await _repo.fetchPage(
      category: savedCategoryId,
      limit: _kPageSize, 
      offset: 0, 
      includeViewed: includeViewed,
    );

    // If cache is empty, wait for the first refresh to complete before showing data.
    if (firstPage.isEmpty) {
      debugPrint('[Feed] Cache empty. Performing initial remote sync...');
      try {
        await _repo.refreshFeed();
        final freshPage = await _repo.fetchPage(
          category: savedCategoryId,
          limit: _kPageSize, 
          offset: 0,
        );
        return FeedState(
          articles: freshPage,
          hasMore: freshPage.length >= _kPageSize,
          selectedCategory: savedCategoryId,
        );
      } catch (e) {
        debugPrint('[Feed] Initial remote refresh failed: $e');
        return FeedState(articles: [], hasMore: false, selectedCategory: savedCategoryId);
      }
    }

    // Find the current index if we saved an article ID
    int initialIndex = 0;
    if (savedArticleId != null) {
      initialIndex = firstPage.indexWhere((a) => a.id == savedArticleId);
      if (initialIndex == -1) {
        // If not in first page, just start from 0 or try to fetch it?
        // For now, let's keep it simple. If it's old/gone, start at 0.
        initialIndex = 0;
      }
    }

    // SILENT refresh in background. 
    Future.microtask(_backgroundRefresh);
    
    return FeedState(
      articles: firstPage,
      hasMore: firstPage.length >= _kPageSize,
      selectedCategory: savedCategoryId,
      currentIndex: initialIndex,
    );
  }

  // ── Public API ──────────────────────────────────────────────────

  /// Appends the next batch of articles to the current list.
  Future<void> loadNextPage() async {
    final startState = state.valueOrNull;
    if (startState == null || startState.isLoadingMore || !startState.hasMore) return;

    state = AsyncData(startState.copyWith(isLoadingMore: true));

    try {
      final category = startState.selectedCategory;
      final last = startState.articles.isEmpty ? null : startState.articles.last;

      final nextPage = await _repo.fetchPage(
        category: category,
        limit: _kPageSize,
        before: last?.publishedAt,
        afterId: last?.id,
        includeViewed: false,
      );

      // CRITICAL: Read the LATEST state to avoid overwriting updates (likes, etc.) 
      // made while we were fetching.
      final current = state.valueOrNull;
      if (current == null || current.selectedCategory != category) {
         debugPrint('[Feed] loadNextPage discarded: category changed during fetch.');
         return;
      }

      // Deduplicate against already loaded articles
      final existingIds = current.articles.map((a) => a.id).toSet();
      final uniqueNextPage = nextPage.where((a) => !existingIds.contains(a.id)).toList();

      state = AsyncData(current.copyWith(
        articles: [...current.articles, ...uniqueNextPage],
        isLoadingMore: false,
        hasMore: nextPage.length >= _kPageSize,
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

      // Persist category selection
      _persistence.saveCurrentCategory(category);
      _persistence.saveCurrentArticleId(articles.firstOrNull?.id);

      // 3. If we still have very few articles, try to load one more page locally (if any)
      if (articles.isNotEmpty && articles.length < _kPageSize) {
        await loadNextPage();
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
    final currentArticle =
        (current.currentIndex >= 0 && current.currentIndex < current.articles.length)
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
    debugPrint('[Feed] Executing pending action: ${pending.action} for ${pending.articleId}');
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
          state = AsyncData(current.copyWith(showChatForArticleId: () => pending.articleId));
        }
        break;
    }
  }

  /// Silently checks for new articles in the background.
  /// Instead of replacing the current list, it stores them in [pendingArticles].
  Future<void> _backgroundRefresh({NewsCategory? forcedCategory}) async {
    final startState = state.valueOrNull;
    final category = forcedCategory ?? startState?.selectedCategory;
    final isInitial = startState == null || startState.articles.isEmpty;

    try {
      await _repo.refreshFeed();

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
          hasMore: freshPage.length >= _kPageSize,
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
    }
  }
}
