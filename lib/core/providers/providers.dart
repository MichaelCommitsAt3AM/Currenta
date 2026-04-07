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
import '../../features/news/data/repositories/chat_repository_impl.dart';
import '../../features/news/domain/repositories/chat_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/dio_client.dart';
import '../../features/news/data/repositories/local_persistence_repository.dart';

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
    auth: ref.watch(authRepositoryProvider),
  );
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    supabaseClient: ref.watch(supabaseClientProvider),
    dio: ref.watch(dioClientProvider),
    prefs: ref.watch(sharedPreferencesProvider),
  );
});

final onboardingRepositoryProvider = Provider<OnboardingRepository>((ref) {
  return OnboardingRepositoryImpl();
});

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepositoryImpl(db: ref.watch(appDatabaseProvider));
});

// ── Persistence ──────────────────────────────────────────────────

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden in ProviderScope');
});

final localPersistenceRepositoryProvider = Provider<LocalPersistenceRepository>((ref) {
  return LocalPersistenceRepository(
    prefs: ref.watch(sharedPreferencesProvider),
  );
});
