// lib/features/news/data/local/news_dao.dart

import 'package:drift/drift.dart';
import '../../domain/entities/news_article.dart';
import '../../domain/entities/news_category.dart';
import 'app_database.dart';

part 'news_dao.g.dart';

@DriftAccessor(tables: [NewsArticlesTable])
class NewsDao extends DatabaseAccessor<AppDatabase> with _$NewsDaoMixin {
  NewsDao(super.db);

  // ── Reads ─────────────────────────────────────────────────────

  /// Watch all articles, ordered newest-first. Optionally filter by category.
  Stream<List<NewsArticlesTableData>> watchArticles({String? category}) {
    return (select(newsArticlesTable)
          ..orderBy([(t) => OrderingTerm.desc(t.publishedAt)])
          ..where((t) => category != null
              ? t.category.equals(category)
              : const Constant(true)))
        .watch();
  }

  Future<List<NewsArticlesTableData>> getArticles({String? category}) {
    return (select(newsArticlesTable)
          ..orderBy([(t) => OrderingTerm.desc(t.publishedAt)])
          ..where((t) => category != null
              ? t.category.equals(category)
              : const Constant(true)))
        .get();
  }

  // ── Writes ────────────────────────────────────────────────────

  /// Bulk upsert: inserts or updates by primary key (id).
  Future<void> upsertArticles(List<NewsArticlesTableCompanion> articles) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(newsArticlesTable, articles);
    });
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
        category: NewsCategory.values.firstWhere(
          (c) => c.name == category,
          orElse: () => NewsCategory.world,
        ),
        isPaywalled: isPaywalled,
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
        category: Value(category.name),
        isPaywalled: Value(isPaywalled),
        clusterId: Value(clusterId),
      );
}
