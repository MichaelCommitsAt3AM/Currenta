// lib/features/news/domain/repositories/news_repository.dart

import '../entities/news_article.dart';
import '../entities/news_category.dart';

/// Abstract contract for all news data operations.
/// The implementation lives in the data layer (Cache-First strategy).
abstract class NewsRepository {
  /// Returns a reactive stream of locally-cached articles.
  /// Optionally filter by [category].
  Stream<List<NewsArticle>> watchFeed({NewsCategory? category});

  /// Returns a single page of locally-cached articles, newest-first.
  /// When [category] is set, results are sorted two-tier:
  ///   1. Articles where [category] is at index 0 (primary).
  ///   2. Articles where [category] appears elsewhere in the list.
  Future<List<NewsArticle>> fetchPage({
    NewsCategory? category,
    int limit = 10,
    int offset = 0,
  });

  /// Fetches fresh articles from the remote source and upserts into local cache.
  Future<void> refreshFeed();

  /// Removes articles older than the configured cache max age from local DB.
  Future<void> clearOldCache();

  /// Pre-fetches the top [count] articles for offline availability.
  Future<void> prefetchTopArticles({int count = 20});

  /// Processes all configured news sources from the NewsSources registry.
  // REMOVED (now strictly backend-controlled): triggerIngestion, triggerAllIngestion
}
