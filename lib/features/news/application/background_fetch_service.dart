// lib/features/news/application/background_fetch_service.dart
// Uses WorkManager to pre-download the top N articles on a schedule.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';
import '../../../core/config/app_config.dart';
import '../../../core/providers/providers.dart';

const _kBgFetchTaskName = 'currenta_news_prefetch';
const _kBgCacheCleanTaskName = 'currenta_cache_clean';

/// Register WorkManager tasks. Call this once from main().
Future<void> registerBackgroundTasks() async {
  await Workmanager().initialize(
    _backgroundCallbackDispatcher,
    isInDebugMode: false,
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
    final container = ProviderContainer();
    try {
      final repo = container.read(newsRepositoryProvider);
      if (taskName == _kBgFetchTaskName) {
        // 1. Trigger fresh ingestion for a few random sources (3-5)
        // to keep the Supabase DB alive and current.
        await repo.triggerAllIngestion(limit: 5);

        // 2. Fetch from DB to local SQLite
        await repo.prefetchTopArticles(
          count: AppConfig.backgroundPrefetchCount,
        );
      } else if (taskName == _kBgCacheCleanTaskName) {
        await repo.clearOldCache();
      }
      return Future.value(true);
    } catch (e) {
      return Future.value(false);
    } finally {
      container.dispose();
    }
  });
}
