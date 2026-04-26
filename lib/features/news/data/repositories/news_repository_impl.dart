// lib/features/news/data/repositories/news_repository_impl.dart
// Cache-First strategy: serve local data immediately, then refresh from remote.

import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import '../../domain/entities/feed_response.dart';
import '../../domain/entities/news_article.dart';
import '../../domain/entities/news_category.dart';
import '../../domain/repositories/news_repository.dart';
import '../local/app_database.dart';
import '../local/news_dao.dart';
import '../remote/news_remote_datasource.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/errors/app_exception.dart';

import '../../../auth/domain/repositories/auth_repository.dart';

class NewsRepositoryImpl implements NewsRepository {
  NewsRepositoryImpl({
    required AppDatabase database,
    required NewsRemoteDataSource remote,
    required AuthRepository auth,
  })  : _dao = NewsDao(database),
        _remote = remote,
        _auth = auth;

  final NewsDao _dao;
  final NewsRemoteDataSource _remote;
  final AuthRepository _auth;

  // ── Watch (reactive stream from local DB) ──────────────────────

  @override
  Stream<List<NewsArticle>> watchFeed({
    NewsCategory? category,
    List<String>? preferredCategories,
    String? countryCode,
    bool primaryOnly = false,
  }) {
    return _dao
        .watchArticles(
          category: category?.name,
          preferredCategories: preferredCategories,
          countryCode: countryCode,
          primaryOnly: primaryOnly,
        )
        .map((rows) => rows.map((r) => r.toDomain()).toList());
  }

  // ── Paginated fetch with two-tier category sort ────────────────

  @override
  Future<List<NewsArticle>> fetchPage({
    NewsCategory? category,
    List<String>? preferredCategories,
    String? countryCode,
    int limit = 10,
    int offset = 0,
    DateTime? before,
    String? afterId,
    bool includeViewed = false,
    bool primaryOnly = false,
  }) async {
    return _dao.getArticlesPage(
      category: category?.name,
      preferredCategories: preferredCategories,
      countryCode: countryCode,
      limit: limit,
      offset: offset,
      before: before,
      afterId: afterId,
      includeViewed: includeViewed,
      primaryOnly: primaryOnly,
    );
  }

  // ── Refresh (remote → local upsert) ───────────────────────────

  @override
  Future<void> refreshFeed() async {
    try {
      final country = await _auth.getPreferredCountry();
      // Background refresh usually starts a fresh "sessionless" fetch
      final feedResponse = await _remote.fetchArticles(country: country);
      final companions = feedResponse.articles.map((a) => a.toCompanion()).toList();
      await _dao.upsertArticles(companions);
    } on AppException {
      rethrow;
    } catch (e) {
      throw ServerException('Failed to refresh feed: $e');
    }
  }

  /// Fetches a batch of articles from remote using session/cursor
  /// and upserts them into the local cache.
  /// Returns a FeedResponse containing the new articles and session metadata.
  @override
  Future<FeedResponse> syncMoreFromRemote({
    NewsCategory? category,
    String? sessionId,
    String? cursor,
    int limit = 30,
  }) async {
    final catName = category?.name ?? 'all';

    try {
      final country = await _auth.getPreferredCountry();
      final feedResponse = await _remote.fetchArticles(
        category: category,
        country: country,
        limit: limit,
        sessionId: sessionId,
        cursor: cursor,
      );

      if (feedResponse.articles.isEmpty) {
        return feedResponse;
      }

      final companions = feedResponse.articles.map((a) => a.toCompanion()).toList();
      await _dao.upsertArticles(companions);

      return feedResponse;
    } on AppException catch (e, st) {
      FirebaseCrashlytics.instance.recordError(e, st, reason: 'AppException in syncMoreFromRemote ($catName)');
      rethrow;
    } catch (e, st) {
      FirebaseCrashlytics.instance.recordError(e, st, reason: 'Unexpected error in syncMoreFromRemote ($catName)');
      throw ServerException('syncMoreFromRemote failed: $e');
    }
  }

  // ── Cache Cleanup ─────────────────────────────────────────────

  @override
  Future<void> clearOldCache() async {
    final threshold = DateTime.now().subtract(
      Duration(hours: AppConfig.cacheMaxAgeHours),
    );
    try {
      await _dao.deleteArticlesOlderThan(threshold);
    } catch (e) {
      throw CacheException();
    }
  }

  @override
  Future<void> clearCache() async {
    try {
      await _dao.deleteAllArticles();
    } catch (e) {
      debugPrint('[Cache] clearCache error: $e');
      throw CacheException();
    }
  }

