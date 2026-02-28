// lib/features/news/domain/repositories/news_repository.dart

import '../entities/news_article.dart';
import '../entities/news_category.dart';

/// Abstract contract for all news data operations.
/// The implementation lives in the data layer (Cache-First strategy).
abstract class NewsRepository {
  /// Returns a reactive stream of locally-cached articles.
  /// Optionally filter by [category].
  Stream<List<NewsArticle>> watchFeed({NewsCategory? category});

  /// Fetches fresh articles from the remote source and upserts into local cache.
  Future<void> refreshFeed();

  /// Removes articles older than the configured cache max age from local DB.
  Future<void> clearOldCache();

  /// Pre-fetches the top [count] articles for offline availability.
  Future<void> prefetchTopArticles({int count = 20});

  /// Triggers the cloud/local ingestion pipeline for a specific [feedUrl].
  Future<void> triggerIngestion({required String feedUrl});
}
