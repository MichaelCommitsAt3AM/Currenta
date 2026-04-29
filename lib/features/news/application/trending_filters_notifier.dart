// lib/features/news/application/trending_filters_notifier.dart

import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../domain/entities/trending_filters.dart';
import '../../../core/providers/providers.dart';

part 'trending_filters_notifier.g.dart';

@riverpod
class TrendingFiltersNotifier extends _$TrendingFiltersNotifier {
  @override
  TrendingFilters build() {
    final repo = ref.watch(localPersistenceRepositoryProvider);
    return repo.getTrendingFilters();
  }

  Future<void> updateFilters(TrendingFilters filters) async {
    final repo = ref.read(localPersistenceRepositoryProvider);
    await repo.saveTrendingFilters(filters);
    state = filters;
  }
}
