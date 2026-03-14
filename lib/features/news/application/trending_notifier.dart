// lib/features/news/application/trending_notifier.dart

import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../domain/entities/news_article.dart';
import '../domain/repositories/news_repository.dart';
import '../../../core/providers/providers.dart';

part 'trending_notifier.g.dart';

@riverpod
class TrendingNotifier extends _$TrendingNotifier {
  NewsRepository get _repo => ref.read(newsRepositoryProvider);

  @override
  Future<List<NewsArticle>> build() async {
    return _fetch();
  }

  Future<List<NewsArticle>> _fetch() async {
    try {
      return await _repo.fetchTrending(limit: 20);
    } catch (e) {
      // Return empty list on error for now, or rethrow
      return [];
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetch());
  }
}
