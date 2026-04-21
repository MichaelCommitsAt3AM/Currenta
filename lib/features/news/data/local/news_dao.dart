// lib/features/news/data/local/news_dao.dart

import 'package:drift/drift.dart';
import '../../domain/entities/news_article.dart';
import 'app_database.dart';

part 'news_dao.g.dart';

@DriftAccessor(
    tables: [NewsArticlesTable, ViewedArticlesTable, ChatSessionsTable])
class NewsDao extends DatabaseAccessor<AppDatabase> with _$NewsDaoMixin {
  NewsDao(super.db);

  // ── Reads ─────────────────────────────────────────────────────

  /// Watch all articles, ordered newest-first. Optionally filter by category.
  /// Uses JSON substring match to check if the stored categories list contains [category].
  Stream<List<NewsArticlesTableData>> watchArticles({
    String? category,
    List<String>? preferredCategories,
    String? countryCode,
    bool primaryOnly = false,
  }) {
    final categoryFirstPrefix = category != null ? '["$category"%' : '';
    final categoryContains = category != null ? '%"$category"%' : '';

    Expression<int> priorityExpr;
    if (category != null) {
      priorityExpr = CustomExpression<int>(
          "CASE WHEN categories LIKE '$categoryFirstPrefix' THEN 0 ELSE 1 END");
    } else if (preferredCategories != null && preferredCategories.isNotEmpty) {
      final likes = preferredCategories
          .map((c) => "categories LIKE '%\"$c\"%'")
          .join(' OR ');
      priorityExpr =
          CustomExpression<int>("CASE WHEN ($likes) THEN 0 ELSE 1 END");
    } else {
      priorityExpr = const Constant(0);
    }

    final countryBoostExpr = CustomExpression<int>(
        "CASE WHEN country_code IS NOT NULL AND country_code = '$countryCode' THEN 0 ELSE 1 END");

    final trendingTierExpr =
        CustomExpression<int>("CASE WHEN trend_score > 0 THEN 0 ELSE 1 END");

    final majorSourceTierExpr = CustomExpression<int>(
        "CASE WHEN is_major_source = 1 THEN 0 ELSE 1 END");

    final hasPriority = category != null ||
        (preferredCategories != null && preferredCategories.isNotEmpty);

    return (select(newsArticlesTable)
          ..orderBy([
            if (hasPriority)
              (_) => OrderingTerm(
                  expression: priorityExpr, mode: OrderingMode.asc),
            (_) => OrderingTerm(
                expression: trendingTierExpr, mode: OrderingMode.asc),
            (_) => OrderingTerm(
                expression: countryBoostExpr, mode: OrderingMode.asc),
            (_) => OrderingTerm(
                expression: majorSourceTierExpr, mode: OrderingMode.asc),
            (t) => OrderingTerm.desc(t.rankingScore),
            (t) => OrderingTerm.desc(t.publishedAt),
            (t) => OrderingTerm.desc(t.id),
          ])
          ..where((t) {
            final catFilter = category != null
                ? (primaryOnly
                    ? t.categories.like(categoryFirstPrefix)
                    : t.categories.like(categoryContains))
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
              ? t.categories.like('["$category"%')
              : const Constant(true)))
        .get();
  }

  Future<NewsArticlesTableData?> getArticleById(String id) {
    return (select(newsArticlesTable)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// Paginated fetch: returns [limit] articles newest-first.
  /// Uses a robust compound cursor (publishedAt, id) for paging.
  Future<List<NewsArticle>> getArticlesPage({
    String? category,
    List<String>? preferredCategories,
    String? countryCode,
    int limit = 10,
    int offset = 0,
    DateTime? before,
    String? afterId,
    bool includeViewed = false,
    bool primaryOnly = false,
  }) async {
    final categoryFirstPrefix = category != null ? '["$category"%' : '';
    final categoryContains = category != null ? '%"$category"%' : '';

    Expression<int> priorityExpr;
    if (category != null) {
      priorityExpr = CustomExpression<int>(
          "CASE WHEN categories LIKE '$categoryFirstPrefix' THEN 0 ELSE 1 END");
    } else if (preferredCategories != null && preferredCategories.isNotEmpty) {
      final likes = preferredCategories
          .map((c) => "categories LIKE '%\"$c\"%'")
          .join(' OR ');
      priorityExpr =
          CustomExpression<int>("CASE WHEN ($likes) THEN 0 ELSE 1 END");
    } else {
      priorityExpr = const Constant(0);
    }

    final countryBoostExpr = CustomExpression<int>(
        "CASE WHEN country_code IS NOT NULL AND country_code = '$countryCode' THEN 0 ELSE 1 END");

    final trendingTierExpr =
        CustomExpression<int>("CASE WHEN trend_score > 0 THEN 0 ELSE 1 END");

    final majorSourceTierExpr = CustomExpression<int>(
        "CASE WHEN is_major_source = 1 THEN 0 ELSE 1 END");

    int lastPriority = 0;
    if (afterId != null) {
      final lastArticle = await (select(newsArticlesTable)
            ..where((t) => t.id.equals(afterId)))
          .getSingleOrNull();

      if (lastArticle != null) {
        if (category != null) {
          lastPriority = (lastArticle.categories.isNotEmpty &&
                  lastArticle.categories.first.name == category)
              ? 0
              : 1;
        } else if (preferredCategories != null &&
            preferredCategories.isNotEmpty) {
          lastPriority = (lastArticle.categories
                  .any((c) => preferredCategories.contains(c.name)))
              ? 0
              : 1;
        }
      }
    }

    int lastCountryBoost = 1;
    int lastTrendingTier = 1;
    int lastMajorTier = 1;
    double lastRankingScore = 0.0;

    if (afterId != null) {
      final lastArticle = await (select(newsArticlesTable)
            ..where((t) => t.id.equals(afterId)))
          .getSingleOrNull();

      if (lastArticle != null) {
        lastCountryBoost =
            (countryCode != null && lastArticle.countryCode == countryCode)
                ? 0
                : 1;
        lastTrendingTier = (lastArticle.trendScore > 0) ? 0 : 1;
        lastMajorTier = (lastArticle.isMajorSource) ? 0 : 1;
        lastRankingScore = lastArticle.rankingScore;
      }
    }

    final hasPriority = category != null ||
        (preferredCategories != null && preferredCategories.isNotEmpty);

    final query = select(newsArticlesTable).join([
      leftOuterJoin(viewedArticlesTable,
          viewedArticlesTable.id.equalsExp(newsArticlesTable.id))
    ])
      ..orderBy([
        if (hasPriority)
          OrderingTerm(
            expression: priorityExpr,
            mode: OrderingMode.asc,
          ),
        OrderingTerm(expression: trendingTierExpr, mode: OrderingMode.asc),
        OrderingTerm(expression: countryBoostExpr, mode: OrderingMode.asc),
        OrderingTerm(expression: majorSourceTierExpr, mode: OrderingMode.asc),
        OrderingTerm.desc(newsArticlesTable.rankingScore),
        OrderingTerm.desc(newsArticlesTable.publishedAt),
        OrderingTerm.desc(newsArticlesTable.id),
      ])
      ..where(() {
        final catFilter = category != null
            ? (primaryOnly
                ? newsArticlesTable.categories.like(categoryFirstPrefix)
                : newsArticlesTable.categories.like(categoryContains))
            : (preferredCategories != null && preferredCategories.isNotEmpty)
                ? CustomExpression<bool>(
                    "(${preferredCategories.map((c) => "categories LIKE '%\"$c\"%'").join(' OR ')})",
                  )
                : const Constant(true);

        Expression<bool> cursorFilter = const Constant(true);
        if (before != null) {
          if (afterId != null) {
            // Complex compound cursor for tiered ranking
            final sameTierFilter =
                newsArticlesTable.publishedAt.isSmallerThanValue(before) |
                    (newsArticlesTable.publishedAt.equals(before) &
                        newsArticlesTable.id.isSmallerThanValue(afterId));

            final sameRankingFilter =
                (newsArticlesTable.rankingScore.equals(lastRankingScore) &
                        sameTierFilter) |
                    newsArticlesTable.rankingScore
                        .isSmallerThanValue(lastRankingScore);

            final sameMajorFilter = (majorSourceTierExpr.equals(lastMajorTier) &
                    sameRankingFilter) |
                majorSourceTierExpr.isBiggerThanValue(lastMajorTier);

            final sameCountryFilter =
                (countryBoostExpr.equals(lastCountryBoost) & sameMajorFilter) |
                    countryBoostExpr.isBiggerThanValue(lastCountryBoost);

            final sameTrendingFilter =
                (trendingTierExpr.equals(lastTrendingTier) &
                        sameCountryFilter) |
                    trendingTierExpr.isBiggerThanValue(lastTrendingTier);

            cursorFilter =
                (priorityExpr.equals(lastPriority) & sameTrendingFilter) |
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
  Future<int> countArticles({String? category, bool primaryOnly = false}) async {
    final query = selectOnly(newsArticlesTable)
      ..addColumns([newsArticlesTable.id.count()])
      ..where(category != null
          ? (primaryOnly
              ? newsArticlesTable.categories.like('["$category"%')
              : newsArticlesTable.categories.like('%"$category"%'))
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

  Stream<List<NewsArticlesTableData>> watchLikes() {
    return (select(newsArticlesTable)
          ..where((t) => t.isLiked.equals(true))
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
  /// Also cleans up associated user data (history, chat sessions).
  Future<int> deleteArticlesOlderThan(DateTime threshold) async {
    // 1. Find IDs of articles to delete
    final toDelete = selectOnly(newsArticlesTable)
      ..addColumns([newsArticlesTable.id])
      ..where(newsArticlesTable.publishedAt.isSmallerThanValue(threshold));

    final ids = (await toDelete.get())
        .map((r) => r.read(newsArticlesTable.id)!)
        .toList();
    if (ids.isEmpty) return 0;

    // 2. Cascade delete manually (since Drift doesn't always handle it on mobile without special config)
    await (delete(viewedArticlesTable)..where((t) => t.id.isIn(ids))).go();
    await (delete(chatSessionsTable)..where((t) => t.articleId.isIn(ids))).go();

    // 3. Delete main articles
    return (delete(newsArticlesTable)..where((t) => t.id.isIn(ids))).go();
  }

  /// Clears the entire articles cache.
  Future<void> deleteAllArticles() async {
    await delete(newsArticlesTable).go();
  }

  Future<void> deleteArticlesByCategory(String category) async {
    final containsCategory = '%"$category"%';
    await (delete(newsArticlesTable)
          ..where((t) => t.categories.like(containsCategory)))
        .go();
  }

  Future<void> deleteNonPersonalizedArticles() async {
    await (delete(newsArticlesTable)
          ..where((t) => t.isFavorited.equals(false) & t.isLiked.equals(false)))
        .go();
  }

  // ── Reading History ───────────────────────────────────────────

  Stream<List<NewsArticlesTableData>> watchReadingHistory({int limit = 100}) {
    final query = select(newsArticlesTable).join([
      innerJoin(viewedArticlesTable,
          viewedArticlesTable.id.equalsExp(newsArticlesTable.id))
    ])
      ..orderBy([OrderingTerm.desc(viewedArticlesTable.viewedAt)])
      ..limit(limit);

    return query.watch().map((rows) {
      return rows.map((row) => row.readTable(newsArticlesTable)).toList();
    });
  }

  Future<void> deleteViewedArticles() async {
    await delete(viewedArticlesTable).go();
  }

  Future<void> wipeAllData() async {
    await transaction(() async {
      await delete(newsArticlesTable).go();
      await delete(viewedArticlesTable).go();
      await delete(chatSessionsTable).go();
      // chatMessagesTable is not explicitly in tables list of @DriftAccessor 
      // but it is in the database.
      await db.delete(db.chatMessagesTable).go();
    });
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
        subCategories:
            subCategories, // already decoded by SubCategoryListConverter
        isPaywalled: isPaywalled,
        isLiked: isLiked,
        likesCount: likesCount,
        isFavorited: isFavorited,
        isViewed: isViewed,
        clusterId: clusterId,
        countryCode: countryCode,
        rankingScore: rankingScore,
        isMajorSource: isMajorSource,
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
        subCategories: Value(subCategories),
        isPaywalled: Value(isPaywalled),
        isLiked: Value(isLiked),
        likesCount: Value(likesCount),
        isFavorited: Value(isFavorited),
        clusterId: Value(clusterId),
        countryCode: Value(countryCode),
        rankingScore: Value(rankingScore),
        isMajorSource: Value(isMajorSource),
      );
}
