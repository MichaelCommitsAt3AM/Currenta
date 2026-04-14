// lib/features/news/application/news_feed_notifier.dart
// Paginated feed state — 10 articles per batch, with two-tier category sort.

import 'dart:async';
import 'package:currenta/core/config/app_config.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../domain/entities/news_article.dart';
import '../domain/entities/news_category.dart';
import '../domain/entities/feed_response.dart';
import '../domain/repositories/news_repository.dart';
import '../../../core/providers/providers.dart';
import '../../auth/application/auth_notifier.dart';

import 'pending_activity_provider.dart';
import '../data/repositories/local_persistence_repository.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

part 'news_feed_notifier.g.dart';

const _kPageSize = 10;

// ── Feed State ────────────────────────────────────────────────────────────────

/// Enum for pending activities that require user attention.
enum PendingActivityType { viewHistory, none }

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
      debugPrint('[Feed] Waiting for auth profile to load...');
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

    // 3. Initialization: Default to 'For You' (null category)
    const NewsCategory? savedCategoryId = null;
    final savedArticleId = _persistence.getCurrentArticleId();
    final bool includeViewed = savedArticleId != null;

    // 4. Local Fetch (Cache-First)
    List<NewsArticle> articles = await _repo.fetchPage(
      category: savedCategoryId,
      preferredCategories: interests,
      countryCode: auth.preferredCountry,
      limit: savedArticleId != null ? 30 : _kPageSize,
      offset: 0,
      includeViewed: includeViewed,
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
        } else if (age.inHours >= AppConfig.softTtlHours) {
          Future.microtask(_backgroundRefresh);
        }
      }
    }

    if (needsRefresh) {
      debugPrint('[Feed] Initializing fresh session...');
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

    // 6. Position restoration
    int initialIndex = 0;
    if (savedArticleId != null && articles.isNotEmpty) {
      final index = articles.indexWhere((a) => a.id == savedArticleId);
      if (index != -1) initialIndex = index;
    }

    final finalState = FeedState(
      articles: articles,
      hasMore: hasMore,
      selectedCategory: savedCategoryId,
      currentIndex: initialIndex,
      sessionId: sessionId,
      nextCursor: nextCursor,
      expiresAt: expiresAt,
      includeViewedInPaging: false,
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
    if (startState == null || !startState.hasMore) return;

    final category = startState.selectedCategory;

    // 1. Concurrency Guard: prevent duplicate fetches for the same category
    if (_fetchingStates.contains(category)) {
      debugPrint('[FeedPaging] Category ${category?.name ?? 'all'} is already fetching.');
      return;
    }

    _fetchingStates.add(category);
    state = AsyncData(startState.copyWith(isLoadingMore: true));

    try {
      if (_isDisposed) return;
      
      // 2. Session Validity Check (Client-side TTL fallback)
      if (startState.expiresAt != null && 
          DateTime.now().isAfter(startState.expiresAt!)) {
        debugPrint('[FeedPaging] Session expired. Resetting category ${category?.name ?? 'all'}.');
        await filterByCategory(category);
        return;
      }

      // 3. Remote Sync (Fetch next page from backend)
      final response = await _repo.syncMoreFromRemote(
        category: category,
        sessionId: startState.sessionId,
        cursor: startState.nextCursor,
        limit: _kPageSize,
      );

      final current = state.valueOrNull;
      if (current == null || current.selectedCategory != category) return;

      // 4. Session Guard: If backend silently reset the session, client must reset local list too.
      if (response.sessionId != null && response.sessionId != current.sessionId) {
        debugPrint('[FeedPaging] Session ID mismatch! Performing hard reset.');
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

      // 5. Empty Page Guard: break potential infinite loops if hasMore is true but articles are empty
      if (response.articles.isEmpty) {
        debugPrint('[FeedPaging] Received empty articles page. Stopping pagination.');
        final endState = current.copyWith(
          hasMore: false,
          isLoadingMore: false,
        );
        state = AsyncData(endState);
        _feedCache[category] = endState;
        return;
      }

      // 6. Success: Append new articles to the existing list
      final nextState = current.copyWith(
        articles: [...current.articles, ...response.articles],
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

  /// Switches the feed to a different category, implementing Lazy Session creation.
  Future<void> filterByCategory(NewsCategory? category) async {
    // 1. Save current state to cache before switching away.
    final oldState = state.valueOrNull;
    if (oldState != null) {
      _feedCache[oldState.selectedCategory] = oldState.copyWith(isLoadingMore: false);
    }

    // 2. Check if we have a valid, unexpired session in cache
    final cached = _feedCache[category];
    if (cached != null && 
        (cached.expiresAt == null || DateTime.now().isBefore(cached.expiresAt!))) {
      debugPrint('[Feed] Reusing valid session for category ${category?.name ?? 'all'}.');
      state = AsyncData(cached);
      _persistence.saveCurrentArticleId(cached.articles.firstOrNull?.id);
      return;
    }

    // 3. Start a fresh session
    debugPrint('[Feed] Creating a lazy session for category ${category?.name ?? 'all'}...');
    state = const AsyncLoading<FeedState>();

    try {
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

  /// Full refresh: re-syncs remote data then resets to page 1.
  Future<void> refresh() async {
    final startState = state.valueOrNull;
    state = AsyncLoading<FeedState>().copyWithPrevious(state);

    final currentCategory = startState?.selectedCategory;
    
    try {
      final response = await _repo.syncMoreFromRemote(
        category: currentCategory,
        limit: _kPageSize,
      );

      final newState = FeedState(
        articles: response.articles,
        selectedCategory: currentCategory,
        sessionId: response.sessionId,
        nextCursor: response.nextCursor,
        hasMore: response.hasMore,
        expiresAt: response.expiresAt,
      );

      state = AsyncData(newState);
      _feedCache[currentCategory] = newState;
    } catch (e, st) {
      state = AsyncData(startState!).copyWithPrevious(AsyncError(e, st));
    }
  }

  Future<void> refreshIfStale() async {
    final current = state.valueOrNull;
    if (current == null) return;

    if (current.expiresAt != null && DateTime.now().isAfter(current.expiresAt!)) {
      debugPrint('[Feed] Session stale on resume. Refreshing...');
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
      _persistence.saveCurrentArticleId(current.articles[index].id);
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

  Future<void> _handlePendingActivity(PendingActivityType activity) async {
    debugPrint('[Feed] Handling pending activity: $activity');
    if (activity == PendingActivityType.viewHistory) {
      // Logic to switch to a history view if we had one
    }
  }

  Future<void> _backgroundRefresh({NewsCategory? forcedCategory}) async {
    // Background refresh logic in session-based mode usually just checks for "Newer" sessions.
    // For now, we can skip implementing this to focus on core stability.
  }
  
  Future<void> applyPendingArticles() async {
    // No longer applicable in pure session-based mode without 'Pending' articles.
  }
}
