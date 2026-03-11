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
    final categoryPrefix = category != null ? '["$category"%' : '';
    final priorityExpr = category != null 
        ? CustomExpression<int>("CASE WHEN categories LIKE '$categoryPrefix' THEN 0 ELSE 1 END")
        : const Constant(0);

    return (select(newsArticlesTable)
          ..orderBy([
            if (category != null) (_) => OrderingTerm(expression: priorityExpr, mode: OrderingMode.asc),
            (t) => OrderingTerm.desc(t.publishedAt),
            (t) => OrderingTerm.desc(t.id),
          ])
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

  /// Paginated fetch: returns [limit] articles newest-first.
  /// Uses a robust compound cursor (publishedAt, id) for paging.
  Future<List<NewsArticle>> getArticlesPage({
    String? category,
    int limit = 10,
    int offset = 0,
    DateTime? before,
    String? afterId,
    bool includeViewed = false,
  }) async {
    // ... (rest of priority logic remains same)
    final categoryPrefix = category != null ? '["$category"%' : '';
    
    int lastPriority = 0;
    if (afterId != null && category != null) {
      final lastArticle = await (select(newsArticlesTable)..where((t) => t.id.equals(afterId))).getSingleOrNull();
      if (lastArticle != null) {
        lastPriority = (lastArticle.categories.isNotEmpty && lastArticle.categories.first.name == category) ? 0 : 1;
      }
    }

    final priorityExpr = category != null 
        ? CustomExpression<int>("CASE WHEN categories LIKE '$categoryPrefix' THEN 0 ELSE 1 END")
        : const Constant(0);

    final query = select(newsArticlesTable).join([
      leftOuterJoin(viewedArticlesTable,
          viewedArticlesTable.id.equalsExp(newsArticlesTable.id))
    ])
      ..orderBy([
        if (category != null)
          OrderingTerm(
            expression: priorityExpr,
            mode: OrderingMode.asc,
          ),
        OrderingTerm.desc(newsArticlesTable.publishedAt),
        OrderingTerm.desc(newsArticlesTable.id),
      ])
      ..where(() {
        final catFilter = category != null
            ? newsArticlesTable.categories.like('%"$category"%')
            : const Constant(true);

        Expression<bool> cursorFilter = const Constant(true);
        if (before != null) {
          if (afterId != null) {
            final sameTierFilter = newsArticlesTable.publishedAt
                    .isSmallerThanValue(before) |
                (newsArticlesTable.publishedAt.equals(before) &
                    newsArticlesTable.id.isSmallerThanValue(afterId));

            cursorFilter = (priorityExpr.equals(lastPriority) & sameTierFilter) |
                priorityExpr.isBiggerThanValue(lastPriority);
          } else {
            cursorFilter =
                newsArticlesTable.publishedAt.isSmallerThanValue(before);
          }
        }

        if (includeViewed) {
          return catFilter & cursorFilter;
        }

        return catFilter & cursorFilter & viewedArticlesTable.id.isNull();
      }());

    if (before == null) {
      query.limit(limit, offset: offset);
    } else {
      query.limit(limit);
    }

    final rows = await query.get();
    return rows.map((row) {
      final article = row.readTable(newsArticlesTable);
      final isViewed = row.readTableOrNull(viewedArticlesTable) != null;
      return article.toDomain(isViewed: isViewed);
    }).toList();
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
  /// Preserves user-specific state like [isFavorited] and [isLiked].
  Future<void> upsertArticles(List<NewsArticlesTableCompanion> articles) async {
    await batch((b) {
      for (final article in articles) {
        b.insert(
          newsArticlesTable,
          article,
          onConflict: DoUpdate(
            (old) => article.copyWith(
              isFavorited: const Value.absent(),
              isLiked: const Value.absent(),
              likesCount: const Value.absent(),
            ),
          ),
        );
      }
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

  Future<void> toggleFavorite(String articleId) async {
    final query = select(newsArticlesTable)
      ..where((t) => t.id.equals(articleId));
    final article = await query.getSingleOrNull();
    if (article == null) return;

    final isFavorited = !article.isFavorited;

    await (update(newsArticlesTable)..where((t) => t.id.equals(articleId)))
        .write(NewsArticlesTableCompanion(
      isFavorited: Value(isFavorited),
    ));
  }

  Stream<List<NewsArticlesTableData>> watchFavorites() {
    return (select(newsArticlesTable)
          ..where((t) => t.isFavorited.equals(true))
          ..orderBy([(t) => OrderingTerm.desc(t.publishedAt)]))
        .watch();
  }

  Future<bool> isViewed(String articleId) async {
    final query = select(viewedArticlesTable)
      ..where((t) => t.id.equals(articleId));
    final res = await query.get();
    return res.isNotEmpty;
  }

  /// Deletes all articles with publishedAt before [threshold].
  Future<int> deleteArticlesOlderThan(DateTime threshold) {
    return (delete(newsArticlesTable)
          ..where((t) => t.publishedAt.isSmallerThanValue(threshold)))
        .go();
  }

  /// Clears the entire articles cache.
  Future<void> deleteAllArticles() async {
    await delete(newsArticlesTable).go();
  }
}

// ── Domain Mapper Extension ───────────────────────────────────────

extension NewsArticleMapper on NewsArticlesTableData {
  NewsArticle toDomain({bool isViewed = false}) => NewsArticle(
        id: id,
        title: title,
        summary: summary,
        originalUrl: originalUrl,
        imageUrl: imageUrl,
        sourceName: sourceName,
        sourceFaviconUrl: sourceFaviconUrl,
        publishedAt: publishedAt,
        createdAt: createdAt,
        categories: categories, // already decoded by CategoryListConverter
        isPaywalled: isPaywalled,
        isLiked: isLiked,
        likesCount: likesCount,
        isFavorited: isFavorited,
        isViewed: isViewed,
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
        createdAt: Value(createdAt),
        // Encode List<NewsCategory> → JSON string via the TypeConverter-aware Value
        categories: Value(categories),
        isPaywalled: Value(isPaywalled),
        isLiked: Value(isLiked),
        likesCount: Value(likesCount),
        isFavorited: Value(isFavorited),
        clusterId: Value(clusterId),
      );
}
