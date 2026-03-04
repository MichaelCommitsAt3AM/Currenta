// lib/features/news/data/local/news_dao.dart

import 'package:drift/drift.dart';
import '../../domain/entities/news_article.dart';
import 'app_database.dart';

part 'news_dao.g.dart';

@DriftAccessor(tables: [NewsArticlesTable, ViewedArticlesTable])
class NewsDao extends DatabaseAccessor<AppDatabase> with _$NewsDaoMixin {
  NewsDao(super.db);

  // ── Reads ─────────────────────────────────────────────────────

  /// Watch all articles, ordered newest-first. Optionally filter by category.
  /// Uses JSON substring match to check if the stored categories list contains [category].
  Stream<List<NewsArticlesTableData>> watchArticles({String? category}) {
    return (select(newsArticlesTable)
          ..orderBy([(t) => OrderingTerm.desc(t.publishedAt)])
          ..where((t) {
            final catFilter = category != null
                ? t.categories.like('%"$category"%')
                : const Constant(true);
            final viewedIds = selectOnly(viewedArticlesTable)
              ..addColumns([viewedArticlesTable.id]);
            return catFilter & t.id.isNotInQuery(viewedIds);
          }))
        .watch();
  }

  Future<List<NewsArticlesTableData>> getArticles({String? category}) {
    return (select(newsArticlesTable)
          ..orderBy([(t) => OrderingTerm.desc(t.publishedAt)])
          ..where((t) => category != null
              ? t.categories.like('%"$category"%')
              : const Constant(true)))
        .get();
  }

  /// Paginated fetch: returns [limit] articles starting at [offset], newest-first.
  /// Optionally filters by category (JSON substring match).
  Future<List<NewsArticlesTableData>> getArticlesPage({
    String? category,
    int limit = 10,
    int offset = 0,
  }) {
    return (select(newsArticlesTable)
          ..orderBy([(t) => OrderingTerm.desc(t.publishedAt)])
          ..where((t) {
            final catFilter = category != null
                ? t.categories.like('%"$category"%')
                : const Constant(true);
            final viewedIds = selectOnly(viewedArticlesTable)
              ..addColumns([viewedArticlesTable.id]);
            return catFilter & t.id.isNotInQuery(viewedIds);
          })
          ..limit(limit, offset: offset))
        .get();
  }

  /// Returns the total number of locally-cached articles (optionally filtered by category).
  Future<int> countArticles({String? category}) async {
    final query = selectOnly(newsArticlesTable)
      ..addColumns([newsArticlesTable.id.count()])
      ..where(category != null
          ? newsArticlesTable.categories.like('%"$category"%')
          : const Constant(true));
    final result = await query.getSingle();
    return result.read(newsArticlesTable.id.count()) ?? 0;
  }

  // ── Writes ────────────────────────────────────────────────────

  /// Bulk upsert: inserts or updates by primary key (id).
  Future<void> upsertArticles(List<NewsArticlesTableCompanion> articles) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(newsArticlesTable, articles);
    });
  }

  // ── Viewed Articles ───────────────────────────────────────────

  Future<void> recordView(String articleId) async {
    await into(viewedArticlesTable).insert(
      ViewedArticlesTableCompanion.insert(id: articleId),
      mode: InsertMode.insertOrIgnore,
    );
  }

  Future<void> toggleLike(String articleId) async {
    final query = select(newsArticlesTable)
      ..where((t) => t.id.equals(articleId));
    final article = await query.getSingleOrNull();
    if (article == null) return;

    final isLiked = !article.isLiked;
    final likesCount =
        isLiked ? article.likesCount + 1 : article.likesCount - 1;

    await (update(newsArticlesTable)..where((t) => t.id.equals(articleId)))
        .write(NewsArticlesTableCompanion(
      isLiked: Value(isLiked),
      likesCount: Value(likesCount.clamp(0, 999999)),
    ));
  }

  Future<bool> isViewed(String articleId) async {
    final query = select(viewedArticlesTable)
      ..where((t) => t.id.equals(articleId));
    final res = await query.get();
    return res.isNotEmpty;
  }

  // ── Cache Cleanup ─────────────────────────────────────────────

  /// Deletes all articles with publishedAt before [threshold].
  Future<int> deleteArticlesOlderThan(DateTime threshold) {
    return (delete(newsArticlesTable)
          ..where((t) => t.publishedAt.isSmallerThanValue(threshold)))
        .go();
  }
}

// ── Domain Mapper Extension ───────────────────────────────────────

extension NewsArticleMapper on NewsArticlesTableData {
  NewsArticle toDomain() => NewsArticle(
        id: id,
        title: title,
        summary: summary,
        originalUrl: originalUrl,
        imageUrl: imageUrl,
        sourceName: sourceName,
        sourceFaviconUrl: sourceFaviconUrl,
        publishedAt: publishedAt,
        categories: categories, // already decoded by CategoryListConverter
        isPaywalled: isPaywalled,
        isLiked: isLiked,
        likesCount: likesCount,
        clusterId: clusterId,
      );
}

extension NewsArticleDboMapper on NewsArticle {
  NewsArticlesTableCompanion toCompanion() => NewsArticlesTableCompanion(
        id: Value(id),
        title: Value(title),
        summary: Value(summary),
        originalUrl: Value(originalUrl),
        imageUrl: Value(imageUrl),
        sourceName: Value(sourceName),
        sourceFaviconUrl: Value(sourceFaviconUrl),
        publishedAt: Value(publishedAt),
        // Encode List<NewsCategory> → JSON string via the TypeConverter-aware Value
        categories: Value(categories),
        isPaywalled: Value(isPaywalled),
        isLiked: Value(isLiked),
        likesCount: Value(likesCount),
        clusterId: Value(clusterId),
      );
}
