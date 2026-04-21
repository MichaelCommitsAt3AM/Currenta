// lib/features/news/application/news_feed_notifier.dart
// Paginated feed state — 10 articles per batch, with two-tier category sort.

import 'dart:async';
import 'package:currenta/core/config/app_config.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../domain/entities/news_article.dart';
import '../domain/entities/news_category.dart';
import '../domain/repositories/news_repository.dart';
import '../../../core/providers/providers.dart';
import '../../auth/application/auth_notifier.dart';

import '../data/repositories/local_persistence_repository.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

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
    this.includeViewedInPaging = false,
    this.sessionId,
    this.nextCursor,
    this.expiresAt,
    this.isServerExhausted = false,
  });

  final List<NewsArticle> articles;

  /// True while a next-page fetch is in flight.
  final bool isLoadingMore;

  /// False once a fetch returns fewer articles than [_kPageSize]
  /// OR as explicitly signaled by the server's [hasMore] flag.
  final bool hasMore;

  final NewsCategory? selectedCategory;

  /// Number of new articles found in background refresh that aren't yet in [articles].
  final int newArticlesCount;

  /// New articles found in background refresh, waiting to be applied.
  final List<NewsArticle> pendingArticles;

  final int currentIndex;

  final String? showChatForArticleId;

  /// If true, pagination will include articles already marked as viewed.
  /// Typically enabled during state restoration to maintain feed continuity.
  final bool includeViewedInPaging;

  final String? sessionId;
  final String? nextCursor;
  final DateTime? expiresAt;
  
  /// True if the remote server has returned hasMore=false for this category session.
  /// When true, we fallback to showing local secondary-category articles.
  final bool isServerExhausted;

  FeedState copyWith({
    List<NewsArticle>? articles,
    bool? isLoadingMore,
    bool? hasMore,
    NewsCategory? Function()? selectedCategory,
    int? newArticlesCount,
    List<NewsArticle>? pendingArticles,
    int? currentIndex,
    String? Function()? showChatForArticleId,
    bool? includeViewedInPaging,
    String? sessionId,
    String? Function()? nextCursor,
    DateTime? expiresAt,
    bool? isServerExhausted,
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
        includeViewedInPaging:
            includeViewedInPaging ?? this.includeViewedInPaging,
        sessionId: sessionId ?? this.sessionId,
        nextCursor: nextCursor != null ? nextCursor() : this.nextCursor,
        expiresAt: expiresAt ?? this.expiresAt,
        isServerExhausted: isServerExhausted ?? this.isServerExhausted,
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

  /// Tracking categories with active fetches to prevent redundant requests.
  final Set<NewsCategory?> _fetchingStates = {};

  bool _isDisposed = false;

  @override
  Future<FeedState> build() async {
    ref.onDispose(() => _isDisposed = true);

    // 0. Trigger cache cleaning on startup.
    await _repo.clearOldCache();

    // 1. Wait for profile (interests/country) to ensure ranking is relevant.
    final isProfileLoaded =
        ref.watch(authNotifierProvider.select((s) => s.isProfileLoaded));
    if (!isProfileLoaded) {
      await _waitForProfileLoad();
    }

    final auth = ref.read(authNotifierProvider);
    final interests = auth.selectedInterests;

    // 2. Listen for auth transitions (login/profile update) to refresh.
    ref.listen(authNotifierProvider, (previous, next) {
      Future.microtask(() {
        if (_isDisposed) return;
        if (next.isAuthenticated && !(previous?.isAuthenticated ?? false)) {
          _backgroundRefresh();
        } else if (next.isAuthenticated &&
            (next.selectedInterests != previous?.selectedInterests ||
                next.preferredCountry != previous?.preferredCountry)) {
          _backgroundRefresh();
        }
      });
    });

    // 3. Initialization: Always start fresh on cold boot with unseen articles
    const NewsCategory? savedCategoryId = null;

    // 4. Local Fetch (Cache-First)
    List<NewsArticle> articles = await _repo.fetchPage(
      category: savedCategoryId,
      preferredCategories: interests,
      countryCode: auth.preferredCountry,
      limit: _kPageSize,
      offset: 0,
      includeViewed: false, // Only show fresh content on startup
    );

    String? sessionId;
    String? nextCursor;
    bool hasMore = true;
    DateTime? expiresAt;

    // 5. Check cache validity or sync remote if empty
    bool needsRefresh = articles.isEmpty;
    if (articles.isNotEmpty) {
      final topArticle = articles.firstOrNull;
      if (topArticle != null) {
        final age = DateTime.now().difference(topArticle.publishedAt);
        if (age.inHours >= AppConfig.hardTtlHours) {
          needsRefresh = true;
          articles = []; // Discard stale articles on hard TTL
          // Also clear the saved position to start fresh at the top
          _persistence.saveLastForYouArticleId(null);
        } else if (age.inHours >= AppConfig.softTtlHours) {
          Future.microtask(_backgroundRefresh);
        }
      }
    }

    if (needsRefresh) {
      try {
        final response = await _repo.syncMoreFromRemote(
          category: savedCategoryId,
          limit: _kPageSize,
        );
        articles = response.articles;
        sessionId = response.sessionId;
        nextCursor = response.nextCursor;
        hasMore = response.hasMore;
        expiresAt = response.expiresAt;
      } catch (e) {
        debugPrint('[Feed] Initial sync failed: $e');
      }
    }

    // 6. Position restoration (Always start at top for fresh feed)
    const int initialIndex = 0;

    final finalState = FeedState(
      articles: articles,
      hasMore: hasMore,
      selectedCategory: savedCategoryId,
      currentIndex: initialIndex,
      sessionId: sessionId,
      nextCursor: nextCursor,
      expiresAt: expiresAt,
      includeViewedInPaging: false,
      isServerExhausted: !hasMore,
    );

    _feedCache[savedCategoryId] = finalState;

    // 7. If we served from cache (no remote fetch yet), establish a session in
    //    the background so that loadNextPage() has a valid sessionId + nextCursor.
    //    Without this, every pagination call sends sessionId=null which the backend
    //    treats as a fresh session restart — returning page 1 again.
    if (sessionId == null && articles.isNotEmpty) {
      Future.microtask(() => _establishSessionInBackground(savedCategoryId));
    }

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

    timeoutTimer = Timer(_profileLoadTimeout, () {
      pollTimer?.cancel();
      finishSuccessfully(); 
    });

    pollTimer = Timer.periodic(_profilePollInterval, (timer) {
      if (_isDisposed) {
        timer.cancel();
        timeoutTimer?.cancel();
        return;
      }
      if (ref.read(authNotifierProvider).isProfileLoaded) {
        timer.cancel();
        timeoutTimer?.cancel();
        finishSuccessfully();
      }
    });

    return completer.future;
  }

  // ── Public API ──────────────────────────────────────────────────

  /// Appends the next batch of articles to the current list using session cursors.
  Future<void> loadNextPage() async {
    final startState = state.valueOrNull;
    if (startState == null) return;
    
    final category = startState.selectedCategory;
    
    // If server is exhausted, fetch secondary articles from local cache
    if (startState.isServerExhausted) {
      await _loadNextPageFromLocalSecondary(startState);
      return;
    }

    if (!startState.hasMore) return;

    // 1. Concurrency Guard
    if (_fetchingStates.contains(category)) return;

    _fetchingStates.add(category);
    state = AsyncData(startState.copyWith(isLoadingMore: true));

    try {
      // 2. Session Validity Check (Client-side TTL fallback)
      if (startState.expiresAt != null &&
          DateTime.now().isAfter(startState.expiresAt!)) {
        await filterByCategory(category);
        return;
      }

      // 3a. If background session hasn't arrived yet, wait up to 3 s for it.
      if (startState.sessionId == null) {
        for (var i = 0; i < 30; i++) {
          await Future.delayed(const Duration(milliseconds: 100));
          final interim = state.valueOrNull;
          if (interim == null || interim.selectedCategory != category) return;
          if (interim.sessionId != null) break;
        }
      }

      // Re-read state after the optional wait
      final resolvedState = state.valueOrNull;
      if (resolvedState == null || resolvedState.selectedCategory != category) return;

      // 3b. Remote Sync (Fetch next page from backend)
      final response = await _repo.syncMoreFromRemote(
        category: category,
        sessionId: resolvedState.sessionId,
        cursor: resolvedState.nextCursor,
        limit: _kPageSize,
      );

      final current = state.valueOrNull;
      if (current == null || current.selectedCategory != category) return;

      // 4. Session Guard: Only detect a mismatch when we had a known sessionId.
      //    Skipping this check when current.sessionId == null avoids a false reset
      //    during the background-session-establishment window.
      if (current.sessionId != null &&
          response.sessionId != null &&
          response.sessionId != current.sessionId) {
        final resetState = current.copyWith(
          articles: response.articles,
          sessionId: response.sessionId,
          nextCursor: () => response.nextCursor,
          hasMore: response.hasMore,
          expiresAt: response.expiresAt,
          isLoadingMore: false,
        );
        state = AsyncData(resetState);
        _feedCache[category] = resetState;
        return;
      }

      // 5. Empty Page Guard
      if (response.articles.isEmpty) {
        if (response.hasMore && response.nextCursor != null) {
          // Server skipped ahead (e.g. some DB-missing IDs were bypassed) but there are
          // still articles further in the session. Trust the server's cursor and keep going.
          final advancedState = current.copyWith(
            isLoadingMore: false,
            hasMore: response.hasMore,
            nextCursor: () => response.nextCursor,
            expiresAt: response.expiresAt,
          );
          state = AsyncData(advancedState);
          _feedCache[category] = advancedState;
        } else {
          // Genuinely no more articles from server
          final endState = current.copyWith(
            hasMore: false,
            isLoadingMore: false,
            isServerExhausted: true,
          );
          state = AsyncData(endState);
          _feedCache[category] = endState;
          
          // Immediately try to load local secondary articles if we didn't get enough from server
          if (current.articles.length < 5) {
             await _loadNextPageFromLocalSecondary(endState);
          }
        }
        return;
      }

      // 6. Success: Deduplicate and Append
      final existingIds = current.articles.map((a) => a.id).toSet();
      final uniqueNewArticles = response.articles.where((a) => !existingIds.contains(a.id)).toList();

      var nextArticles = [...current.articles, ...uniqueNewArticles];
      
      // Memory Guard: Prune the list if it exceeds 500 articles to prevent OOM
      if (nextArticles.length > 500) {
        nextArticles = nextArticles.sublist(0, 500);
      }

      final nextState = current.copyWith(
        articles: nextArticles,
        isLoadingMore: false,
        hasMore: response.hasMore,
        nextCursor: () => response.nextCursor,
        expiresAt: response.expiresAt,
      );

      state = AsyncData(nextState);
      _feedCache[category] = nextState;
      
    } catch (e, st) {
      FirebaseCrashlytics.instance.recordError(e, st, reason: 'Paging failure in loadNextPage');
      debugPrint('[FeedPaging] ERROR: $e\n$st');
    } finally {
      _fetchingStates.remove(category);
      final finalCurrent = state.valueOrNull;
      if (finalCurrent != null && finalCurrent.isLoadingMore) {
        state = AsyncData(finalCurrent.copyWith(isLoadingMore: false));
      }
    }
  }

  Future<void> filterByCategory(NewsCategory? category) async {
    // 1. Save current state to cache before switching away.
    final oldState = state.valueOrNull;
    if (oldState != null) {
      _feedCache[oldState.selectedCategory] =
          oldState.copyWith(isLoadingMore: false);
    }

    // 2. Fast Path: If category is in cache and valid, switch immediately
    final cached = _feedCache[category];
    if (cached != null &&
        (cached.expiresAt == null ||
            DateTime.now().isBefore(cached.expiresAt!))) {
      state = AsyncData(cached);
      _persistence.saveCurrentArticleId(cached.articles.firstOrNull?.id);
      return;
    }

    // 3. Start a fresh session (Cache-First)
    // Yield immediately so UI can render the category highlight & shimmer
    state = const AsyncLoading<FeedState>();
    await Future.microtask(() {});

    try {
      // 4. Local Fetch (Cache-First) - For category switches, we show unseen first
      List<NewsArticle> localArticles = await _repo.fetchPage(
        category: category,
        preferredCategories: ref.read(authNotifierProvider).selectedInterests,
        countryCode: ref.read(authNotifierProvider).preferredCountry,
        limit: _kPageSize,
        offset: 0,
        includeViewed: false,
        primaryOnly: true, // User request: First look for primary-only
      );

      const int initialIndex = 0;

      if (localArticles.isNotEmpty) {
        final newState = FeedState(
          articles: localArticles,
          selectedCategory: category,
          currentIndex: initialIndex,
          hasMore: true,
          isServerExhausted: false,
        );
        state = AsyncData(newState);
        _feedCache[category] = newState;

        // Establish remote session in background
        Future.microtask(() => _establishSessionInBackground(category));
        return;
      }

      // 5. Remote Sync (Fallback)
      final response = await _repo.syncMoreFromRemote(
        category: category,
        limit: _kPageSize,
      );

      final newState = FeedState(
        articles: response.articles,
        selectedCategory: category,
        sessionId: response.sessionId,
        nextCursor: response.nextCursor,
        hasMore: response.hasMore,
        expiresAt: response.expiresAt,
        isServerExhausted: !response.hasMore,
      );

      state = AsyncData(newState);
      _feedCache[category] = newState;

      if (newState.articles.isNotEmpty) {
        _persistence.saveCurrentArticleId(newState.articles.first.id);
      }
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Full refresh: invalidates ALL cached sessions and resets to page 1 with new data.
  Future<void> refresh() async {
    final startState = state.valueOrNull;
    state = const AsyncLoading<FeedState>().copyWithPrevious(state);

    final currentCategory = startState?.selectedCategory;
    
    // Clear all cached sessions to ensure diversity fixes apply to every category
    _feedCache.clear();
    
    try {
      final response = await _repo.syncMoreFromRemote(
        category: currentCategory,
        limit: _kPageSize,
        // Passing null sessionId triggers a brand new session on the backend
        sessionId: null, 
      );

      final newState = FeedState(
        articles: response.articles,
        selectedCategory: currentCategory,
        sessionId: response.sessionId,
        nextCursor: response.nextCursor,
        hasMore: response.hasMore,
        expiresAt: response.expiresAt,
        isServerExhausted: !response.hasMore,
      );

      state = AsyncData(newState);
      _feedCache[currentCategory] = newState;

      // Persistence: Reset scroll position to top on refresh
      if (newState.articles.isNotEmpty) {
        _persistence.saveCurrentArticleId(newState.articles.first.id);
      }
    } catch (e, st) {
      debugPrint('[Feed] Refresh failed: $e');
      if (startState != null) {
        state = AsyncData(startState).copyWithPrevious(AsyncError(e, st));
      } else {
        state = AsyncError(e, st);
      }
    }
  }

  Future<void> refreshIfStale() async {
    final current = state.valueOrNull;
    if (current == null) return;

    if (current.expiresAt != null && DateTime.now().isAfter(current.expiresAt!)) {
      await refresh();
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

    await _repo.toggleLike(articleId);
  }

  Future<void> toggleFavorite(String articleId) async {
    final current = state.valueOrNull;
    if (current == null) return;

    _updateArticleInAllFeeds(articleId, (a) => a.copyWith(isFavorited: !a.isFavorited));
    await _repo.toggleFavorite(articleId);
  }

  /// Marks an article as viewed.
  Future<void> markArticleAsViewed(String articleId) async {
    final current = state.valueOrNull;
    if (current == null) return;

    _updateArticleInAllFeeds(articleId, (a) => a.copyWith(isViewed: true));
    await _repo.markAsViewed(articleId);
  }

  /// Updates an article across ALL cached category feeds to maintain consistency.
  void _updateArticleInAllFeeds(String articleId, NewsArticle Function(NewsArticle) update) {
    // 1. Update current state
    final current = state.valueOrNull;
    if (current != null) {
      final index = current.articles.indexWhere((a) => a.id == articleId);
      if (index != -1) {
        final newArticles = [...current.articles];
        newArticles[index] = update(newArticles[index]);
        state = AsyncData(current.copyWith(articles: newArticles));
      }
    }

    // 2. Update all caches
    for (final entry in _feedCache.entries) {
      final cachedState = entry.value;
      final idx = cachedState.articles.indexWhere((a) => a.id == articleId);
      if (idx != -1) {
        final freshArticles = [...cachedState.articles];
        freshArticles[idx] = update(freshArticles[idx]);
        _feedCache[entry.key] = cachedState.copyWith(articles: freshArticles);
      }
    }
  }

  void updateCurrentIndex(int index) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(currentIndex: index));
    if (index < current.articles.length) {
      final articleId = current.articles[index].id;
      _persistence.saveCurrentArticleId(articleId);
      
      // Specialized tracking for 'For You' feed to support reset-to-main on startup
      if (current.selectedCategory == null) {
        _persistence.saveLastForYouArticleId(articleId);
      }
    }
  }

  void openChat(String articleId) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(showChatForArticleId: () => articleId));
  }

  void closeChat() {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(showChatForArticleId: () => null));
  }

  void clearPendingChat() => closeChat();

  /// Called after a cache-hit boot to establish a remote session so that
  /// subsequent [loadNextPage] calls have a valid [sessionId] + [nextCursor].
  /// Only updates session metadata in the state — does NOT replace articles.
  Future<void> _establishSessionInBackground(NewsCategory? category) async {
    if (_isDisposed) return;
    try {
      final response = await _repo.syncMoreFromRemote(
        category: category,
        limit: _kPageSize,
      );

      if (_isDisposed) return;
      final current = state.valueOrNull;
      if (current == null || current.selectedCategory != category) return;

      // Patch the state with session metadata only — keep cached articles intact.
      final patched = current.copyWith(
        sessionId: response.sessionId,
        nextCursor: () => response.nextCursor,
        hasMore: response.hasMore,
        expiresAt: response.expiresAt,
        isServerExhausted: !response.hasMore,
      );
      state = AsyncData(patched);
      _feedCache[category] = patched;
    } catch (e) {
      // Non-fatal: pagination will still work on a session that is established
      // lazily at the next loadNextPage call.
      debugPrint('[Feed] Background session establishment failed: $e');
    }
  }
  
  /// Loads secondary articles from local cache (where category is NOT primary).
  /// This is used as a fallback when the server is exhausted.
  Future<void> _loadNextPageFromLocalSecondary(FeedState current) async {
    final category = current.selectedCategory;
    if (category == null) return; // For You feed handles this via its own logic
    
    _fetchingStates.add(category);
    state = AsyncData(current.copyWith(isLoadingMore: true));

    try {
      final lastArticle = current.articles.lastOrNull;
      
      final secondaryArticles = await _repo.fetchPage(
        category: category,
        preferredCategories: ref.read(authNotifierProvider).selectedInterests,
        countryCode: ref.read(authNotifierProvider).preferredCountry,
        limit: _kPageSize,
        afterId: lastArticle?.id,
        before: lastArticle?.publishedAt,
        includeViewed: false,
        primaryOnly: false, // Allow secondary
      );
      
      final existingIds = current.articles.map((a) => a.id).toSet();
      final uniqueNew = secondaryArticles.where((a) => !existingIds.contains(a.id)).toList();
      
      final nextState = current.copyWith(
        articles: [...current.articles, ...uniqueNew],
        isLoadingMore: false,
        hasMore: uniqueNew.length >= _kPageSize, // If we got less than requested, we're done
      );
      
      state = AsyncData(nextState);
      _feedCache[category] = nextState;
    } catch (e) {
      debugPrint('[Feed] Local secondary fetch failed: $e');
      state = AsyncData(current.copyWith(isLoadingMore: false));
    } finally {
      _fetchingStates.remove(category);
    }
  }

  /// Triggered by AuthNotifier when interests or country changes.
  Future<void> _backgroundRefresh({NewsCategory? forcedCategory}) async {
    if (_isDisposed) return;
    
    // 1. Wipe all existing sessions (they are now based on old interests/country)
    _feedCache.clear();
    
    // 2. Refresh the current active feed immediately
    await refresh();
  }
  
  Future<void> applyPendingArticles() async {
    // No longer applicable in pure session-based mode without 'Pending' articles.
  }
}
