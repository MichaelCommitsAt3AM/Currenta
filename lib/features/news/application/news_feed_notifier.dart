// lib/features/news/application/news_feed_notifier.dart
// Paginated feed state — 10 articles per batch, with two-tier category sort.

import 'dart:async';
import 'package:currenta/core/config/app_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    this.isStale = false,
    this.isRefreshing = false,
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

  /// True if the feed has exceeded its soft TTL and a refresh is recommended.
  final bool isStale;

  /// True when a full feed refresh (replacement) is in progress.
  final bool isRefreshing;

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
    bool? isStale,
    bool? isRefreshing,
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
        isStale: isStale ?? this.isStale,
        isRefreshing: isRefreshing ?? this.isRefreshing,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────
@Riverpod(keepAlive: true)
class NewsFeedNotifier extends _$NewsFeedNotifier {
  NewsRepository get _repo => ref.read(newsRepositoryProvider);
  LocalPersistenceRepository get _persistence =>
      ref.read(localPersistenceRepositoryProvider);

  static const Duration _profileLoadTimeout = Duration(seconds: 8);

  /// In-memory cache to preserve feed state (articles, index, pagination status)
  /// for each category durante the session.
  final Map<NewsCategory?, FeedState> _feedCache = {};

  /// Tracks the access order of categories in the cache for LRU eviction.
  final List<NewsCategory?> _cacheAccessOrder = [];

  static const int _maxCacheSize = 5;

  /// Tracking categories with active fetches to prevent redundant requests.
  final Set<NewsCategory?> _fetchingStates = {};

  bool _isDisposed = false;

  /// Tracker for the most recent category switch request to ignore stale results.
  NewsCategory? _lastRequestedCategory;

  /// Timestamp of the last TTL check to throttle frequent resumed checks.
  DateTime? _lastTtlCheckAt;

  FeedState? _getFromCache(NewsCategory? category) {
    final cachedState = _feedCache[category];
    if (cachedState != null) {
      _cacheAccessOrder.remove(category);
      _cacheAccessOrder.add(category);
    }
    return cachedState;
  }

  void _updateCache(NewsCategory? category, FeedState newState) {
    _feedCache[category] = newState;
    _cacheAccessOrder.remove(category);
    _cacheAccessOrder.add(category);

    if (_cacheAccessOrder.length > _maxCacheSize) {
      final oldest = _cacheAccessOrder.first;
      // Never evict the category currently displayed.
      final currentCategory = state.valueOrNull?.selectedCategory;
      if (oldest != currentCategory) {
        _cacheAccessOrder.removeAt(0);
        _feedCache.remove(oldest);
        if (kDebugMode) {
          _log('[Feed] LRU Evicted category: ${oldest?.name}');
        }
      } else if (_cacheAccessOrder.length > 1) {
        final secondOldest = _cacheAccessOrder[1];
        _cacheAccessOrder.removeAt(1);
        _feedCache.remove(secondOldest);
        if (kDebugMode) {
          _log('[Feed] LRU Evicted second-oldest: ${secondOldest?.name}');
        }
      }
    }
  }

  void _clearCache() {
    _feedCache.clear();
    _cacheAccessOrder.clear();
  }

