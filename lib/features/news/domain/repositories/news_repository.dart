// lib/features/news/domain/repositories/news_repository.dart

import '../entities/news_article.dart';
import '../entities/news_category.dart';

/// Abstract contract for all news data operations.
/// The implementation lives in the data layer (Cache-First strategy).
abstract class NewsRepository {
  /// Returns a reactive stream of locally-cached articles.
  /// Optionally filter by [category].
  Stream<List<NewsArticle>> watchFeed({
    NewsCategory? category,
    List<String>? preferredCategories,
    String? countryCode,
  });

  /// Returns a single page of locally-cached articles, newest-first.
  /// When [category] is set, results are sorted two-tier.
  /// When [category] is null, [preferredCategories] are used to prioritize stories.
  Future<List<NewsArticle>> fetchPage({
    NewsCategory? category,
    List<String>? preferredCategories,
    String? countryCode,
    int limit = 10,
    int offset = 0,
    DateTime? before,
    String? afterId,
    bool includeViewed = false,
  });

  /// Fetches fresh articles from the remote source and upserts into local cache.
  Future<void> refreshFeed();

  /// Fetches a batch of articles from remote and syncs to local cache.
  /// Returns the number of articles synced.
  Future<int> syncMoreFromRemote({
    NewsCategory? category,
    int remoteOffset = 0,
    DateTime? before,
    int limit = 30,
  });

  /// Removes articles older than the configured cache max age from local DB.
  Future<void> clearOldCache();

  /// Completely clears the local articles cache.
  Future<void> clearCache();

  /// Removes articles from the local cache that match the specified category.
  Future<void> deleteArticlesByCategory(String category);

  /// Pre-fetches the top [count] articles for offline availability.
  Future<void> prefetchTopArticles({int count = 20});

  /// Marks an article as viewed both locally and on the server.
  Future<void> markAsViewed(String articleId);

  /// Toggles the like status of an article.
  Future<void> toggleLike(String articleId);

  /// Toggles the favorite status of an article.
  Future<void> toggleFavorite(String articleId);

  /// Returns a stream of favorited articles.
  Stream<List<NewsArticle>> watchFavorites();

  /// Returns a stream of liked articles.
  Stream<List<NewsArticle>> watchLikes();

  /// Returns a stream of recently viewed articles, newest-first.
  Stream<List<NewsArticle>> watchReadingHistory();

  /// Clears the local reading history (viewed articles).
  Future<void> clearReadingHistory();
  
  /// Fetches global trending articles directly from remote.
  Future<List<NewsArticle>> fetchTrending({int limit = 20, String? country});

  /// Returns a single article by its identifier.
  Future<NewsArticle?> getArticleById(String id);
}
