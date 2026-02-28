// lib/core/providers/providers.dart
// All top-level Riverpod providers for infrastructure dependencies.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/news/data/local/app_database.dart';
import '../../features/news/data/remote/news_remote_datasource.dart';
import '../../features/news/data/repositories/news_repository_impl.dart';
import '../../features/news/domain/repositories/news_repository.dart';
import '../ai/llm_provider.dart';
import '../ai/llm_provider_factory.dart';
import '../utils/dio_client.dart';

// ── Supabase ──────────────────────────────────────────────────────

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// ── Local Database ────────────────────────────────────────────────

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

// ── Networking ────────────────────────────────────────────────────

final dioClientProvider = Provider((ref) => DioClient.instance.dio);

// ── AI / LLM ─────────────────────────────────────────────────────

final llmProviderProvider = Provider<LlmProvider>((ref) {
  return LlmProviderFactory.create();
});

// ── Data Sources ──────────────────────────────────────────────────

final newsRemoteDataSourceProvider = Provider<NewsRemoteDataSource>((ref) {
  return NewsRemoteDataSource(
    supabase: ref.watch(supabaseClientProvider),
    dio: ref.watch(dioClientProvider),
  );
});

// ── Repository ────────────────────────────────────────────────────

final newsRepositoryProvider = Provider<NewsRepository>((ref) {
  return NewsRepositoryImpl(
    database: ref.watch(appDatabaseProvider),
    remote: ref.watch(newsRemoteDataSourceProvider),
  );
});
