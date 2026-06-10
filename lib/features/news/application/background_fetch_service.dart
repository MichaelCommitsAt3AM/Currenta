// lib/features/news/application/background_fetch_service.dart
// Uses WorkManager to pre-download the top N articles on a schedule.

import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';
import '../../../core/config/app_config.dart';
import '../../../core/providers/providers.dart';
import '../../../core/storage/secure_auth_storage.dart';
import '../../../firebase_options_dev.dart' as dev;
import '../../../firebase_options_prod.dart' as prod;

const _kBgFetchTaskName = 'currenta_news_prefetch';
const _kBgCacheCleanTaskName = 'currenta_cache_clean';

/// Register WorkManager tasks. Call this once from main().
Future<void> registerBackgroundTasks() async {
  await Workmanager().initialize(
    _backgroundCallbackDispatcher,
  );

  // ── Prefetch top articles every N hours ──────────────────────
  await Workmanager().registerPeriodicTask(
    _kBgFetchTaskName,
    _kBgFetchTaskName,
    frequency: Duration(hours: AppConfig.backgroundFetchIntervalHours),
    constraints: Constraints(
      networkType: NetworkType.connected,
    ),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );

  // ── Clean stale cache daily ───────────────────────────────────
  await Workmanager().registerPeriodicTask(
    _kBgCacheCleanTaskName,
    _kBgCacheCleanTaskName,
    frequency: const Duration(hours: 24),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );
}

/// Top-level callback — must be a top-level or static function.
@pragma('vm:entry-point')
void _backgroundCallbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    // 1. Initialize Flutter engine bindings for background isolate
    DartPluginRegistrant.ensureInitialized();

    try {
      // 2. Initialize SharedPreferences
      final prefs = await SharedPreferences.getInstance();

      // 3. Initialize Firebase if not already initialized
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: AppConfig.isProd
              ? prod.DefaultFirebaseOptions.currentPlatform
              : dev.DefaultFirebaseOptions.currentPlatform,
        );
      }

      // 4. Initialize Supabase if not already initialized
      try {
        Supabase.instance;
      } catch (_) {
        await Supabase.initialize(
          url: AppConfig.supabaseUrl,
          anonKey: AppConfig.supabaseAnonKey,
          authOptions: const FlutterAuthClientOptions(
            localStorage: SecureAuthStorage(),
          ),
        );
      }

      // 5. Create ProviderContainer with sharedPreferencesProvider overridden
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );

      try {
        final repo = container.read(newsRepositoryProvider);
        if (taskName == _kBgFetchTaskName) {
          // Fetch existing processed articles from DB to local SQLite
          await repo.prefetchTopArticles(
            count: AppConfig.backgroundPrefetchCount,
          );
        } else if (taskName == _kBgCacheCleanTaskName) {
          await repo.clearOldCache();
        }
        return Future.value(true);
      } catch (e, st) {
        if (Firebase.apps.isNotEmpty) {
          await FirebaseCrashlytics.instance.recordError(
            e,
            st,
            reason: 'WorkManager task failed: $taskName',
            printDetails: true,
          );
        }
        return Future.value(false);
      } finally {
        container.dispose();
      }
    } catch (e, st) {
      // Catch initialization errors
      debugPrint('[BackgroundFetch] Initialization failed: $e\n$st');
      return Future.value(false);
    }
  });
}
