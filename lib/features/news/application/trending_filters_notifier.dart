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
    final saved = repo.getTrendingFilters();
    
    if (saved != null) return saved;

    // Default to global if no filters saved yet
    return const TrendingFilters(countryCode: null);
  }

  Future<void> updateFilters(TrendingFilters filters) async {
    final repo = ref.read(localPersistenceRepositoryProvider);
    await repo.saveTrendingFilters(filters);
    state = filters;
  }
}
