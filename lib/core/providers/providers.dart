// lib/core/providers/providers.dart
// All top-level Riverpod providers for infrastructure dependencies.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/news/data/local/app_database.dart';
import '../../features/news/data/remote/news_remote_datasource.dart';
import '../../features/news/data/repositories/news_repository_impl.dart';
import '../../features/news/domain/repositories/news_repository.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/data/repositories/onboarding_repository_impl.dart';
import '../../features/auth/domain/repositories/onboarding_repository.dart';
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

// ── Data Sources ──────────────────────────────────────────────────

final newsRemoteDataSourceProvider = Provider<NewsRemoteDataSource>((ref) {
  return NewsRemoteDataSource(
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

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    supabaseClient: ref.watch(supabaseClientProvider),
  );
});

final onboardingRepositoryProvider = Provider<OnboardingRepository>((ref) {
  return OnboardingRepositoryImpl();
});
