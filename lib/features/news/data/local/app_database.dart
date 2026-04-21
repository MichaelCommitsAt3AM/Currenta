// lib/features/news/data/local/app_database.dart

import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../domain/entities/news_category.dart';
import '../../../../core/storage/secure_storage_service.dart';

part 'app_database.g.dart';

void _configureSqlCipherForAndroid() {
  if (!Platform.isAndroid) return;
  open.overrideFor(OperatingSystem.android, openCipherOnAndroid);
}

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

class SubCategoryListConverter
    extends TypeConverter<List<NewsSubCategory>, String> {
  const SubCategoryListConverter();

  @override
  List<NewsSubCategory> fromSql(String fromDb) {
    try {
      final list = (jsonDecode(fromDb) as List<dynamic>);
      return list
          .map((e) => NewsSubCategory.values.firstWhere(
                (c) => c.name == e.toString(),
                // If it fails to find, we just skip it or return a default?
                // Since this is for personalization, skipping unknown might be best.
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  String toSql(List<NewsSubCategory> value) =>
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

  /// Fine-grained sub-categories
  TextColumn get subCategories => text()
      .map(const SubCategoryListConverter())
      .withDefault(const Constant('[]'))();

  BoolColumn get isPaywalled =>
      boolean().named('is_paywalled').withDefault(const Constant(false))();
  BoolColumn get isLiked =>
      boolean().named('is_liked').withDefault(const Constant(false))();
  BoolColumn get isFavorited =>
      boolean().named('is_favorited').withDefault(const Constant(false))();
  IntColumn get likesCount =>
      integer().named('likes_count').withDefault(const Constant(0))();
  TextColumn get clusterId => text().named('cluster_id').nullable()();
  TextColumn get countryCode => text().named('country_code').nullable()();
  RealColumn get trendScore =>
      real().named('trend_score').withDefault(const Constant(0.0))();
  DateTimeColumn get lastTrendUpdate =>
      dateTime().named('last_trend_update').nullable()();
  RealColumn get rankingScore =>
      real().named('ranking_score').withDefault(const Constant(0.0))();
  BoolColumn get isMajorSource =>
      boolean().named('is_major_source').withDefault(const Constant(false))();

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

class ChatSessionsTable extends Table {
  @override
  String get tableName => 'chat_sessions';

  TextColumn get id => text()();
  TextColumn get articleId => text().named('article_id')();
  TextColumn get articleTitle => text().named('article_title')();
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().named('updated_at').withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class ChatMessagesTable extends Table {
  @override
  String get tableName => 'chat_messages';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get sessionId => text().named('session_id')();
  TextColumn get role => text()();
  TextColumn get content => text()();
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();
}

// ── Database ──────────────────────────────────────────────────────

@DriftDatabase(tables: [
  NewsArticlesTable,
  ViewedArticlesTable,
  ChatSessionsTable,
  ChatMessagesTable
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 11;

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
          if (from < 7) {
            await m.createTable(chatSessionsTable);
            await m.createTable(chatMessagesTable);
          }
          if (from < 8) {
            await m.addColumn(
                newsArticlesTable, newsArticlesTable.subCategories);
          }
          if (from < 9) {
            await m.addColumn(newsArticlesTable, newsArticlesTable.trendScore);
            await m.addColumn(
                newsArticlesTable, newsArticlesTable.lastTrendUpdate);
          }
          if (from < 10) {
            await m.addColumn(
                newsArticlesTable, newsArticlesTable.rankingScore);
            await m.addColumn(
                newsArticlesTable, newsArticlesTable.isMajorSource);
          }
          if (from < 11) {
            await m.addColumn(newsArticlesTable, newsArticlesTable.countryCode);
          }
        },
      );

  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'currenta_db.sqlite'));

      // Configure SQLCipher in the current isolate before opening sqlite.
      _configureSqlCipherForAndroid();

      // Get the persistent encryption key
      final key = await SecureStorageService.instance.getOrCreateDatabaseKey();

      // HEURISTIC: If we are enabling encryption for the first time on an existing DB,
      // SQLCipher will fail to read the unencrypted header. We reset the cache.
      final encryptionFlag =
          await SecureStorageService.instance.read('db_encrypted_v1');
      if (encryptionFlag == null && await file.exists()) {
        try {
          await file.delete();
        } catch (e) {
          debugPrint('[Database] Reset failed: $e');
        }
      }
      await SecureStorageService.instance.write('db_encrypted_v1', 'true');

      return NativeDatabase.createInBackground(
        file,
        isolateSetup: _configureSqlCipherForAndroid,
        setup: (db) {
          try {
            db.execute("PRAGMA key = '$key';");
          } catch (e) {
            debugPrint('[Database] PRAGMA key execution failed: $e');
          }
        },
      );
    });
  }
  
  Future<void> wipeDatabase() async {
    await transaction(() async {
      for (final table in allTables) {
        await delete(table).go();
      }
    });
  }
}
