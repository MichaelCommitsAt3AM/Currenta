// lib/features/news/data/local/app_database.dart

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

// ── Table Definition ──────────────────────────────────────────────

class NewsArticlesTable extends Table {
  @override
  String get tableName => 'news_articles';

  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get summary => text()();
  TextColumn get originalUrl => text().named('original_url')();
  TextColumn get sourceName => text().named('source_name')();
  TextColumn get sourceFaviconUrl =>
      text().named('source_favicon_url').nullable()();
  DateTimeColumn get publishedAt => dateTime().named('published_at')();
  TextColumn get category => text().withDefault(const Constant('world'))();
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
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'currenta_db');
  }
}
