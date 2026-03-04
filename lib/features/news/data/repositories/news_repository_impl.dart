// lib/features/news/data/repositories/news_repository_impl.dart
// Cache-First strategy: serve local data immediately, then refresh from remote.

import '../../domain/entities/news_article.dart';
import '../../domain/entities/news_category.dart';
import '../../domain/repositories/news_repository.dart';
import '../local/app_database.dart';
import '../local/news_dao.dart';
import '../remote/news_remote_datasource.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/errors/app_exception.dart';

class NewsRepositoryImpl implements NewsRepository {
  NewsRepositoryImpl({
    required AppDatabase database,
    required NewsRemoteDataSource remote,
  })  : _dao = NewsDao(database),
        _remote = remote;

  final NewsDao _dao;
  final NewsRemoteDataSource _remote;

  // ── Watch (reactive stream from local DB) ──────────────────────

  @override
  Stream<List<NewsArticle>> watchFeed({NewsCategory? category}) {
    return _dao
        .watchArticles(category: category?.name)
        .map((rows) => rows.map((r) => r.toDomain()).toList());
  }

  // ── Paginated fetch with two-tier category sort ────────────────

  @override
  Future<List<NewsArticle>> fetchPage({
    NewsCategory? category,
    int limit = 10,
    int offset = 0,
  }) async {
    final rows = await _dao.getArticlesPage(
      category: category?.name,
      limit: limit,
      offset: offset,
    );
    final articles = rows.map((r) => r.toDomain()).toList();

    if (category == null) return articles;

    // Two-tier sort:
    //   Tier 1 — category is at index 0 (primary category)
    //   Tier 2 — category appears elsewhere in the list
    final primary = <NewsArticle>[];
    final secondary = <NewsArticle>[];
    for (final a in articles) {
      if (a.categories.isNotEmpty && a.categories.first == category) {
        primary.add(a);
      } else {
        secondary.add(a);
      }
    }
    return [...primary, ...secondary];
  }

  // ── Refresh (remote → local upsert) ───────────────────────────

  @override
  Future<void> refreshFeed() async {
    try {
      final remoteArticles = await _remote.fetchArticles();
      final companions = remoteArticles.map((a) => a.toCompanion()).toList();
      await _dao.upsertArticles(companions);
    } on AppException {
      rethrow;
    } catch (e) {
      throw ServerException('Failed to refresh feed: $e');
    }
  }

  /// Fetches a batch of [limit] articles from remote starting at [remoteOffset]
  /// and upserts them into the local cache.
  /// Returns the number of articles written (0 = no more remote data).
  Future<int> syncMoreFromRemote({
    NewsCategory? category,
    int remoteOffset = 0,
    int limit = 30,
  }) async {
    try {
      final remoteArticles = await _remote.fetchArticles(
        category: category,
        limit: limit,
        offset: remoteOffset,
      );
      if (remoteArticles.isEmpty) return 0;
      final companions = remoteArticles.map((a) => a.toCompanion()).toList();
      await _dao.upsertArticles(companions);
      return remoteArticles.length;
    } on AppException {
      rethrow;
    } catch (e) {
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
      final deleted = await _dao.deleteArticlesOlderThan(threshold);
      // ignore: avoid_print
      print(
          '[Cache] Deleted $deleted stale articles (older than ${AppConfig.cacheMaxAgeHours}h).');
    } catch (e) {
      throw CacheException();
    }
  }

  // ── Background Prefetch ───────────────────────────────────────

  @override
  Future<void> prefetchTopArticles(
      {int count = AppConfig.backgroundPrefetchCount}) async {
    try {
      final articles = await _remote.fetchArticles(limit: count);
      await _dao.upsertArticles(articles.map((a) => a.toCompanion()).toList());
    } on AppException {
      rethrow;
    } catch (e) {
      throw ServerException('Prefetch failed: $e');
    }
  }
}
