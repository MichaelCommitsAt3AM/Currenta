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

// ── Table Definition ──────────────────────────────────────────────

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

  /// Stored as a JSON-encoded list, e.g. '["tech","politics"]'
  TextColumn get categories => text()
      .map(const CategoryListConverter())
      .withDefault(const Constant('["world"]'))();

  BoolColumn get isPaywalled =>
      boolean().named('is_paywalled').withDefault(const Constant(false))();
  TextColumn get clusterId => text().named('cluster_id').nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// ── Database ──────────────────────────────────────────────────────

@DriftDatabase(tables: [NewsArticlesTable])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // Add the new `categories` column (JSON text) for multi-label support.
            // Articles without it will use the default value '["world"]'.
            await m.issueCustomQuery(
              'ALTER TABLE news_articles ADD COLUMN IF NOT EXISTS '
              "categories TEXT NOT NULL DEFAULT '[\"world\"]'",
            );
          }
        },
      );

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'currenta_db');
  }
}
