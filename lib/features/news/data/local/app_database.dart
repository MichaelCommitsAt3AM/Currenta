// lib/features/news/data/local/app_database.dart

import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import '../../domain/entities/news_category.dart';

part 'app_database.g.dart';

// ── TypeConverter: List<NewsCategory> ↔ JSON string ──────────────────────────

class CategoryListConverter extends TypeConverter<List<NewsCategory>, String> {
  const CategoryListConverter();

  @override
  List<NewsCategory> fromSql(String fromDb) {
    try {
      final list = (jsonDecode(fromDb) as List<dynamic>);
      return list
          .map((e) => NewsCategory.values.firstWhere(
                (c) => c.name == e.toString(),
                orElse: () => NewsCategory.world,
              ))
          .toList();
    } catch (_) {
      return [NewsCategory.world];
    }
  }

  @override
  String toSql(List<NewsCategory> value) =>
      jsonEncode(value.map((c) => c.name).toList());
}

// ── Table Definitions ─────────────────────────────────────────────

class NewsArticlesTable extends Table {
  @override
  String get tableName => 'news_articles';

  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get summary => text()();
  TextColumn get originalUrl => text().named('original_url')();
  TextColumn get imageUrl => text().named('image_url').nullable()();
  TextColumn get sourceName => text().named('source_name')();
  TextColumn get sourceFaviconUrl =>
      text().named('source_favicon_url').nullable()();
  DateTimeColumn get publishedAt => dateTime().named('published_at')();
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();

  /// Stored as a JSON-encoded list, e.g. '["tech","politics"]'
  TextColumn get categories => text()
      .map(const CategoryListConverter())
      .withDefault(const Constant('["world"]'))();

  BoolColumn get isPaywalled =>
      boolean().named('is_paywalled').withDefault(const Constant(false))();
  BoolColumn get isLiked =>
      boolean().named('is_liked').withDefault(const Constant(false))();
  BoolColumn get isFavorited =>
      boolean().named('is_favorited').withDefault(const Constant(false))();
  IntColumn get likesCount =>
      integer().named('likes_count').withDefault(const Constant(0))();
  TextColumn get clusterId => text().named('cluster_id').nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class ViewedArticlesTable extends Table {
  @override
  String get tableName => 'viewed_articles';

  TextColumn get id => text()(); // articleId
  DateTimeColumn get viewedAt =>
      dateTime().named('viewed_at').withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// ── Database ──────────────────────────────────────────────────────

@DriftDatabase(tables: [NewsArticlesTable, ViewedArticlesTable])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(newsArticlesTable, newsArticlesTable.categories);
          }
          if (from < 3) {
            await m.createTable(viewedArticlesTable);
          }
          if (from < 4) {
            await m.addColumn(newsArticlesTable, newsArticlesTable.isLiked);
            await m.addColumn(newsArticlesTable, newsArticlesTable.likesCount);
          }
          if (from < 5) {
            await m.addColumn(newsArticlesTable, newsArticlesTable.isFavorited);
          }
          if (from < 6) {
            await m.addColumn(newsArticlesTable, newsArticlesTable.createdAt);
          }
        },
      );

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'currenta_db');
  }
}
