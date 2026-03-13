// lib/features/news/application/reading_history_notifier.dart

import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../domain/entities/news_article.dart';
import '../domain/repositories/news_repository.dart';
import '../../../core/providers/providers.dart';

part 'reading_history_notifier.g.dart';

@riverpod
class ReadingHistoryNotifier extends _$ReadingHistoryNotifier {
  NewsRepository get _repo => ref.read(newsRepositoryProvider);

  @override
  Stream<List<NewsArticle>> build() {
    return _repo.watchReadingHistory();
  }

  Future<void> clearHistory() async {
    await _repo.clearReadingHistory();
  }
}
