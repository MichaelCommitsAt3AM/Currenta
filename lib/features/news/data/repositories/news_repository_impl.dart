// lib/features/news/data/repositories/news_repository_impl.dart
// Cache-First strategy: serve local data immediately, then refresh from remote.

import '../../domain/entities/news_article.dart';
import '../../domain/entities/news_category.dart';
import '../../domain/repositories/news_repository.dart';
import '../local/app_database.dart';
import '../local/news_dao.dart';
import '../remote/news_remote_datasource.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/config/news_sources.dart';
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

  @override
  Future<void> triggerIngestion({
    required String feedUrl,
    String? categoryHint,
  }) async {
    try {
      await _remote.triggerIngestion(
        feedUrl: feedUrl,
        categoryHint: categoryHint,
      );
    } on AppException {
      rethrow;
    } catch (e) {
      throw ServerException('Ingestion trigger failed: $e');
    }
  }

  @override
  Future<void> triggerAllIngestion({int? limit}) async {
    final List<({String url, String category})> allFeeds = [];
    NewsSources.feeds.forEach((category, urls) {
      for (final url in urls) {
        allFeeds.add((url: url, category: category.name));
      }
    });

    allFeeds.shuffle();
    final sourcesToTrigger = limit != null ? allFeeds.take(limit) : allFeeds;

    for (final source in sourcesToTrigger) {
      try {
        await _remote.triggerIngestion(
          feedUrl: source.url,
          categoryHint: source.category,
        );
      } catch (e) {
        // Silently continue for background jobs
        // ignore: avoid_print
        print('[Repo] Failed to trigger ${source.url}: $e');
      }
    }
  }
}