  @override
  Future<void> clearFeed() async {
    try {
      await _dao.deleteNonPersonalizedArticles();
    } catch (e) {
      debugPrint('[Cache] clearFeed error: $e');
      throw CacheException();
    }
  }

  @override
  Future<void> deleteArticlesByCategory(String category) async {
    try {
      await _dao.deleteArticlesByCategory(category);
    } catch (e) {
      throw CacheException();
    }
  }

  // ── Background Prefetch ───────────────────────────────────────

  @override
  Future<void> prefetchTopArticles(
      {int count = AppConfig.backgroundPrefetchCount}) async {
    try {
      final country = await _auth.getPreferredCountry();
      final feedResponse = await _remote.fetchArticles(limit: count, country: country);
      await _dao.upsertArticles(feedResponse.articles.map((a) => a.toCompanion()).toList());
    } on AppException {
      rethrow;
    } catch (e) {
      throw ServerException('Prefetch failed: $e');
    }
  }

  @override
  Future<void> markAsViewed(String articleId) async {
    // 1. Record locally immediately (for instant filtering in same session)
    await _dao.recordView(articleId);

    // 2. Report to backend
    await _remote.trackArticleView(articleId);
  }

  @override
  Future<void> toggleLike(String articleId) async {
    // 1. Toggle locally
    await _dao.toggleLike(articleId);

    // 2. Sync with backend
    await _remote.toggleArticleLike(articleId);
  }

  @override
  Future<void> toggleFavorite(String articleId) async {
    // 1. Toggle locally
    await _dao.toggleFavorite(articleId);

    // 2. Sync with backend
    await _remote.toggleArticleFavorite(articleId);
  }

  @override
  Stream<List<NewsArticle>> watchFavorites() {
    return _dao
        .watchFavorites()
        .map((rows) => rows.map((r) => r.toDomain()).toList());
  }

  @override
  Stream<List<NewsArticle>> watchLikes() {
    return _dao
        .watchLikes()
        .map((rows) => rows.map((r) => r.toDomain()).toList());
  }

  @override
  Future<bool> syncLikedArticles({int limit = 30, int offset = 0}) async {
    try {
      final response = await _remote.fetchLikedArticles(limit: limit, offset: offset);
      final articlesJson = response['articles'] as List<dynamic>;
      final hasMore = response['has_more'] as bool;

      if (articlesJson.isEmpty) return false;

      final articles = articlesJson
          .map((json) => NewsArticle.fromJson(json as Map<String, dynamic>))
          .toList();

      final companions = articles.map((a) => a.toCompanion()).toList();
      await _dao.upsertArticles(companions);

      // Force mark them as liked in local DB in bulk
      final ids = articles.map((a) => a.id).toList();
      await _dao.setLikesBulk(ids, true);

      return hasMore;
    } catch (e) {
      debugPrint('[Repo] syncLikedArticles error: $e');
      rethrow;
    }
  }

  @override
  Stream<List<NewsArticle>> watchReadingHistory() {
    return _dao
        .watchReadingHistory()
        .map((rows) => rows.map((r) => r.toDomain(isViewed: true)).toList());
  }

  @override
  Future<void> clearReadingHistory() async {
    try {
      await _dao.deleteViewedArticles();
    } catch (e) {
      throw CacheException();
    }
  }

  @override
  Future<NewsArticle?> getArticleById(String id) async {
    final row = await _dao.getArticleById(id);
    if (row == null) return null;
    final isViewed = await _dao.isViewed(id);
    return row.toDomain(isViewed: isViewed);
  }

  @override
  Future<List<NewsArticle>> fetchTrending({int limit = 20, String? country}) async {
    try {
      final remoteArticles = await _remote.fetchTrendingArticles(limit: limit, country: country);
      // We don't necessarily want to cache these, or we can upsert if we want them available offline.
      // Let's upsert them so they appear in the feed too if relevant.
      final companions = remoteArticles.map((a) => a.toCompanion()).toList();
      await _dao.upsertArticles(companions);
      return remoteArticles;
    } on AppException {
      rethrow;
    } catch (e) {
      throw ServerException('Failed to fetch trending: $e');
    }
  }

  @override
  Future<void> wipeLocalData() async {
    try {
      await _dao.wipeAllData();
    } catch (e) {
       debugPrint('[Cache] wipeLocalData error: $e');
    }
  }

  @override
  Future<void> clearRemoteUserState() async {
    await _remote.clearUserState();
  }
}