  void _log(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  @override
  Future<FeedState> build() async {
    ref.onDispose(() => _isDisposed = true);

    // 0. Trigger cache cleaning on startup.
    await _repo.clearOldCache();

    // 0.1 Initialize TTL check throttle to prevent immediate re-check on resume
    _lastTtlCheckAt = DateTime.now().toUtc();

    // 1. Watch profile (interests/country) to ensure ranking is always relevant.
    // By watching these, the build() method will automatically re-run whenever
    // personalization settings are updated, ensuring the feed is always fresh.
    final interests =
        ref.watch(authNotifierProvider.select((s) => s.selectedInterests));
    final country =
        ref.watch(authNotifierProvider.select((s) => s.preferredCountry));
    final isProfileLoaded =
        ref.watch(authNotifierProvider.select((s) => s.isProfileLoaded));

    _log(
        '[Feed] build() triggered. isProfileLoaded=$isProfileLoaded, country=$country, interestsCount=${interests.length}');

    if (!isProfileLoaded) {
      await _waitForProfileLoad();
    }

    // 3. Initialization: Preserve the current category across re-builds
    // triggered by Auth profile updates.
    final NewsCategory? savedCategoryId = _lastRequestedCategory;

    // 4. Local Fetch (Cache-First)
    List<NewsArticle> articles = await _repo.fetchPage(
      category: savedCategoryId,
      preferredCategories: interests,
      countryCode: country,
      limit: _kPageSize,
      offset: 0,
      includeViewed: false, // Only show fresh content on startup
      primaryOnly: savedCategoryId != null,
    );

    String? sessionId;
    String? nextCursor;
    bool hasMore = true;
    DateTime? expiresAt;

    // 5. Check cache validity or sync remote if empty
    bool needsRefresh = articles.isEmpty;
    bool isStale = false;

    final lastRefresh = _persistence.getLastRefreshTime();
    final now = DateTime.now().toUtc();

    if (lastRefresh != null) {
      final age = now.difference(lastRefresh.toUtc());
      _log(
          '[Feed] Checking staleness: lastRefresh=$lastRefresh, now=$now, ageHours=${age.inHours}, softTtl=${AppConfig.softTtlHours}');

      if (age.inHours >= AppConfig.hardTtlHours) {
        _log(
            '[Feed] Hard TTL exceeded (${age.inHours}h >= ${AppConfig.hardTtlHours}h)');
        needsRefresh = true;
        _persistence.saveLastForYouArticleId(null);
      } else if (age.inHours >= AppConfig.softTtlHours) {
        _log(
            '[Feed] Soft TTL exceeded (${age.inHours}h >= ${AppConfig.softTtlHours}h). Setting isStale=true');
        isStale = true;
      }
    } else if (articles.isNotEmpty) {
      // Fallback for first-time migration: if no lastRefresh is stored but we have articles,
      // use the top article's age as a one-time proxy.
      final topArticle = articles.firstOrNull;
      if (topArticle != null) {
        final age = now.difference(topArticle.publishedAt.toUtc());
        if (age.inHours >= AppConfig.hardTtlHours) {
          needsRefresh = true;
        } else if (age.inHours >= AppConfig.softTtlHours) {
          isStale = true;
        }
      }
    }

    if (needsRefresh) {
      if (articles.isEmpty) {
        // Blocking sync only if we have absolutely no data to show
        try {
          final response = await _repo.syncMoreFromRemote(
            category: savedCategoryId,
            limit: _kPageSize,
          );
          _persistence.saveLastRefreshTime(DateTime.now().toUtc());
          articles =
              _filterArticles(response.articles, interests, savedCategoryId);
          _log(
              '[Feed] Initial remote articles: ${response.articles.length} -> ${articles.length} (Interests: $interests)');
          sessionId = response.sessionId;
          nextCursor = response.nextCursor;
          hasMore = response.hasMore;
          expiresAt = response.expiresAt;
        } catch (e) {
          _log('[Feed] Initial sync failed: $e');
        }
      } else {
        // If we have stale data, return it immediately and refresh in background
        Future.microtask(_backgroundRefresh);
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
      isStale: isStale,
    );

    // 5. Initial cache seeding
    _updateCache(savedCategoryId, finalState);

    // 7. If we served from cache (no remote fetch yet), establish a session in
    //    the background so that loadNextPage() has a valid sessionId + nextCursor.
    //    Without this, every pagination call sends sessionId=null which the backend
    //    treats as a fresh session restart — returning page 1 again.
    if (sessionId == null && articles.isNotEmpty) {
      Future.microtask(() => _establishSessionInBackground(savedCategoryId));
    }

    // ── Race Condition Guard ──
    // If the user already switched categories while build() was awaiting profile/remote,
    // we must not return the 'For You' state as the initial state, as that would
    // overwrite the user's explicit choice.
    if (_lastRequestedCategory != null &&
        _lastRequestedCategory != savedCategoryId) {
      _log(
          '[Feed] build() detected late arrival. Respecting _lastRequestedCategory: ${_lastRequestedCategory?.name}');
      final cached = _getFromCache(_lastRequestedCategory);
      if (cached != null) return cached;

      final current = state.valueOrNull;
      if (current != null &&
          current.selectedCategory == _lastRequestedCategory) {
        return current;
      }

      // Fall back to whatever this build computed if we cannot recover the
      // user's already-selected category from cache/current state.
      return finalState;
    }

    return finalState;
  }

  Future<void> _waitForProfileLoad() async {
    // If already loaded, proceed immediately.
    if (ref.read(authNotifierProvider).isProfileLoaded) return;

    final completer = Completer<void>();
    Timer? timeoutTimer;
    ProviderSubscription? subscription;

    void cleanup() {
      timeoutTimer?.cancel();
      timeoutTimer = null;
      subscription?.close();
      subscription = null;
    }

    void finish() {
      if (!completer.isCompleted) {
        cleanup();
        completer.complete();
      }
    }

    // Reactive listener instead of polling reduces CPU wakeups.
    subscription = ref.listen(authNotifierProvider, (prev, next) {
      if (next.isProfileLoaded) {
        finish();
      }
    }, fireImmediately: true);

    timeoutTimer = Timer(_profileLoadTimeout, () {
      _log(
          '[Feed] Profile load timed out after ${_profileLoadTimeout.inSeconds}s. Proceeding with defaults.');
      finish();
    });

    ref.onDispose(cleanup);

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
      final current = state.valueOrNull;
      final isCategoryActive =
          current != null && current.selectedCategory == category;

      // Determine the most relevant state for this category (current active, cached, or start)
      final resolvedState =
          isCategoryActive ? current : (_getFromCache(category) ?? startState);

      // 3b. Remote Sync (Fetch next page from backend)
      final sentSessionId = resolvedState.sessionId;
      final response = await _repo.syncMoreFromRemote(
        category: category,
        sessionId: sentSessionId,
        cursor: resolvedState.nextCursor,
        limit: _kPageSize,
      );

      // Determine which state to use as base for update (either current active or cached)
      final baseState = isCategoryActive
          ? (state.valueOrNull ?? current)
          : (_getFromCache(category) ?? resolvedState);

      // 4. Session Guard: Handle session ID transitions.
      // If we sent null but now have a sessionId, verify they match to avoid double-fetching.
      // If we sent a sessionId and got a different one, it's a genuine reset.
      final currentSessionId = baseState.sessionId;

      if (response.sessionId != null) {
        if (sentSessionId != null && response.sessionId != sentSessionId) {
          // Genuine mismatch: backend session changed unexpectedly
          _triggerReset(category, response, baseState, isCategoryActive);
          return;
        } else if (sentSessionId == null &&
            currentSessionId != null &&
            response.sessionId != currentSessionId) {
          // Race condition: background establishment finished while we were fetching
          // and they resulted in different sessions.
          _triggerReset(category, response, baseState, isCategoryActive);
          return;
        }
      }

      // 5. Empty Page Guard
      if (response.articles.isEmpty) {
        if (response.hasMore && response.nextCursor != null) {
          // Server skipped ahead
          final advancedState = baseState.copyWith(
            isLoadingMore: false,
            hasMore: response.hasMore,
            nextCursor: () => response.nextCursor,
            expiresAt: response.expiresAt,
          );
          _updateCache(category, advancedState);
          if (isCategoryActive) state = AsyncData(advancedState);
        } else {
          // Genuinely no more articles
          final endState = baseState.copyWith(
            hasMore: false,
            isLoadingMore: false,
            isServerExhausted: true,
          );
          _updateCache(category, endState);
          if (isCategoryActive) state = AsyncData(endState);

          if (baseState.articles.length < 5) {
            await _loadNextPageFromLocalSecondary(endState);
          }
        }
        return;
      }

      // 6. Success: Deduplicate and Append
      final existingIds = baseState.articles.map((a) => a.id).toSet();

      final authState = ref.read(authNotifierProvider);
      final interests = authState.selectedInterests;
      final filteredNewArticles =
          _filterArticles(response.articles, interests, category);

      _log(
          '[Feed] Filtered remote articles: ${response.articles.length} -> ${filteredNewArticles.length}');

      final uniqueNewArticles = filteredNewArticles
          .where((a) => !existingIds.contains(a.id))
          .toList();

      var nextArticles = [...baseState.articles, ...uniqueNewArticles];

      if (nextArticles.length > 500) {
        nextArticles = nextArticles.sublist(0, 500);
      }

      final nextState = baseState.copyWith(
        articles: nextArticles,
        isLoadingMore: false,
        hasMore: response.hasMore,
        nextCursor: () => response.nextCursor,
        expiresAt: response.expiresAt,
      );

      _updateCache(category, nextState);
      if (isCategoryActive) state = AsyncData(nextState);
    } catch (e, st) {
      FirebaseCrashlytics.instance
          .recordError(e, st, reason: 'Paging failure in loadNextPage');
      _log('[FeedPaging] ERROR: $e\n$st');
    } finally {
      _fetchingStates.remove(category);
      final finalCurrent = state.valueOrNull;
      if (finalCurrent != null && finalCurrent.isLoadingMore) {
        state = AsyncData(finalCurrent.copyWith(isLoadingMore: false));
      }
    }
  }

  Future<void> filterByCategory(NewsCategory? category) async {
    _log('[NewsFeedNotifier] filterByCategory: ${category?.name}');
    _lastRequestedCategory = category;

    // 1. Save current state to cache before switching away.
    final oldState = state.valueOrNull;
    if (oldState != null) {
      _updateCache(
          oldState.selectedCategory, oldState.copyWith(isLoadingMore: false));
    }

    // 2. Fast Path: If category is in cache and valid, switch immediately
    final cached = _getFromCache(category);
    if (cached != null &&
        (cached.expiresAt == null ||
            DateTime.now().toUtc().isBefore(cached.expiresAt!.toUtc()))) {
      // PRODUCTION GUARD: If we're entering 'For You' and have no session yet,
      // we don't return early. This ensures we don't get stuck with a potentially
      // biased local-only cache (e.g. if the user immediately clicked another category on boot).
      if (category == null && cached.sessionId == null) {
        _log(
            '[Feed] For You cache is sessionless. Proceeding to sync to ensure diversity.');
      } else {
        // Re-sync staleness flag
        bool isStale = false;
        final lastRefresh = _persistence.getLastRefreshTime();
        if (lastRefresh != null) {
          final age = DateTime.now().toUtc().difference(lastRefresh.toUtc());
          if (age.inHours >= AppConfig.softTtlHours) {
            isStale = true;
          }
        }

        final interests = ref.read(authNotifierProvider).selectedInterests;
        final sanitizedArticles =
            _filterArticles(cached.articles, interests, category);
        final newState = cached.copyWith(
          articles: sanitizedArticles,
          isStale: isStale,
        );

        // If the cache doesn't contain any valid primary-category articles,
        // ignore it and fall through to fetch fresh data.
        if (category != null && sanitizedArticles.isEmpty) {
          _log(
              '[Feed] Cache had no primary matches for ${category.name}; fetching fresh.');
        } else {
          state = AsyncData(newState);
          _persistence.saveCurrentArticleId(newState.articles.firstOrNull?.id);

          if (newState.sessionId == null) {
            Future.microtask(() => _establishSessionInBackground(category));
          }
          return;
        }
      }
    }

    // 3. Concurrency Guard: If we are already fetching this category, don't start another one.
    if (_fetchingStates.contains(category)) {
      _log(
          '[Feed] Already fetching ${category?.name}. Ignoring redundant request.');
      return;
    }

    // Yield immediately so UI can render the category highlight & shimmer.
    state =
        AsyncData(FeedState(selectedCategory: category, isRefreshing: false));
    state = const AsyncLoading<FeedState>().copyWithPrevious(state);

    _fetchingStates.add(category);
    await Future.microtask(() {});

    try {
      // 4. Local Fetch (Cache-First)
      List<NewsArticle> localArticles = await _repo.fetchPage(
        category: category,
        preferredCategories: ref.read(authNotifierProvider).selectedInterests,
        countryCode: ref.read(authNotifierProvider).preferredCountry,
        limit: _kPageSize,
        offset: 0,
        includeViewed: false,
        primaryOnly: true,
      );

      final isCategoryStillActive = _lastRequestedCategory == category;
      const int initialIndex = 0;

      if (localArticles.isNotEmpty) {
        final newState = FeedState(
          articles: localArticles,
          selectedCategory: category,
          currentIndex: initialIndex,
          hasMore: true,
          isServerExhausted: false,
        );

        _updateCache(category, newState);

        if (isCategoryStillActive) {
          // DIVERSITY GUARD: If For You has no session yet, we show a shimmer while syncing
          if (category == null) {
            _log(
                '[Feed] Showing shimmer for For You until remote sync completes.');
            state = const AsyncLoading<FeedState>();
          } else {
            state = AsyncData(newState);
          }
        }

        // Establish remote session in background
        Future.microtask(() => _establishSessionInBackground(category));

        // If we found local articles, we can stop the blocking part of filterByCategory.
        // Even if the user switched away, we've updated the cache for when they return.
        return;
      }

      // 5. Remote Sync (Fallback)
      final response = await _repo.syncMoreFromRemote(
        category: category,
        limit: _kPageSize,
      );

      _persistence.saveLastRefreshTime(DateTime.now().toUtc());

      final interests = ref.read(authNotifierProvider).selectedInterests;
      final filteredArticles =
          _filterArticles(response.articles, interests, category);

      final newState = FeedState(
        articles: filteredArticles,
        selectedCategory: category,
        sessionId: response.sessionId,
        nextCursor: response.nextCursor,
        hasMore: response.hasMore,
        expiresAt: response.expiresAt,
        isServerExhausted: !response.hasMore,
        isStale: false,
      );

      _updateCache(category, newState);

      if (_lastRequestedCategory == category) {
        state = AsyncData(newState);
        if (newState.articles.isNotEmpty) {
          _persistence.saveCurrentArticleId(newState.articles.first.id);
        }
      }

      // ── Fallback: Secondary Content ──
      if (newState.articles.length < 5 && !response.hasMore) {
        await _loadNextPageFromLocalSecondary(newState);
      }
    } catch (e, st) {
      if (_lastRequestedCategory == category) {
        state = AsyncError(e, st);
      }
    } finally {
      _fetchingStates.remove(category);
    }
  }

  /// Full refresh: invalidates ALL cached sessions and resets to page 1 with new data.
  Future<void> refresh() async {
    final startState = state.valueOrNull;

    // Concurrency Guard: Don't start a new refresh if one is already in progress
    if (startState?.isRefreshing ?? false) {
      _log('[Feed] Refresh already in progress. Ignoring request.');
      return;
    }

    state = const AsyncLoading<FeedState>().copyWithPrevious(state);

    final currentCategory = startState?.selectedCategory;

    // 1. Hide the refresh badge immediately for better UX
    if (startState != null) {
      state =
          AsyncData(startState.copyWith(isStale: false, isRefreshing: true));
    }

    state = const AsyncLoading<FeedState>().copyWithPrevious(state);

    // Clear all cached sessions to ensure diversity fixes apply to every category
    _clearCache();

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
        isStale: false,
      );

      _persistence.saveLastRefreshTime(DateTime.now().toUtc());
      state = AsyncData(newState);
      _updateCache(currentCategory, newState);

      // Persistence: Reset scroll position to top on refresh
      if (newState.articles.isNotEmpty) {
        _persistence.saveCurrentArticleId(newState.articles.first.id);
      }
    } catch (e, st) {
      _log('[Feed] Refresh failed: $e');
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

    final now = DateTime.now().toUtc();

    // 1. Throttle & Concurrency: Avoid checking TTL more than once every 30 seconds
    // on resume, and never while a refresh is already in flight.
    if (current.isRefreshing) {
      _log(
          '[Feed] refreshIfStale: Refresh already in progress. Skipping check.');
      return;
    }

    if (_lastTtlCheckAt != null &&
        now.difference(_lastTtlCheckAt!).inSeconds < 30) {
      return;
    }
    _lastTtlCheckAt = now;

    // 2. Hard Expiry check (backend controlled)
    if (current.expiresAt != null && now.isAfter(current.expiresAt!.toUtc())) {
      _log('[Feed] refreshIfStale: Hard expiry (backend) reached. Refreshing.');
      await refresh();
      return;
    }

    // 3. TTL-based staleness check (client controlled)
    final lastRefresh = _persistence.getLastRefreshTime();
    if (lastRefresh != null) {
      final age = now.difference(lastRefresh.toUtc());
      _log(
          '[Feed] refreshIfStale check: ageHours=${age.inHours}, softTtl=${AppConfig.softTtlHours}, hardTtl=${AppConfig.hardTtlHours}, isStale=${current.isStale}');

      if (age.inHours >= AppConfig.hardTtlHours) {
        _log(
            '[Feed] refreshIfStale: Hard TTL exceeded. Triggering full refresh.');
        await refresh();
      } else if (age.inHours >= AppConfig.softTtlHours && !current.isStale) {
        _log('[Feed] refreshIfStale: Soft TTL exceeded. Setting isStale=true');
        state = AsyncData(current.copyWith(isStale: true));
      }
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

    _updateArticleInAllFeeds(
        articleId, (a) => a.copyWith(isFavorited: !a.isFavorited));
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
  void _updateArticleInAllFeeds(
      String articleId, NewsArticle Function(NewsArticle) update) {
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
        _updateCache(entry.key, cachedState.copyWith(articles: freshArticles));
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

    final startState = state.valueOrNull;
    if (startState != null &&
        startState.selectedCategory == category &&
        startState.articles.isNotEmpty &&
        !startState.isRefreshing) {
      state = AsyncData(startState.copyWith(isRefreshing: true));
    }

    try {
      final response = await _repo.syncMoreFromRemote(
        category: category,
        limit: _kPageSize,
      );

      if (_isDisposed) return;
      final current = state.valueOrNull;
      final isCategoryActive =
          current != null && current.selectedCategory == category;

      // Use the existing cache as base if the category is not active
      final base = isCategoryActive
          ? current
          : (_getFromCache(category) ?? FeedState(selectedCategory: category));

      // Deduplicate and Append: Merge remote articles into the UI state instead of discarding them.
      // This ensures Remote0-Remote9 are actually shown to the user.
      final existingIds = base.articles.map((a) => a.id).toSet();

      final authState = ref.read(authNotifierProvider);
      final interests = authState.selectedInterests;
      final filteredIncoming =
          _filterArticles(response.articles, interests, category);

      final newArticles =
          filteredIncoming.where((a) => !existingIds.contains(a.id)).toList();
      final combinedArticles = [...base.articles, ...newArticles];

      // Patch the state with session metadata AND the new articles
      final patched = base.copyWith(
        articles: combinedArticles,
        sessionId: response.sessionId,
        nextCursor: () => response.nextCursor,
        hasMore: response.hasMore,
        expiresAt: response.expiresAt,
        isServerExhausted: !response.hasMore,
        isRefreshing: false,
      );

      _updateCache(category, patched);
      if (isCategoryActive) {
        state = AsyncData(patched);
      }

      // ── Fallback: Secondary Content ──
      // If we are server-exhausted but have very few articles, immediately try to
      // load secondary-category articles from local cache to provide a better experience.
      if (combinedArticles.length < 5 && !response.hasMore) {
        await _loadNextPageFromLocalSecondary(patched);
      }
    } catch (e) {
      // Non-fatal: pagination will still work on a session that is established
      // lazily at the next loadNextPage call.
      _log('[Feed] Background session establishment failed: $e');

      final current = state.valueOrNull;
      if (current != null && current.selectedCategory == category) {
        state = AsyncData(current.copyWith(isRefreshing: false));
      }
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
      final uniqueNew =
          secondaryArticles.where((a) => !existingIds.contains(a.id)).toList();

      final nextState = current.copyWith(
        articles: [...current.articles, ...uniqueNew],
        isLoadingMore: false,
        hasMore: uniqueNew.length >=
            _kPageSize, // If we got less than requested, we're done
      );

      state = AsyncData(nextState);
      _updateCache(category, nextState);
    } catch (e) {
      _log('[Feed] Local secondary fetch failed: $e');
      state = AsyncData(current.copyWith(isLoadingMore: false));
    } finally {
      _fetchingStates.remove(category);
    }
  }

  /// Triggered by AuthNotifier when interests or country changes.
  Future<void> _backgroundRefresh({NewsCategory? forcedCategory}) async {
    if (_isDisposed) return;

    // 1. Wipe all existing sessions (they are now based on old interests/country)
    _clearCache();

    // 2. Refresh the current active feed immediately
    await refresh();
  }

  Future<void> applyPendingArticles() async {
    // No longer applicable in pure session-based mode without 'Pending' articles.
  }

  List<NewsArticle> _filterArticles(
    List<NewsArticle> articles,
    List<String> interests,
    NewsCategory? category,
  ) {
    if (category != null) {
      // HARD GATEKEEPER: Ensure every article in a category feed actually
      // belongs to that category. This prevents "leaks" from broader backend
      // buckets or local cache pollution.
      return articles.where((article) {
        if (category == NewsCategory.local) {
          return article.categories.contains(NewsCategory.local);
        }

        if (article.categories.isEmpty) return false;

        // Backend may prepend a virtual `local` marker for country-matched stories.
        // For category tabs, we treat the first non-local category as the true primary.
        final first = article.categories.first;
        final effectivePrimary =
            (first == NewsCategory.local && article.categories.length > 1)
                ? article.categories[1]
                : first;

        return effectivePrimary.name == category.name;
      }).toList();
    }

    if (interests.isEmpty)
      return articles; // No interests selected yet, show everything

    return articles.where((article) {
      // Defensive filter for 'For You' feed: Ensure at least one category matches the user's current interests.
      return article.categories.any((cat) => interests.contains(cat.name));
    }).toList();
  }

  void _triggerReset(
    NewsCategory? category,
    dynamic response,
    FeedState baseState,
    bool isCategoryActive,
  ) {
    _log(
        '[Feed] Session mismatch detected for ${category?.name}. Resetting feed.');

    final authState = ref.read(authNotifierProvider);
    final interests = authState.selectedInterests;
    final filtered = _filterArticles(response.articles, interests, category);

    final resetState = baseState.copyWith(
      articles: filtered,
      sessionId: response.sessionId,
      nextCursor: () => response.nextCursor,
      hasMore: response.hasMore,
      expiresAt: response.expiresAt,
      isLoadingMore: false,
    );

    _updateCache(category, resetState);
    if (isCategoryActive) state = AsyncData(resetState);
  }
}
