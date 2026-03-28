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

  static const Duration _profileLoadTimeout = Duration(seconds: 8);
  static const Duration _profilePollInterval = Duration(milliseconds: 150);

  /// In-memory cache to preserve feed state (articles, index, pagination status)
  /// for each category durante the session.
  final Map<NewsCategory?, FeedState> _feedCache = {};

  Future<void>? _refreshInFlight;
  bool _isDisposed = false;

  @override
  Future<FeedState> build() async {
    ref.onDispose(() => _isDisposed = true);

    // 0. Trigger cache cleaning on startup.
    unawaited(_repo.clearOldCache());

    // 1. Watch Auth status and profile loading state.
    // We wait for 'isProfileLoaded' to ensure we have the user's interests
    // BEFORE the very first fetch. This prevents the 'jumping' feed issue.
    final isProfileLoaded =
        ref.watch(authNotifierProvider.select((s) => s.isProfileLoaded));
    final isAuthenticated =
        ref.watch(authNotifierProvider.select((s) => s.isAuthenticated));

    if (!isProfileLoaded) {
      debugPrint('[Feed] Waiting for auth profile to load...');
      await _waitForProfileLoad();
    }

    final auth = ref.read(authNotifierProvider);
    final interests = auth.selectedInterests;

    // 2. Listen for auth TRANSITIONS or further preference changes
    ref.listen(authNotifierProvider, (previous, next) {
      // Handle login transition (e.g. guest -> user logged in)
      if (next.isAuthenticated && !(previous?.isAuthenticated ?? false)) {
        debugPrint('[Feed] Auth state transitioned: authenticated.');
        final pending = ref.read(pendingActivityNotifierProvider);
        if (pending != null) {
          ref.read(pendingActivityNotifierProvider.notifier).clear();
          _handlePendingActivity(pending);
        }
        _backgroundRefresh();
      }
      // Handle mid-session interest/country changes silently
      else if (next.isAuthenticated &&
          (next.selectedInterests != previous?.selectedInterests ||
              next.preferredCountry != previous?.preferredCountry)) {
        debugPrint('[Feed] Profile updated. Triggering silent refresh.');
        _backgroundRefresh();
      }
    });

    // 3. Check for initial pending activity
    if (isAuthenticated) {
      final pending = ref.read(pendingActivityNotifierProvider);
      if (pending != null) {
        ref.read(pendingActivityNotifierProvider.notifier).clear();
        Future.microtask(() => _handlePendingActivity(pending));
      }
    }

    // 4. Initialization: Default to 'For You' (null category)
    const NewsCategory? savedCategoryId = null;
    final savedArticleId = _persistence.getCurrentArticleId();
    final includeViewed = savedArticleId != null;

    // 5. Fetch first page with personalization
    List<NewsArticle> articles = await _repo.fetchPage(
      category: savedCategoryId,
      preferredCategories: interests,
      limit: _kPageSize,
      offset: 0,
      includeViewed: includeViewed,
    );

    // 6. Remote sync if local cache is empty
    if (articles.isEmpty) {
      debugPrint('[Feed] Cache empty. Syncing remote...');
      try {
        await _repo.refreshFeed();
        articles = await _repo.fetchPage(
          category: savedCategoryId,
          preferredCategories: interests,
          limit: _kPageSize,
          offset: 0,
          includeViewed: includeViewed,
        );
      } catch (e) {
        debugPrint('[Feed] Remote refresh failed: $e');
      }
    }

    // 7. Position restoration
    int initialIndex = 0;
    if (savedArticleId != null && articles.isNotEmpty) {
      final index = articles.indexWhere((a) => a.id == savedArticleId);
      if (index != -1) initialIndex = index;
    }

    // 8. Silent background refresh
    Future.microtask(_backgroundRefresh);

    final finalState = FeedState(
      articles: articles,
      hasMore: true,
      selectedCategory: savedCategoryId,
      currentIndex: initialIndex,
    );

    _feedCache[savedCategoryId] = finalState;
    return finalState;
  }

  Future<void> _waitForProfileLoad() async {
    final completer = Completer<void>();
    Timer? pollTimer;
    Timer? timeoutTimer;

    void finishSuccessfully() {
      if (!completer.isCompleted) {
        completer.complete();
      }
    }

    void finishWithError(Object error) {
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
    }

    // Fast path if profile already loaded by the time this runs.
    if (ref.read(authNotifierProvider).isProfileLoaded) {
      finishSuccessfully();
    } else {
      timeoutTimer = Timer(_profileLoadTimeout, () {
        // TODO(prod): This explicit startup timeout is useful in dev to surface
        // auth/profile initialization issues. Before production release, gate
        // this behind a debug/dev flag or replace with a resilient fallback
        // flow to avoid hard-failing feed startup for end users.
        finishWithError(TimeoutException(
          'Timed out waiting for auth/profile initialization after '
          '${_profileLoadTimeout.inSeconds}s. Feed startup aborted.',
        ));
      });

      pollTimer = Timer.periodic(_profilePollInterval, (_) {
        if (_isDisposed) {
          finishWithError(
              StateError('Feed provider disposed during profile wait.'));
          return;
        }

        if (ref.read(authNotifierProvider).isProfileLoaded) {
          finishSuccessfully();
        }
      });
    }

    try {
      await completer.future;
    } finally {
      pollTimer?.cancel();
      timeoutTimer?.cancel();
    }
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

      if (_isDisposed) return;
      var nextPage = await _repo.fetchPage(
        category: category,
        preferredCategories: ref.read(authNotifierProvider).selectedInterests,
        limit: _kPageSize,
        before: last?.publishedAt,
        afterId: last?.id,
        includeViewed: false,
      );

      final current = state.valueOrNull;
      if (current == null || current.selectedCategory != category) return;

      // If local cache is exhausted or sparse, sync from remote
      int syncedCount = 0;
      if (nextPage.length < _kPageSize) {
        debugPrint(
            '[Feed] Local cache sparse for ${category?.name ?? 'all'}. Syncing from remote...');
        syncedCount = await _repo.syncMoreFromRemote(
          category: category,
          before: last?.publishedAt,
          limit: 30, // Fetch a healthy batch
          remoteOffset: current.articles.length, // SKIP already loaded articles
        );

        if (syncedCount > 0) {
          // Fetch again to include newly synced items
          nextPage = await _repo.fetchPage(
            category: category,
            preferredCategories:
                ref.read(authNotifierProvider).selectedInterests,
            limit: _kPageSize,
            before: last?.publishedAt,
            afterId: last?.id,
            includeViewed: false,
          );
        }
      }

      // Deduplicate against already loaded articles
      final existingIds = current.articles.map((a) => a.id).toSet();
      final uniqueNextPage =
          nextPage.where((a) => !existingIds.contains(a.id)).toList();

      state = AsyncData(current.copyWith(
        articles: [...current.articles, ...uniqueNextPage],
        isLoadingMore: false,
        hasMore: (nextPage.isNotEmpty || syncedCount > 0),
      ));

      // Update cache with the new page data
      _feedCache[category] = state.value!;
    } catch (e, st) {
      debugPrint('[Feed] loadNextPage error: $e\n$st');
      final current = state.valueOrNull;
      if (current != null) {
        state = AsyncData(current.copyWith(isLoadingMore: false));
      }
    }
  }

  /// Filter by category, resetting pagination to page 0 if not cached.
  /// Auto-fetches a second page if the first returns fewer than [_kPageSize].
  Future<void> filterByCategory(NewsCategory? category) async {
    // 1. Save current state to cache before switching away
    final oldState = state.valueOrNull;
    if (oldState != null) {
      _feedCache[oldState.selectedCategory] = oldState;
    }

    // 2. Check if we have this category cached
    if (_feedCache.containsKey(category)) {
      final cached = _feedCache[category]!;
      state = AsyncData(cached);

      // Persist the current article ID of the restored feed
      if (cached.articles.isNotEmpty &&
          cached.currentIndex < cached.articles.length) {
        _persistence
            .saveCurrentArticleId(cached.articles[cached.currentIndex].id);
      }

      // Proactively refresh in background to keep it fresh
      unawaited(_backgroundRefresh(forcedCategory: category));
      return;
    }

    // 3. Not in cache: Initialize fresh loading carrier
    state = AsyncLoading<FeedState>().copyWithPrevious(AsyncData(FeedState(
      articles: [], // Clear articles to show whole-screen shimmer
      selectedCategory: category,
    )));

    try {
      // 4. Fetch from local cache first
      final articles = await _repo.fetchPage(
        category: category,
        preferredCategories: ref.read(authNotifierProvider).selectedInterests,
        limit: _kPageSize,
        offset: 0,
      );

      // 5. Update memory state
      final currentState = FeedState(
        articles: articles,
        hasMore: true,
        selectedCategory: category,
        isLoadingMore: false,
      );

      // 6. If cache is empty, fetch remote for this category and then resolve state.
      if (articles.isEmpty) {
        state =
            AsyncLoading<FeedState>().copyWithPrevious(AsyncData(currentState));

        final syncedCount = await _repo.syncMoreFromRemote(
          category: category,
          remoteOffset: 0,
          limit: 30,
        );

        final refreshedArticles = await _repo.fetchPage(
          category: category,
          preferredCategories: ref.read(authNotifierProvider).selectedInterests,
          limit: _kPageSize,
          offset: 0,
        );

        state = AsyncData(currentState.copyWith(
          articles: refreshedArticles,
          hasMore: syncedCount > 0 || refreshedArticles.length >= _kPageSize,
          isLoadingMore: false,
        ));
      } else {
        // We have articles! Show them immediately.
        state = AsyncData(currentState);

        // If we have very few articles, proactively load the next batch in background
        if (articles.length < _kPageSize) {
          unawaited(loadNextPage());
        }
      }

      // Update cache with the new result
      if (state.hasValue) {
        _feedCache[category] = state.value!;
      }

      // Persist the first article ID of this new feed if available.
      final resolvedArticles =
          state.valueOrNull?.articles ?? const <NewsArticle>[];
      if (resolvedArticles.isNotEmpty) {
        _persistence.saveCurrentArticleId(resolvedArticles.firstOrNull?.id);
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
      await applyPendingArticles();
    }
  }

  /// Toggles the like status of an article.
  Future<void> toggleLike(String articleId) async {
    final current = state.valueOrNull;
    if (current == null) return;

    _updateArticleInAllFeeds(articleId, (a) {
      final newIsLiked = !a.isLiked;
      return a.copyWith(
        isLiked: newIsLiked,
        likesCount: newIsLiked ? a.likesCount + 1 : a.likesCount - 1,
      );
    });

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

    _updateArticleInAllFeeds(
        articleId, (a) => a.copyWith(isFavorited: !a.isFavorited));

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
  Future<void> applyPendingArticles() async {
    final current = state.valueOrNull;
    if (current == null || current.pendingArticles.isEmpty) return;

    // 1. Show a loading state to trigger the shimmering screen
    state = const AsyncLoading<FeedState>();

    // 2. Artificial delay for visual feedback/shimmer effect
    await Future.delayed(const Duration(milliseconds: 600));

    // 3. Identify the currently visible article
    final currentArticle = (current.currentIndex >= 0 &&
            current.currentIndex < current.articles.length)
        ? current.articles[current.currentIndex]
        : null;

    // 4. Filter out already viewed articles from the old list
    // (excluding the current one since we want to keep it)
    final unviewedOldArticles = current.articles.where((a) {
      if (currentArticle != null && a.id == currentArticle.id) return false;
      return !a.isViewed;
    }).toList();

    // 5. Deduplicate against pending articles
    final pendingIds = current.pendingArticles.map((a) => a.id).toSet();
    final uniqueUnviewedOld =
        unviewedOldArticles.where((a) => !pendingIds.contains(a.id)).toList();

    // 6. Construct new list: [Current, New1, New2..., OldUnviewed1...]
    final newList = <NewsArticle>[];
    if (currentArticle != null) {
      newList.add(currentArticle);
    }
    newList.addAll(current.pendingArticles);
    newList.addAll(uniqueUnviewedOld);

    final nextState = current.copyWith(
      articles: newList,
      pendingArticles: [],
      newArticlesCount: 0,
      currentIndex: currentArticle != null ? 1 : 0,
    );

    state = AsyncData(nextState);

    // Update cache
    _feedCache[nextState.selectedCategory] = nextState;

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

      if (_isDisposed) return;

      // Fetch the top articles for the relevant category
      final freshPage = await _repo.fetchPage(
        category: category,
        preferredCategories: ref.read(authNotifierProvider).selectedInterests,
        limit: _kPageSize,
        offset: 0,
        includeViewed: true,
      );

      if (_isDisposed) return;

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
        final nextState = current.copyWith(
          newArticlesCount: newArticles.length,
          pendingArticles: newArticles,
        );
        state = AsyncData(nextState);
        _feedCache[category] = nextState;
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

  /// Helper to update an article across all cached category feeds to maintain consistency.
  void _updateArticleInAllFeeds(
      String articleId, NewsArticle Function(NewsArticle) update) {
    // 1. Update all cached feeds
    for (final cat in _feedCache.keys) {
      final oldFeed = _feedCache[cat]!;

      // Update main articles
      final articles = oldFeed.articles;
      final idx = articles.indexWhere((a) => a.id == articleId);

      // Update pending articles
      final pending = oldFeed.pendingArticles;
      final pIdx = pending.indexWhere((a) => a.id == articleId);

      if (idx != -1 || pIdx != -1) {
        var newFeed = oldFeed;
        if (idx != -1) {
          final newArticles = List<NewsArticle>.from(articles);
          newArticles[idx] = update(articles[idx]);
          newFeed = newFeed.copyWith(articles: newArticles);
        }
        if (pIdx != -1) {
          final newPending = List<NewsArticle>.from(pending);
          newPending[pIdx] = update(pending[pIdx]);
          newFeed = newFeed.copyWith(pendingArticles: newPending);
        }
        _feedCache[cat] = newFeed;
      }
    }

    // 2. Update current state if it exists (it might be one of the cached ones)
    final current = state.valueOrNull;
    if (current != null) {
      final articles = current.articles;
      final idx = articles.indexWhere((a) => a.id == articleId);

      final pending = current.pendingArticles;
      final pIdx = pending.indexWhere((a) => a.id == articleId);

      if (idx != -1 || pIdx != -1) {
        var nextState = current;
        if (idx != -1) {
          final newArticles = List<NewsArticle>.from(articles);
          newArticles[idx] = update(articles[idx]);
          nextState = nextState.copyWith(articles: newArticles);
        }
        if (pIdx != -1) {
          final newPending = List<NewsArticle>.from(pending);
          newPending[pIdx] = update(pending[pIdx]);
          nextState = nextState.copyWith(pendingArticles: newPending);
        }
        state = AsyncData(nextState);
      }
    }
  }
}
